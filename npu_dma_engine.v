// ============================================================================
// Module:      npu_dma_engine
// Description: Synthesizable AXI4-Stream DMA Engine for Siddham NPU.
//              Provides high-throughput memory transfers between host DDR and 
//              internal Weight/Activation/Result SRAM buffers.
// Interfaces:  - S_AXIS (Slave Stream): Receives Weight/Activation stream from DMA
//              - M_AXIS (Master Stream): Streams Result data back to host DMA
// ============================================================================

`timescale 1ns / 1ps

module npu_dma_engine #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 32,
    parameter ARRAY_N    = 16
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // Control Registers & Handshake
    input  wire                    dma_start_rx,  // Trigger RX (Host -> NPU SRAM)
    input  wire                    dma_start_tx,  // Trigger TX (NPU SRAM -> Host)
    input  wire [ADDR_WIDTH-1:0]   base_addr,     // Base Transfer Address
    input  wire [15:0]             xfer_length,   // Transfer Length in 64-bit words
    input  wire [1:0]              target_buffer, // 00: Weight, 01: Activation, 10: Result
    output reg                     dma_busy,
    output reg                     dma_done,

    // ------------------------------------------------------------------------
    // AXI4-Stream Slave Interface (Inbound Stream: DDR -> NPU SRAM)
    // ------------------------------------------------------------------------
    input  wire [DATA_WIDTH-1:0]   s_axis_tdata,
    input  wire [(DATA_WIDTH/8)-1:0] s_axis_tstrb,
    input  wire                    s_axis_tlast,
    input  wire                    s_axis_tvalid,
    output reg                     s_axis_tready,

    // ------------------------------------------------------------------------
    // AXI4-Stream Master Interface (Outbound Stream: NPU SRAM -> DDR)
    // ------------------------------------------------------------------------
    output reg  [DATA_WIDTH-1:0]   m_axis_tdata,
    output reg  [(DATA_WIDTH/8)-1:0] m_axis_tstrb,
    output reg                     m_axis_tlast,
    output reg                     m_axis_tvalid,
    input  wire                    m_axis_tready,

    // ------------------------------------------------------------------------
    // Local NPU Buffer Write Interfaces (RX Target)
    // ------------------------------------------------------------------------
    output reg                     w_buf_wr_en,
    output reg  [$clog2(ARRAY_N)-1:0] w_buf_addr,
    output reg  [DATA_WIDTH-1:0]   w_buf_wdata,

    output reg                     a_buf_wr_en,
    output reg  [$clog2(ARRAY_N)-1:0] a_buf_addr,
    output reg  [DATA_WIDTH-1:0]   a_buf_wdata,

    // ------------------------------------------------------------------------
    // Local NPU Buffer Read Interface (TX Target)
    // ------------------------------------------------------------------------
    output reg                     out_buf_rd_en,
    output reg  [$clog2(ARRAY_N)-1:0] out_buf_addr,
    input  wire [DATA_WIDTH-1:0]   out_buf_rdata
);

    // FSM States
    localparam STATE_IDLE = 2'b00;
    localparam STATE_RX   = 2'b01; // Stream Inbound (Host -> SRAM)
    localparam STATE_TX   = 2'b10; // Stream Outbound (SRAM -> Host)
    localparam STATE_DONE = 2'b11;

    reg [1:0]  state;
    reg [15:0] word_cnt;

    // ------------------------------------------------------------------------
    // FSM & Stream Control Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= STATE_IDLE;
            word_cnt      <= 16'd0;
            dma_busy      <= 1'b0;
            dma_done      <= 1'b0;
            s_axis_tready <= 1'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= {DATA_WIDTH{1'b0}};
            m_axis_tstrb  <= {(DATA_WIDTH/8){1'b0}};
            m_axis_tlast  <= 1'b0;
            w_buf_wr_en   <= 1'b0;
            w_buf_addr    <= 0;
            w_buf_wdata   <= 0;
            a_buf_wr_en   <= 1'b0;
            a_buf_addr    <= 0;
            a_buf_wdata   <= 0;
            out_buf_rd_en <= 1'b0;
            out_buf_addr  <= 0;
        end else begin
            // Default Pulsed Signals
            w_buf_wr_en   <= 1'b0;
            a_buf_wr_en   <= 1'b0;
            out_buf_rd_en <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    dma_done <= 1'b0;
                    word_cnt <= 16'd0;
                    if (dma_start_rx) begin
                        state         <= STATE_RX;
                        dma_busy      <= 1'b1;
                        s_axis_tready <= 1'b1; // Signal ready to consume AXI-Stream
                    end else if (dma_start_tx) begin
                        state         <= STATE_TX;
                        dma_busy      <= 1'b1;
                        out_buf_rd_en <= 1'b1;
                        out_buf_addr  <= 0;
                    end else begin
                        dma_busy <= 1'b0;
                    end
                end

// Inbound DMA Transfer (S_AXIS -> SRAM)
                STATE_RX: begin
                    s_axis_tready <= 1'b1;
                    if (s_axis_tvalid && s_axis_tready) begin
                        if (target_buffer == 2'b00) begin
                            w_buf_wr_en <= 1'b1;
                            w_buf_addr  <= word_cnt[$clog2(ARRAY_N)-1:0];
                            w_buf_wdata <= s_axis_tdata;
                        end else if (target_buffer == 2'b01) begin
                            a_buf_wr_en <= 1'b1;
                            a_buf_addr  <= word_cnt[$clog2(ARRAY_N)-1:0];
                            a_buf_wdata <= s_axis_tdata;
                        end

                        if (s_axis_tlast || (word_cnt + 1'b1 >= xfer_length)) begin
                            s_axis_tready <= 1'b0;
                            state         <= STATE_DONE;
                        end else begin
                            word_cnt      <= word_cnt + 1'b1;
                        end
                    end
                end
                
                // Outbound DMA Transfer (SRAM -> M_AXIS)
                STATE_TX: begin
                    m_axis_tvalid <= 1'b1;
                    m_axis_tdata  <= out_buf_rdata;
                    m_axis_tstrb  <= {(DATA_WIDTH/8){1'b1}};
                    m_axis_tlast  <= (word_cnt + 1 >= xfer_length);

                    if (m_axis_tvalid && m_axis_tready) begin
                        word_cnt <= word_cnt + 1'b1;
                        if (word_cnt + 1 < xfer_length) begin
                            out_buf_rd_en <= 1'b1;
                            out_buf_addr  <= word_cnt + 1'b1;
                        end else begin
                            m_axis_tvalid <= 1'b0;
                            m_axis_tlast  <= 1'b0;
                            state         <= STATE_DONE;
                        end
                    end
                end

                STATE_DONE: begin
                    dma_busy <= 1'b0;
                    dma_done <= 1'b1;
                    state    <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule