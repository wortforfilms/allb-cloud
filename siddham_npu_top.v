// ============================================================================
// Module:      siddham_npu_top
// Description: Top-Level Integration Wrapper for Siddham NPU System.
// ============================================================================

`timescale 1ns / 1ps

module siddham_npu_top #(
    parameter C_S00_AXI_DATA_WIDTH = 32,
    parameter C_S00_AXI_ADDR_WIDTH = 32,
    parameter C_AXIS_DATA_WIDTH    = 64,
    parameter ARRAY_N              = 16
)(
    input  wire                            clk,
    input  wire                            rst_n,

    // Interrupt Signal to PS
    output wire                            pl_ps_irq0,

    // Unified AXI4-Stream Slave Interface (Inbound: Weights & Activations)
    input  wire [C_AXIS_DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire [(C_AXIS_DATA_WIDTH/8)-1:0] s_axis_tstrb,
    input  wire                            s_axis_tlast,
    input  wire                            s_axis_tvalid,
    output wire                            s_axis_tready,

    // Unified AXI4-Stream Master Interface (Outbound: Results)
    output wire [C_AXIS_DATA_WIDTH-1:0]    m_axis_tdata,
    output wire [(C_AXIS_DATA_WIDTH/8)-1:0] m_axis_tstrb,
    output wire                            m_axis_tlast,
    output wire                            m_axis_tvalid,
    input  wire                            m_axis_tready
);

    // Internal Control Signals
    wire        dma_start_rx;
    wire        dma_start_tx;
    wire [31:0] dma_base_addr;
    wire [15:0] dma_xfer_len;
    wire [1:0]  dma_target_buf;
    wire        dma_busy;
    wire        dma_done;

    wire        core_start;
    wire [15:0] matrix_dim;
    wire [1:0]  act_mode;
    wire        core_busy;
    wire        core_done;

    // SRAM Buffer Interconnect Wires
    wire        w_buf_wr_en;
    wire [3:0]  w_buf_addr;
    wire [63:0] w_buf_wdata;

    wire        a_buf_wr_en;
    wire [3:0]  a_buf_addr;
    wire [63:0] a_buf_wdata;

    wire        out_buf_rd_en;
    wire [3:0]  out_buf_addr;
    wire [63:0] out_buf_rdata;

    assign pl_ps_irq0 = core_done | dma_done;

    // ------------------------------------------------------------------------
    // 1. AXI4-Stream DMA Engine Instantiation
    // ------------------------------------------------------------------------
    npu_dma_engine #(
        .DATA_WIDTH(C_AXIS_DATA_WIDTH),
        .ADDR_WIDTH(32),
        .ARRAY_N(ARRAY_N)
    ) u_dma_engine (
        .clk             (clk),
        .rst_n           (rst_n),
        .dma_start_rx    (dma_start_rx),
        .dma_start_tx    (dma_start_tx),
        .base_addr       (dma_base_addr),
        .xfer_length     (dma_xfer_len),
        .target_buffer   (dma_target_buf),
        .dma_busy        (dma_busy),
        .dma_done        (dma_done),
        .s_axis_tdata    (s_axis_tdata),
        .s_axis_tstrb    (s_axis_tstrb),
        .s_axis_tlast    (s_axis_tlast),
        .s_axis_tvalid   (s_axis_tvalid),
        .s_axis_tready   (s_axis_tready),
        .m_axis_tdata    (m_axis_tdata),
        .m_axis_tstrb    (m_axis_tstrb),
        .m_axis_tlast    (m_axis_tlast),
        .m_axis_tvalid   (m_axis_tvalid),
        .m_axis_tready   (m_axis_tready),
        .w_buf_wr_en     (w_buf_wr_en),
        .w_buf_addr      (w_buf_addr),
        .w_buf_wdata     (w_buf_wdata),
        .a_buf_wr_en     (a_buf_wr_en),
        .a_buf_addr      (a_buf_addr),
        .a_buf_wdata     (a_buf_wdata),
        .out_buf_rd_en   (out_buf_rd_en),
        .out_buf_addr    (out_buf_addr),
        .out_buf_rdata   (out_buf_rdata)
    );

    // ------------------------------------------------------------------------
    // 2. Synthesizable NPU Compute Core
    // ------------------------------------------------------------------------
    npu_compute_core #(
        .ARRAY_N(ARRAY_N),
        .DATA_WIDTH(8),
        .ACC_WIDTH(32)
    ) u_compute_core (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (core_start),
        .matrix_dim      (matrix_dim),
        .act_mode        (act_mode),
        .w_buf_wr_en     (w_buf_wr_en),
        .w_buf_addr      (w_buf_addr),
        .w_buf_wdata     (w_buf_wdata),
        .a_buf_wr_en     (a_buf_wr_en),
        .a_buf_addr      (a_buf_addr),
        .a_buf_wdata     (a_buf_wdata),
        .out_buf_rd_en   (out_buf_rd_en),
        .out_buf_addr    (out_buf_addr),
        .out_buf_rdata   (out_buf_rdata),
        .core_busy       (core_busy),
        .core_done       (core_done)
    );

endmodule