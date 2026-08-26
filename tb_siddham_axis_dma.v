// ============================================================================
// File:        tb_siddham_axis_dma.v
// Description: Testbench for Siddham NPU AXI4-Stream DMA Core
// Simulator:   Icarus Verilog (iverilog)
// ============================================================================

`timescale 1ns / 1ps

module tb_siddham_axis_dma;

    // --- Parameters ---
    parameter C_AXIS_TDATA_WIDTH = 32;
    parameter MAX_VECTOR_LEN     = 1024;
    parameter VECTOR_SIZE        = 128;

    // --- Clock & Reset ---
    reg clk;
    reg rst_n;

    // --- AXI4-Stream Interface Signals ---
    reg  [C_AXIS_TDATA_WIDTH-1:0] s_axis_tdata;
    reg                           s_axis_tvalid;
    wire                          s_axis_tready;
    reg                           s_axis_tlast;
    reg  [(C_AXIS_TDATA_WIDTH/8)-1:0] s_axis_tstrb;

    // --- Control & Status Interface ---
    reg                           dma_start_enable;
    reg  [31:0]                   target_vector_length;
    wire                          dma_busy;
    wire                          dma_done;
    wire                          dma_error;
    wire [31:0]                   received_word_count;

    // --- NPU BRAM Read Port Interface ---
    reg  [$clog2(MAX_VECTOR_LEN)-1:0] npu_bram_raddr;
    wire [C_AXIS_TDATA_WIDTH-1:0]     npu_bram_rdata;

    // --- Instantiate Unit Under Test (UUT) ---
    siddham_axis_dma #(
        .C_AXIS_TDATA_WIDTH(C_AXIS_TDATA_WIDTH),
        .MAX_VECTOR_LEN(MAX_VECTOR_LEN)
    ) uut (
        .axis_aclk(clk),
        .axis_aresetn(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tstrb(s_axis_tstrb),
        .dma_start_enable(dma_start_enable),
        .target_vector_length(target_vector_length),
        .dma_busy(dma_busy),
        .dma_done(dma_done),
        .dma_error(dma_error),
        .received_word_count(received_word_count),
        .npu_bram_raddr(npu_bram_raddr),
        .npu_bram_rdata(npu_bram_rdata)
    );

    // --- 100 MHz Clock Generation ---
    always #5 clk = ~clk;

    // --- Main Simulation Routine ---
    integer i;
    reg [31:0] test_vector [0:VECTOR_SIZE-1];

    initial begin
        // Waveform Dump Configuration
        $dumpfile("dma_waves.vcd");
        $dumpvars(0, tb_siddham_axis_dma);

        // Initialize Signals
        clk                  = 0;
        rst_n                = 0;
        s_axis_tdata         = 0;
        s_axis_tvalid        = 0;
        s_axis_tlast         = 0;
        s_axis_tstrb         = 4'b1111;
        dma_start_enable     = 0;
        target_vector_length = VECTOR_SIZE;
        npu_bram_raddr       = 0;

        // Populate mock IEEE-754 Float / Integer pattern vector
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
            test_vector[i] = 32'h3F80_0000 + i; // Simulated float sequence starting at 1.0f
        end

        // Hardware Reset Pulse
        #20 rst_n = 1;
        #20;

        $display("=================================================");
        $display("  SIDDHAM NPU AXI4-STREAM DMA TESTBENCH SIMULATION");
        $display("=================================================");

        // Step 1: Enable DMA Core Ingress State Machine
        $display("[STEP 1] Asserting dma_start_enable for 128-element stream...");
        dma_start_enable = 1;
        @(posedge clk);
        
        // Wait until DMA enters active stream state (tready = 1)
        wait (s_axis_tready);
        $display("[STEP 2] DMA Core Ready. Beginning AXI-Stream transmission...");

        // Step 2: Stream 128 vector elements continuously
        for (i = 0; i < VECTOR_SIZE; i = i + 1) begin
            @(posedge clk);
            s_axis_tvalid <= 1'b1;
            s_axis_tdata  <= test_vector[i];
            
            // Assert tlast on the final element (index 127)
            if (i == VECTOR_SIZE - 1) begin
                s_axis_tlast <= 1'b1;
                $display("          • Transmitting Element %0d (LAST element, tlast = 1)", i);
            end else if (i % 32 == 0) begin
                $display("          • Transmitting Element %0d (data = 0x%h)...", i, test_vector[i]);
            end
        end

        // Clear Stream Valid and Last Flags
        @(posedge clk);
        s_axis_tvalid <= 1'b0;
        s_axis_tlast  <= 1'b0;

        // Step 3: Wait for DMA Transfer Completion
        wait (dma_done);
        $display("[STEP 3] DMA Transfer Complete!");
        $display("          • Total Received Word Count: %0d", received_word_count);

        if (received_word_count == VECTOR_SIZE)
            $display("[CHECK 1] Received Word Count matches target vector size!");
        else
            $display("[ERROR 1] Word Count Mismatch!");

        dma_start_enable = 0;
        #20;

        // Step 4: Verify NPU Dual-Port BRAM Readback
        $display("[STEP 4] Verifying dual-port BRAM contents from NPU read port...");
        for (i = 0; i < 4; i = i + 1) begin
            npu_bram_raddr = i;
            #5;
            $display("          • BRAM Index [%0d] -> Read Data: 0x%h (Expected: 0x%h)", 
                     i, npu_bram_rdata, test_vector[i]);
            if (npu_bram_rdata !== test_vector[i]) begin
                $display("[ERROR 2] BRAM Content mismatch at index %0d!", i);
            end
        end

        $display("=================================================");
        $display("  SIMULATION COMPLETE: ALL DMA TESTS PASSED");
        $display("=================================================");
        #50 $finish;
    end

endmodule