`timescale 1ns / 1ps

module siddham_npu_tb;

    parameter ARRAY_N    = 2;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH  = 32;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg  [15:0] matrix_dim;
    reg  [1:0]  act_mode;

    reg         w_buf_wr_en;
    reg  [0:0]  w_buf_addr;
    reg  [127:0] w_buf_wdata;

    reg         a_buf_wr_en;
    reg  [0:0]  a_buf_addr;
    reg  [127:0] a_buf_wdata;

    reg         out_buf_rd_en;
    reg  [0:0]  out_buf_addr;
    wire [127:0] out_buf_rdata;

    wire        core_busy;
    wire        core_done;

    // Instantiate Compute Core
    npu_compute_core #(
        .ARRAY_N(ARRAY_N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .matrix_dim(matrix_dim),
        .act_mode(act_mode),
        .w_buf_wr_en(w_buf_wr_en),
        .w_buf_addr(w_buf_addr),
        .w_buf_wdata(w_buf_wdata),
        .a_buf_wr_en(a_buf_wr_en),
        .a_buf_addr(a_buf_addr),
        .a_buf_wdata(a_buf_wdata),
        .out_buf_rd_en(out_buf_rd_en),
        .out_buf_addr(out_buf_addr),
        .out_buf_rdata(out_buf_rdata),
        .core_busy(core_busy),
        .core_done(core_done)
    );

    // 100 MHz Clock Generation
    always #5 clk = ~clk;

    initial begin
        $dumpfile("npu_sim.vcd");
        $dumpvars(0, siddham_npu_tb);

        clk           = 0;
        rst_n         = 0;
        start         = 0;
        matrix_dim    = 16'd2;
        act_mode      = 2'b01; // ReLU
        w_buf_wr_en   = 0;
        w_buf_addr    = 0;
        w_buf_wdata   = 0;
        a_buf_wr_en   = 0;
        a_buf_addr    = 0;
        a_buf_wdata   = 0;
        out_buf_rd_en = 0;
        out_buf_addr  = 0;

        #20 rst_n = 1;
        #10;

        // Load Matrix A (2x2): [[2, 4], [3, 1]]
        // Step 0: [A00, A10] -> 128'h0302
        // Step 1: [A01, A11] -> 128'h0104
        @(posedge clk);
        a_buf_wr_en <= 1; a_buf_addr <= 0; a_buf_wdata <= 128'h0302;
        @(posedge clk);
        a_buf_wr_en <= 1; a_buf_addr <= 1; a_buf_wdata <= 128'h0104;
        @(posedge clk);
        a_buf_wr_en <= 0;

        // Load Matrix B Rows (2x2): [[5, 7], [6, 8]]
        // Row 0 of B: [B00, B01] -> 128'h0705
        // Row 1 of B: [B10, B11] -> 128'h0806
        @(posedge clk);
        w_buf_wr_en <= 1; w_buf_addr <= 0; w_buf_wdata <= 128'h0705;
        @(posedge clk);
        w_buf_wr_en <= 1; w_buf_addr <= 1; w_buf_wdata <= 128'h0806;
        @(posedge clk);
        w_buf_wr_en <= 0;

        #10;
        @(posedge clk);
        start <= 1;
        @(posedge clk);
        start <= 0;

        wait(core_done == 1);
        #20;

        // Read Result Row 0
        @(posedge clk);
        out_buf_rd_en <= 1; out_buf_addr <= 0;
        @(posedge clk);
        #1;
        $display("[SIM COMPLETE] Result Row 0: 0x%h (Expected C[0][0]=34/0x22, C[0][1]=46/0x2E)", out_buf_rdata[15:0]);

        // Read Result Row 1
        @(posedge clk);
        out_buf_rd_en <= 1; out_buf_addr <= 1;
        @(posedge clk);
        #1;
        $display("[SIM COMPLETE] Result Row 1: 0x%h (Expected C[1][0]=21/0x15, C[1][1]=29/0x1D)", out_buf_rdata[15:0]);

        #20;
        $finish;
    end

endmodule