// ============================================================================
// Module:        siddham_npu_top
// Description:   Top-Level Integration Wrapper with Parameterized ARRAY_N
// ============================================================================

`timescale 1ns / 1ps

module siddham_npu_top #(
    parameter C_AXIS_DATA_WIDTH = 128,
    parameter ARRAY_N           = 16,    // Fixed: Exported top-level array dimension
    parameter DATA_WIDTH        = 8,
    parameter ACC_WIDTH         = 32
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         core_start,
    input  wire [15:0]                  matrix_dim,
    input  wire [1:0]                   act_mode,

    // DMA Control Interfaces
    input  wire                         dma_start_rx,
    input  wire                         dma_start_tx,
    input  wire [31:0]                  dma_base_addr,
    input  wire [15:0]                  dma_xfer_len,
    input  wire [1:0]                   dma_target_buf,

    // Core Execution Flags
    output wire                         core_busy,
    output wire                         core_done,
    output wire                         pl_ps_irq0,

    // AXI-Stream Slave Input Interface (Activations / Weights)
    input  wire [C_AXIS_DATA_WIDTH-1:0] s_axis_tdata,
    input  wire [15:0]                  s_axis_tstrb,
    input  wire                         s_axis_tlast,
    input  wire                         s_axis_tvalid,
    output wire                         s_axis_tready,

    // AXI-Stream Master Output Interface (Results)
    output wire [C_AXIS_DATA_WIDTH-1:0] m_axis_tdata,
    output wire [15:0]                  m_axis_tstrb,
    output wire                         m_axis_tlast,
    output wire                         m_axis_tvalid,
    input  wire                         m_axis_tready
);

    // Dynamic address width calculation based on ARRAY_N
    localparam ADDR_W = (ARRAY_N > 1) ? $clog2(ARRAY_N) : 1;

    // Internal Interconnect Wires
    wire                w_buf_wr_en;
    wire [ADDR_W-1:0]   w_buf_addr;
    wire [127:0]        w_buf_wdata;

    wire                a_buf_wr_en;
    wire [ADDR_W-1:0]   a_buf_addr;
    wire [127:0]        a_buf_wdata;

    wire                out_buf_rd_en;
    wire [ADDR_W-1:0]   out_buf_addr;
    wire [127:0]        out_buf_rdata;
    wire                dma_busy;
    wire                dma_done;

    assign pl_ps_irq0 = core_done;

    // DMA Engine Instantiation
// DMA Engine Instantiation
    npu_dma_engine #(
        .DATA_WIDTH(C_AXIS_DATA_WIDTH),
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
        .w_buf_wr_en     (w_buf_wr_en),
        .w_buf_addr      (w_buf_addr),
        .w_buf_wdata     (w_buf_wdata),
        .a_buf_wr_en     (a_buf_wr_en),
        .a_buf_addr      (a_buf_addr),
        .a_buf_wdata     (a_buf_wdata),
        .out_buf_rd_en   (out_buf_rd_en),
        .out_buf_addr    (out_buf_addr),
        .out_buf_rdata   (out_buf_rdata),
        .s_axis_tdata    (s_axis_tdata),
        .s_axis_tstrb    (s_axis_tstrb),
        .s_axis_tlast    (s_axis_tlast),
        .s_axis_tvalid   (s_axis_tvalid),
        .s_axis_tready   (s_axis_tready),
        .m_axis_tdata    (m_axis_tdata),
        .m_axis_tstrb    (m_axis_tstrb),
        .m_axis_tlast    (m_axis_tlast),
        .m_axis_tvalid   (m_axis_tvalid),
        .m_axis_tready   (m_axis_tready)
    );

    // Systolic Compute Core Instantiation (Explicit Parameter Pass-Through)
    npu_compute_core #(
        .ARRAY_N(ARRAY_N),          // Fixed: Passes top parameter down to compute array
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
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
