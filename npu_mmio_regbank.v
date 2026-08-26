// ============================================================================
// Module: npu_mmio_regbank
// Description: AXI4-Lite Register Bank for Siddham NPU Control & Telemetry.
// Maps MMIO offsets to host-accessible control, address, and status registers.
// ============================================================================

`timescale 1ns / 1ps

module npu_mmio_regbank #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 12
)(
    // AXI4-Lite System Signals
    input  wire                          s_axi_aclk,
    input  wire                          s_axi_aresetn,

    // AXI4-Lite Write Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                          s_axi_awvalid,
    output reg                           s_axi_awready,

    // AXI4-Lite Write Data Channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                          s_axi_wvalid,
    output reg                           s_axi_wready,

    // AXI4-Lite Write Response Channel
    output reg  [1:0]                    s_axi_bresp,
    output reg                           s_axi_bvalid,
    input  wire                          s_axi_bready,

    // AXI4-Lite Read Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                          s_axi_arvalid,
    output reg                           s_axi_arready,

    // AXI4-Lite Read Data Channel
    output reg  [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]                    s_axi_rresp,
    output reg                           s_axi_rvalid,
    input  wire                          s_axi_rready,

    // Exported Control & Address Registers
    output reg  [31:0]                   reg_ctrl,
    input  wire [31:0]                   reg_status,
    output reg  [31:0]                   reg_weight_addr,
    output reg  [31:0]                   reg_act_addr,
    output reg  [31:0]                   reg_out_addr,
    output reg  [31:0]                   reg_matrix_dim
);

    // ------------------------------------------------------------------------
    // Register Offsets (Byte Addressed)
    // ------------------------------------------------------------------------
    localparam [7:0] ADDR_REG_CTRL        = 8'h00; // Bit 0: Start, Bit 1: Soft Reset
    localparam [7:0] ADDR_REG_STATUS      = 8'h04; // Read-Only Status Flags
    localparam [7:0] ADDR_REG_WEIGHT_ADDR = 8'h08; // Base Address for Weights Buffer
    localparam [7:0] ADDR_REG_ACT_ADDR    = 8'h0C; // Base Address for Activations Buffer
    localparam [7:0] ADDR_REG_OUT_ADDR    = 8'h10; // Base Address for Output Buffer
    localparam [7:0] ADDR_REG_MATRIX_DIM  = 8'h14; // Matrix Dimensions (N x N)

    // Internal State Registers
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr_reg;
    reg                          axi_awready_reg;
    reg                          axi_wready_reg;
    reg                          axi_bvalid_reg;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr_reg;
    reg                          axi_arready_reg;
    reg                          axi_rvalid_reg;

    // ------------------------------------------------------------------------
    // AXI4-Lite Write Handshake & Register Commit
    // ------------------------------------------------------------------------
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_awready   <= 1'b0;
            s_axi_wready    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            s_axi_bresp     <= 2'b00;
            reg_ctrl        <= 32'h0;
            reg_weight_addr <= 32'h0;
            reg_act_addr    <= 32'h0;
            reg_out_addr    <= 32'h0;
            reg_matrix_dim  <= 32'd16; // Default to 16x16 matrix dimension
        end else begin
            // Self-clearing START pulse (Bit 0 of CTRL)
            if (reg_ctrl[0]) begin
                reg_ctrl[0] <= 1'b0;
            end

            // Write Address Handshake
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready   <= 1'b1;
                axi_awaddr_reg  <= s_axi_awaddr;
            end else begin
                s_axi_awready   <= 1'b0;
            end

            // Write Data Handshake
            if (!s_axi_wready && s_axi_wvalid && s_axi_awvalid) begin
                s_axi_wready <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
            end

            // Register Update Phase
            if (s_axi_awready && s_axi_wready) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY response

                case (axi_awaddr_reg[7:0])
                    ADDR_REG_CTRL:        reg_ctrl        <= s_axi_wdata;
                    ADDR_REG_WEIGHT_ADDR: reg_weight_addr <= s_axi_wdata;
                    ADDR_REG_ACT_ADDR:    reg_act_addr    <= s_axi_wdata;
                    ADDR_REG_OUT_ADDR:    reg_out_addr    <= s_axi_wdata;
                    ADDR_REG_MATRIX_DIM:  reg_matrix_dim  <= s_axi_wdata;
                    default: ; // Status register is read-only
                endcase
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // AXI4-Lite Read Handshake & Data Decode
    // ------------------------------------------------------------------------
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'h0;
            s_axi_rresp   <= 2'b00;
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready  <= 1'b1;
                axi_araddr_reg <= s_axi_araddr;
            end else begin
                s_axi_arready  <= 1'b0;
            end

            if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00; // OKAY response

                case (axi_araddr_reg[7:0])
                    ADDR_REG_CTRL:        s_axi_rdata <= reg_ctrl;
                    ADDR_REG_STATUS:      s_axi_rdata <= reg_status;
                    ADDR_REG_WEIGHT_ADDR: s_axi_rdata <= reg_weight_addr;
                    ADDR_REG_ACT_ADDR:    s_axi_rdata <= reg_act_addr;
                    ADDR_REG_OUT_ADDR:    s_axi_rdata <= reg_out_addr;
                    ADDR_REG_MATRIX_DIM:  s_axi_rdata <= reg_matrix_dim;
                    default:              s_axi_rdata <= 32'hDEAD_BEEF;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0; // <-- FIXED: Removed '1 me' typo
            end
        end
    end

endmodule