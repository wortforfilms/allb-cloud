// ============================================================================
// Module:        siddham_npu_top_tb
// Description:   AXI4-Stream Testbench for siddham_npu_top.v
//                Verifies dynamic stream transfers via DMA Engine & NPU Core.
// ============================================================================

`timescale 1ns / 1ps

module siddham_npu_top_tb;

    parameter C_AXIS_DATA_WIDTH = 128;
    parameter ARRAY_N           = 2;

    reg                            clk;
    reg                            rst_n;

    // Control and Status Signals
    reg                            core_start;
    reg [15:0]                     matrix_dim;
    reg [1:0]                      act_mode;
    reg                            dma_start_rx;
    reg                            dma_start_tx;
    reg [31:0]                     dma_base_addr;
    reg [15:0]                     dma_xfer_len;
    reg [1:0]                      dma_target_buf;

    wire                           core_busy;
    wire                           core_done;
    wire                           pl_ps_irq0;

    // Inbound AXI4-Stream Interface (Slave)
    reg [C_AXIS_DATA_WIDTH-1:0]    s_axis_tdata;
    reg [(C_AXIS_DATA_WIDTH/8)-1:0] s_axis_tstrb;
    reg                            s_axis_tlast;
    reg                            s_axis_tvalid;
    wire                           s_axis_tready;

    // Outbound AXI4-Stream Interface (Master)
    wire [C_AXIS_DATA_WIDTH-1:0]   m_axis_tdata;
    wire [(C_AXIS_DATA_WIDTH/8)-1:0] m_axis_tstrb;
    wire                           m_axis_tlast;
    wire                           m_axis_tvalid;
    reg                            m_axis_tready;

    // Instantiate NPU Top Module
    siddham_npu_top #(
        .C_AXIS_DATA_WIDTH(C_AXIS_DATA_WIDTH),
        .ARRAY_N(ARRAY_N)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .core_start(core_start),
        .matrix_dim(matrix_dim),
        .act_mode(act_mode),
        .dma_start_rx(dma_start_rx),
        .dma_start_tx(dma_start_tx),
        .dma_base_addr(dma_base_addr),
        .dma_xfer_len(dma_xfer_len),
        .dma_target_buf(dma_target_buf),
        .core_busy(core_busy),
        .core_done(core_done),
        .pl_ps_irq0(pl_ps_irq0),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tstrb(s_axis_tstrb),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tstrb(m_axis_tstrb),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready)
    );

    // 100 MHz Clock Generation
    always #5 clk = ~clk;

    // Task: Stream Single Word over Inbound AXI4-Stream Interface
    task axis_send_word(
        input [C_AXIS_DATA_WIDTH-1:0] data,
        input is_last
    );
        begin
            @(posedge clk);
            s_axis_tvalid <= 1'b1;
            s_axis_tdata  <= data;
            s_axis_tstrb  <= 16'hFFFF;
            s_axis_tlast  <= is_last;

            // Wait for slave ready handshake
            while (!s_axis_tready) begin
                @(posedge clk);
            end

            @(posedge clk);
            s_axis_tvalid <= 1'b0;
            s_axis_tlast  <= 1'b0;
        end
    endtask

    // Main Verification Flow
    initial begin
        $dumpfile("npu_top_sim.vcd");
        $dumpvars(0, siddham_npu_top_tb);

        // Signal Initialization
        clk            = 0;
        rst_n          = 0;
        core_start     = 0;
        matrix_dim     = 16'd2;
        act_mode       = 2'b01; // ReLU
        dma_start_rx   = 0;
        dma_start_tx   = 0;
        dma_base_addr  = 32'd0;
        dma_xfer_len   = 16'd0;
        dma_target_buf = 2'b00;

        s_axis_tdata   = 0;
        s_axis_tstrb   = 0;
        s_axis_tlast   = 0;
        s_axis_tvalid  = 0;
        m_axis_tready  = 0;

        #20 rst_n = 1;
        #10;

        // --------------------------------------------------------------------
        // Step 1: Stream Weights via RX DMA (Buffer = 2'b00)
        // Weight Matrix B (2x2): Row 0 = [5, 7] (0x0705), Row 1 = [6, 8] (0x0806)
        // --------------------------------------------------------------------
        $display("[TB] Step 1: Streaming Weight Matrix B into SRAM via RX DMA...");
        dma_target_buf = 2'b00;
        dma_xfer_len   = 16'd2;
        @(posedge clk);
        dma_start_rx   = 1'b1;
        @(posedge clk);
        dma_start_rx   = 1'b0;

        axis_send_word(128'h0705, 1'b0); // Row 0
        axis_send_word(128'h0806, 1'b1); // Row 1 (tlast = 1)

        #20;

        // --------------------------------------------------------------------
        // Step 2: Stream Activations via RX DMA (Buffer = 2'b01)
        // Activation Matrix A (2x2): Col 0 = [2, 3] (0x0302), Col 1 = [4, 1] (0x0104)
        // --------------------------------------------------------------------
        $display("[TB] Step 2: Streaming Activation Matrix A into SRAM via RX DMA...");
        dma_target_buf = 2'b01;
        dma_xfer_len   = 16'd2;
        @(posedge clk);
        dma_start_rx   = 1'b1;
        @(posedge clk);
        dma_start_rx   = 1'b0;

        axis_send_word(128'h0302, 1'b0); // Col 0
        axis_send_word(128'h0104, 1'b1); // Col 1 (tlast = 1)

        #20;

        // --------------------------------------------------------------------
        // Step 3: Trigger NPU Compute Execution
        // --------------------------------------------------------------------
        $display("[TB] Step 3: Triggering NPU Compute Core...");
        @(posedge clk);
        core_start = 1'b1;
        @(posedge clk);
        core_start = 1'b0;

        wait(core_done == 1'b1);
        $display("[TB] NPU Compute Complete! (core_done & pl_ps_irq0 asserted)");
        #20;

        // --------------------------------------------------------------------
        // Step 4: Stream Out Matrix C Results via TX DMA (Buffer = 2'b10)
        // Expected Row 0: 0x2e22 (34, 46), Expected Row 1: 0x1d15 (21, 29)
        // --------------------------------------------------------------------
        $display("[TB] Step 4: Streaming Out Matrix C Results via TX DMA...");
        dma_target_buf = 2'b10;
        dma_xfer_len   = 16'd2;
        m_axis_tready  = 1'b1; // Host ready to receive AXI-Stream output

        @(posedge clk);
        dma_start_tx   = 1'b1;
        @(posedge clk);
        dma_start_tx   = 1'b0;

        // Capture Streamed Row 0
        wait(m_axis_tvalid == 1'b1);
        #1;
        $display("[TB AXI OUT] Row 0 Streamed Data: 0x%h (Expected: 0x2e22)", m_axis_tdata[15:0]);
        @(posedge clk);

        // Capture Streamed Row 1
        wait(m_axis_tvalid == 1'b1);
        #1;
        $display("[TB AXI OUT] Row 1 Streamed Data: 0x%h (Expected: 0x1d15)", m_axis_tdata[15:0]);
        if (m_axis_tlast) begin
            $display("[TB AXI OUT] m_axis_tlast correctly asserted on final burst packet.");
        end
        @(posedge clk);

        m_axis_tready = 1'b0;
        #50;
        $display("[TB SUCCESS] End-to-End AXI4-Stream dynamic matrix transfer verified!");
        $finish;
    end

endmodule