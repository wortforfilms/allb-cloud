// ============================================================================
// Module:      npu_dma_engine (128-bit Data Path)
// Description: AXI4-Stream DMA Engine for 128-bit wide SRAM buffers.
//              Supports inbound (Host -> SRAM) and outbound (SRAM -> Host).
// ============================================================================

module npu_dma_engine #(
    parameter DATA_WIDTH = 128,          // अब 128-बिट
    parameter ADDR_WIDTH = 32,
    parameter ARRAY_N    = 16
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // Control Registers & Handshake
    input  wire                    dma_start_rx,
    input  wire                    dma_start_tx,
    input  wire [ADDR_WIDTH-1:0]   base_addr,
    input  wire [15:0]             xfer_length,   // 128-बिट शब्दों में लंबाई
    input  wire [1:0]              target_buffer,
    output reg                     dma_busy,
    output reg                     dma_done,

    // AXI4-Stream Slave (Inbound)
    input  wire [DATA_WIDTH-1:0]   s_axis_tdata,
    input  wire [(DATA_WIDTH/8)-1:0] s_axis_tstrb,
    input  wire                    s_axis_tlast,
    input  wire                    s_axis_tvalid,
    output reg                     s_axis_tready,

    // AXI4-Stream Master (Outbound)
    output reg  [DATA_WIDTH-1:0]   m_axis_tdata,
    output reg  [(DATA_WIDTH/8)-1:0] m_axis_tstrb,
    output reg                     m_axis_tlast,
    output reg                     m_axis_tvalid,
    input  wire                    m_axis_tready,

    // Local NPU Buffer Write Interfaces (RX)
    output reg                     w_buf_wr_en,
    output reg  [$clog2(ARRAY_N)-1:0] w_buf_addr,
    output reg  [DATA_WIDTH-1:0]   w_buf_wdata,

    output reg                     a_buf_wr_en,
    output reg  [$clog2(ARRAY_N)-1:0] a_buf_addr,
    output reg  [DATA_WIDTH-1:0]   a_buf_wdata,

    // Local NPU Buffer Read Interface (TX)
    output reg                     out_buf_rd_en,
    output reg  [$clog2(ARRAY_N)-1:0] out_buf_addr,
    input  wire [DATA_WIDTH-1:0]   out_buf_rdata
);

    // FSM States
    localparam STATE_IDLE = 2'b00;
    localparam STATE_RX   = 2'b01;
    localparam STATE_TX   = 2'b10;
    localparam STATE_DONE = 2'b11;

    reg [1:0]  state;
    reg [15:0] word_cnt;
    reg        tx_data_ready;

    // सभी सिग्नल अब DATA_WIDTH के अनुसार स्वतः चौड़े हैं।

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
            tx_data_ready <= 1'b0;
        end else begin
            // पल्स सिग्नल डिफ़ॉल्ट शून्य
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
                        s_axis_tready <= 1'b1;
                    end else if (dma_start_tx) begin
                        state         <= STATE_TX;
                        dma_busy      <= 1'b1;
                        out_buf_rd_en <= 1'b1;
                        out_buf_addr  <= 0;
                        tx_data_ready <= 1'b0;
                    end else begin
                        dma_busy <= 1'b0;
                    end
                end

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

                STATE_TX: begin
                    if (!tx_data_ready) begin
                        // Result SRAM has a synchronous one-cycle read latency.
                        m_axis_tvalid <= 1'b0;
                        tx_data_ready <= 1'b1;
                    end else begin
                        m_axis_tvalid <= 1'b1;
                        m_axis_tdata  <= out_buf_rdata;
                        m_axis_tstrb  <= {(DATA_WIDTH/8){1'b1}};
                        m_axis_tlast  <= (word_cnt + 1 >= xfer_length);

                        if (m_axis_tvalid && m_axis_tready) begin
                            if (word_cnt + 1 < xfer_length) begin
                                word_cnt       <= word_cnt + 1'b1;
                                out_buf_rd_en  <= 1'b1;
                                out_buf_addr   <= word_cnt + 1'b1;
                                tx_data_ready  <= 1'b0;
                                m_axis_tvalid  <= 1'b0;
                                m_axis_tlast   <= 1'b0;
                            end else begin
                                m_axis_tvalid <= 1'b0;
                                m_axis_tlast  <= 1'b0;
                                tx_data_ready <= 1'b0;
                                state         <= STATE_DONE;
                            end
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
