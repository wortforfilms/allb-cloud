// ============================================================================
// Module:        ecp5_top_wrapper
// Description:   Dynamic Stimulus I/O Wrapper to Prevent Array Pruning
// ============================================================================

`timescale 1ns / 1ps

module ecp5_top_wrapper (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       btn_start,
    output wire [3:0] status_leds
);

    localparam ARRAY_SIZE = 4;

    reg  [15:0]  timer_cnt;
    reg  [127:0] s_axis_tdata;
    reg          dma_trig;

    wire [127:0] m_axis_tdata;
    wire         m_axis_tvalid;
    wire         m_axis_tlast;
    wire         core_busy;
    wire         core_done;
    wire         pl_ps_irq0;

    // XOR reduction across output bits prevents dead-code elimination
    wire data_xor = ^m_axis_tdata;

    assign status_leds[0] = core_busy;
    assign status_leds[1] = core_done;
    assign status_leds[2] = pl_ps_irq0 ^ data_xor;
    assign status_leds[3] = m_axis_tvalid;

    // Free-running dynamic stimulus sequence
    always @(posedge clk) begin
        if (!rst_n) begin
            timer_cnt    <= 16'd0;
            s_axis_tdata <= 128'd0;
            dma_trig     <= 1'b0;
        end else begin
            timer_cnt    <= timer_cnt + 1'b1;
            s_axis_tdata <= s_axis_tdata + timer_cnt;
            dma_trig     <= (timer_cnt == 16'h00FF) | btn_start;
        end
    end

// Inside ecp5_top_wrapper.v
localparam ARRAY_SIZE = 16; // Set array size to 16x16

siddham_npu_top #(
    .C_AXIS_DATA_WIDTH(128),
    .ARRAY_N(ARRAY_SIZE)
) u_npu (
    .clk(clk),
    .rst_n(rst_n),
    .core_start(dma_trig),
    .matrix_dim(16'd16),    // Update run dimension to match 16 steps
    .act_mode(2'b01),
    .dma_start_rx(dma_trig),
    .dma_start_tx(dma_trig),
    .dma_base_addr(32'd0),
    .dma_xfer_len(16'd16),
    .dma_target_buf(2'b00),
    .core_busy(core_busy),
    .core_done(core_done),
    .pl_ps_irq0(pl_ps_irq0),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tstrb(16'hFFFF),
    .s_axis_tlast(timer_cnt[3]),
    .s_axis_tvalid(dma_trig),
    .s_axis_tready(),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tstrb(),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(1'b1)
);

endmodule