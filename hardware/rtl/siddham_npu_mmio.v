// ============================================================================
// Module Name:  siddham_npu_mmio
// Project:      Maataa Sovereign AI Hardware Accelerator (Siddham NPU Core)
// Description:  AXI4-Lite Memory-Mapped Register Bank at Address 0xA0000000.
//               Coordinates low-level DMA buffer pointers, control signals,
//               and execution telemetry for the C++ HAL layer.
// ============================================================================

`timescale 1ns / 1ps

module siddham_npu_mmio #(
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter [31:0]  BASE_ADDR          = 32'hA000_0000
)(
    // --- Global Clock & Reset ---
    input  wire        axi_aclk,
    input  wire        axi_aresetn,

    // --- AXI4-Lite Slave Write Interface ---
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                          s_axi_awvalid,
    output reg                           s_axi_awready,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                          s_axi_wvalid,
    output reg                           s_axi_wready,
    output reg  [1:0]                    s_axi_bresp,
    output reg                           s_axi_bvalid,
    input  wire                          s_axi_bready,

    // --- AXI4-Lite Slave Read Interface ---
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                          s_axi_arvalid,
    output reg                           s_axi_arready,
    output reg  [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]                    s_axi_rresp,
    output reg                           s_axi_rvalid,
    input  wire                          s_axi_rready,

    // --- NPU Vector Engine Control & Status Signals ---
    output reg  [31:0] npu_input_buffer_ptr,
    output reg  [31:0] npu_output_buffer_ptr,
    output reg  [31:0] npu_vector_length,
    output wire        npu_start_trigger,
    output wire        npu_soft_reset,
    input  wire        npu_engine_busy,
    input  wire        npu_engine_done,
    input  wire        npu_engine_error,
    input  wire [3:0]  npu_hal_error_code,
    input  wire [31:0] npu_execution_cycles,
    output wire        npu_irq_out
);

    // ------------------------------------------------------------------------
    // Internal Control Registers
    // ------------------------------------------------------------------------
    reg [31:0] cr_control;
    reg [31:0] cr_input_addr;
    reg [31:0] cr_output_addr;
    reg [31:0] cr_vector_len;
    reg        npu_done_latched;

    // Register Offsets
    localparam ADDR_CR_CONTROL     = 8'h00;
    localparam ADDR_CR_STATUS      = 8'h04;
    localparam ADDR_CR_INPUT_ADDR  = 8'h08;
    localparam ADDR_CR_OUTPUT_ADDR = 8'h0C;
    localparam ADDR_CR_VECTOR_LEN  = 8'h10;
    localparam ADDR_CR_CYCLE_COUNT = 8'h14;
    localparam ADDR_CR_INT_ACK     = 8'h18;

    // Control Bits Breakdown
    assign npu_start_trigger = cr_control[0];
    assign npu_soft_reset    = cr_control[1];
    wire   npu_irq_en        = cr_control[2];

    // Interrupt Line Generation
    assign npu_irq_out = npu_irq_en && npu_done_latched;

    // Status Word Formatting
    wire [31:0] cr_status_word = {
        24'b0,
        npu_hal_error_code, // Bits [7:4]: HAL status flags
        1'b0,
        npu_engine_error,   // Bit 2: Execution fault
        npu_done_latched,   // Bit 1: Completion status
        npu_engine_busy     // Bit 0: HW Busy Flag
    };

    // ------------------------------------------------------------------------
    // AXI-Lite Write State Machine & Register Update
    // ------------------------------------------------------------------------
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr_reg;

    always @(posedge axi_aclk or negedge axi_aresetn) begin
        if (!axi_aresetn) begin
            s_axi_awready        <= 1'b0;
            s_axi_wready         <= 1'b0;
            s_axi_bvalid         <= 1'b0;
            s_axi_bresp          <= 2'b00;
            cr_control           <= 32'h0;
            cr_input_addr        <= 32'h0;
            cr_output_addr       <= 32'h0;
            cr_vector_len        <= 32'd128; // Default to 128-dim embeddings
            npu_input_buffer_ptr <= 32'h0;
            npu_output_buffer_ptr<= 32'h0;
            npu_vector_length    <= 32'd128;
            npu_done_latched     <= 1'b0;
        end else begin
            // Clear self-clearing START bit on next cycle
            if (cr_control[0]) begin
                cr_control[0] <= 1'b0;
            end

            // Capture completion flag from compute core
            if (npu_engine_done) begin
                npu_done_latched <= 1'b1;
            end

            // AXI Write Handshake
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready  <= 1'b1;
                s_axi_wready   <= 1'b1;
                axi_awaddr_reg <= s_axi_awaddr;
            end else begin
                s_axi_awready  <= 1'b0;
                s_axi_wready   <= 1'b0;
            end

            // Register Commit Phase
            if (s_axi_awready && s_axi_wready) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY response

                // Address match against BASE_ADDR (0xA0000000)
                if ((axi_awaddr_reg & 32'hFFFF_FF00) == BASE_ADDR) begin
                    case (axi_awaddr_reg[7:0])
                        ADDR_CR_CONTROL: begin
                            cr_control <= s_axi_wdata;
                        end
                        ADDR_CR_INPUT_ADDR: begin
                            cr_input_addr        <= s_axi_wdata;
                            npu_input_buffer_ptr <= s_axi_wdata;
                        end
                        ADDR_CR_OUTPUT_ADDR: begin
                            cr_output_addr        <= s_axi_wdata;
                            npu_output_buffer_ptr <= s_axi_wdata;
                        end
                        ADDR_CR_VECTOR_LEN: begin
                            cr_vector_len     <= s_axi_wdata;
                            npu_vector_length <= s_axi_wdata;
                        end
                        ADDR_CR_INT_ACK: begin
                            if (s_axi_wdata[0]) begin
                                npu_done_latched <= 1'b0; // Clear IRQ & done flag
                            end
                        end
                    endcase
                end
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // AXI-Lite Read State Machine
    // ------------------------------------------------------------------------
    always @(posedge axi_aclk or negedge axi_aresetn) begin
        if (!axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'h0;
            s_axi_rresp   <= 2'b00;
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;

                // Decode Address Read
                if ((s_axi_araddr & 32'hFFFF_FF00) == BASE_ADDR) begin
                    case (s_axi_araddr[7:0])
                        ADDR_CR_CONTROL:     s_axi_rdata <= cr_control;
                        ADDR_CR_STATUS:      s_axi_rdata <= cr_status_word;
                        ADDR_CR_INPUT_ADDR:  s_axi_rdata <= cr_input_addr;
                        ADDR_CR_OUTPUT_ADDR: s_axi_rdata <= cr_output_addr;
                        ADDR_CR_VECTOR_LEN:  s_axi_rdata <= cr_vector_len;
                        ADDR_CR_CYCLE_COUNT: s_axi_rdata <= npu_execution_cycles;
                        default:             s_axi_rdata <= 32'hDEAD_BEEF;
                    endcase
                end else begin
                    s_axi_rdata <= 32'h0;
                end
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_arready <= 1'b0;
                s_axi_rvalid  <= 1'b0;
            end
        end
    end

endmodule