// ============================================================================
// Module Name:  siddham_axis_dma
// Project:      Maataa Sovereign AI Hardware Accelerator (Siddham NPU Core)
// Description:  AXI4-Stream Slave DMA Engine. Stream-ingests Float32 vector
//               embeddings directly into NPU internal BRAM register storage.
// ============================================================================

`timescale 1ns / 1ps

module siddham_axis_dma #(
    parameter integer C_AXIS_TDATA_WIDTH = 32,
    parameter integer MAX_VECTOR_LEN     = 1024  // Maximum embedding size
)(
    // --- Global Clock & Reset ---
    input  wire                          axis_aclk,
    input  wire                          axis_aresetn,

    // --- AXI4-Stream Slave Interface ---
    input  wire [C_AXIS_TDATA_WIDTH-1:0] s_axis_tdata,
    input  wire                          s_axis_tvalid,
    output reg                           s_axis_tready,
    input  wire                          s_axis_tlast,
    input  wire [(C_AXIS_TDATA_WIDTH/8)-1:0] s_axis_tstrb,

    // --- Control & Status Interface (From/To MMIO Core) ---
    input  wire                          dma_start_enable,
    input  wire [31:0]                   target_vector_length,
    output reg                           dma_busy,
    output reg                           dma_done,
    output reg                           dma_error,
    output reg  [31:0]                   received_word_count,

    // --- NPU Compute Engine BRAM Read Port ---
    input  wire [$clog2(MAX_VECTOR_LEN)-1:0] npu_bram_raddr,
    output wire [C_AXIS_TDATA_WIDTH-1:0]     npu_bram_rdata
);

    localparam ADDR_BITS = $clog2(MAX_VECTOR_LEN);

    // ------------------------------------------------------------------------
    // FSM States
    // ------------------------------------------------------------------------
    localparam [1:0] STATE_IDLE  = 2'b00,
                     STATE_STREAM = 2'b01,
                     STATE_DONE   = 2'b10,
                     STATE_ERROR  = 2'b11;

    reg [1:0] state;

    // ------------------------------------------------------------------------
    // Dual-Port RAM Block for Vector Embedding Storage
    // ------------------------------------------------------------------------
    reg [C_AXIS_TDATA_WIDTH-1:0] vector_bram [0:MAX_VECTOR_LEN-1];
    reg [ADDR_BITS-1:0]          waddr;

    // Infer BRAM Write Port (AXI-Stream Clock Domain)
    always @(posedge axis_aclk) begin
        if (s_axis_tvalid && s_axis_tready) begin
            vector_bram[waddr] <= s_axis_tdata;
        end
    end

    // Infer BRAM Read Port (NPU Execution Core Domain)
    assign npu_bram_rdata = vector_bram[npu_bram_raddr];

    // ------------------------------------------------------------------------
    // AXI-Stream Ingress State Machine
    // ------------------------------------------------------------------------
    always @(posedge axis_aclk or negedge axis_aresetn) begin
        if (!axis_aresetn) begin
            state               <= STATE_IDLE;
            s_axis_tready       <= 1'b0;
            waddr               <= {ADDR_BITS{1'b0}};
            dma_busy            <= 1'b0;
            dma_done            <= 1'b0;
            dma_error           <= 1'b0;
            received_word_count <= 32'h0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    dma_done  <= 1'b0;
                    dma_error <= 1'b0;
                    waddr     <= {ADDR_BITS{1'b0}};

                    if (dma_start_enable) begin
                        state               <= STATE_STREAM;
                        s_axis_tready       <= 1'b1;
                        dma_busy            <= 1'b1;
                        received_word_count <= 32'h0;
                    end else begin
                        s_axis_tready       <= 1'b0;
                        dma_busy            <= 1'b0;
                    end
                end

                STATE_STREAM: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        received_word_count <= received_word_count + 1'b1;
                        
                        // Buffer overflow guard
                        if (waddr >= MAX_VECTOR_LEN - 1 && !s_axis_tlast) begin
                            state         <= STATE_ERROR;
                            s_axis_tready <= 1'b0;
                            dma_error     <= 1'b1;
                        end else begin
                            waddr <= waddr + 1'b1;
                        end

                        // End of Packet Handling via tlast
                        if (s_axis_tlast) begin
                            state         <= STATE_DONE;
                            s_axis_tready <= 1'b0;
                            dma_busy      <= 1'b1;  // <-- FIXED: Changed '1 me' to '1'b1'
                            dma_done      <= 1'b1;
                        end
                    end
                end

                STATE_DONE: begin
                    dma_busy <= 1'b0;
                    if (!dma_start_enable) begin
                        state <= STATE_IDLE;
                    end
                end

                STATE_ERROR: begin
                    dma_busy  <= 1'b0;
                    dma_error <= 1'b1;
                    if (!dma_start_enable) begin
                        state <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule