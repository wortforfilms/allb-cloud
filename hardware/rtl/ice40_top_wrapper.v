// ============================================================================
// Module:        ice40_top_wrapper
// Description:   Synthesizable top-level wrapper for iCE40 HX8K target.
// ============================================================================

module ice40_top_wrapper (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        btn_start,
    output wire [3:0]  status_leds
);

    reg btn_start_q;
    always @(posedge clk) begin
        btn_start_q <= btn_start;
    end
    wire core_start = btn_start && !btn_start_q;

    (* keep *) wire core_busy;
    (* keep *) wire core_done;
    (* keep *) wire pl_ps_irq0;
    (* keep *) wire [127:0] m_axis_tdata;
    (* keep *) wire m_axis_tvalid;
    wire s_axis_tready;

    siddham_npu_top #(
        .ARRAY_N(2)
    ) u_npu (
        .clk             (clk),
        .rst_n           (rst_n),
        .core_start      (core_start),
        .matrix_dim      (16'd2),
        .act_mode        (2'b01),
        .dma_start_rx    (1'b0),
        .dma_start_tx    (1'b0),
        .dma_base_addr   (32'd0),
        .dma_xfer_len    (16'd0),
        .dma_target_buf  (2'b00),
        .core_busy       (core_busy),
        .core_done       (core_done),
        .pl_ps_irq0      (pl_ps_irq0),
        .s_axis_tdata    (128'd0),
        .s_axis_tstrb    (16'hFFFF),
        .s_axis_tlast    (1'b0),
        .s_axis_tvalid   (1'b0),
        .s_axis_tready   (s_axis_tready),
        .m_axis_tdata    (m_axis_tdata),
        .m_axis_tstrb    (),
        .m_axis_tlast    (),
        .m_axis_tvalid   (m_axis_tvalid),
        .m_axis_tready   (1'b1)
    );

    assign status_leds[0] = core_busy;
    assign status_leds[1] = core_done;
    assign status_leds[2] = pl_ps_irq0;
    assign status_leds[3] = ^m_axis_tdata[7:0];

endmodule