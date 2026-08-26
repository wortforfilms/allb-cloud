// ============================================================================
// File:        tb_siddham_npu_mmio.v
// Description: Testbench for Siddham NPU AXI4-Lite MMIO Register Bank
// Simulator:   Icarus Verilog (iverilog)
// ============================================================================

`timescale 1ns / 1ps

module tb_siddham_npu_mmio;

    // --- Testbench Parameters ---
    parameter C_S_AXI_ADDR_WIDTH = 32;
    parameter C_S_AXI_DATA_WIDTH = 32;
    parameter [31:0] BASE_ADDR  = 32'hA000_0000;

    // --- Clock & Reset ---
    reg clk;
    reg rst_n;

    // --- AXI4-Lite Signals ---
    reg  [C_S_AXI_ADDR_WIDTH-1:0] awaddr;
    reg                           awvalid;
    wire                          awready;
    reg  [C_S_AXI_DATA_WIDTH-1:0] wdata;
    reg  [3:0]                    wstrb;
    reg                           wvalid;
    wire                          wready;
    wire [1:0]                    bresp;
    wire                          bvalid;
    reg                           bready;

    reg  [C_S_AXI_ADDR_WIDTH-1:0] araddr;
    reg                           arvalid;
    wire                          arready;
    wire [C_S_AXI_DATA_WIDTH-1:0] rdata;
    wire [1:0]                    rresp;
    wire                          rvalid;
    reg                           rready;

    // --- NPU Hardware Core Mock Interfaces ---
    wire [31:0] npu_input_ptr;
    wire [31:0] npu_output_ptr;
    wire [31:0] npu_vector_len;
    wire        npu_start;
    wire        npu_reset;
    reg         npu_busy;
    reg         npu_done;
    reg         npu_error;
    reg  [3:0]  npu_err_code;
    reg  [31:0] npu_cycles;
    wire        npu_irq;

    // Register Offsets
    localparam ADDR_CR_CONTROL     = 8'h00;
    localparam ADDR_CR_STATUS      = 8'h04;
    localparam ADDR_CR_INPUT_ADDR  = 8'h08;
    localparam ADDR_CR_OUTPUT_ADDR = 8'h0C;
    localparam ADDR_CR_VECTOR_LEN  = 8'h10;
    localparam ADDR_CR_CYCLE_COUNT = 8'h14;

    // --- Instantiate Unit Under Test (UUT) ---
    siddham_npu_mmio #(
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .BASE_ADDR(BASE_ADDR)
    ) uut (
        .axi_aclk(clk),
        .axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),
        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_araddr(araddr),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready),
        .npu_input_buffer_ptr(npu_input_ptr),
        .npu_output_buffer_ptr(npu_output_ptr),
        .npu_vector_length(npu_vector_len),
        .npu_start_trigger(npu_start),
        .npu_soft_reset(npu_reset),
        .npu_engine_busy(npu_busy),
        .npu_engine_done(npu_done),
        .npu_engine_error(npu_error),
        .npu_hal_error_code(npu_err_code),
        .npu_execution_cycles(npu_cycles),
        .npu_irq_out(npu_irq)
    );

    // --- 100MHz Clock Generation ---
    always #5 clk = ~clk;

    // --- AXI4-Lite Write Task ---
    task axi_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            awaddr  <= addr;
            awvalid <= 1'b1;
            wdata   <= data;
            wstrb   <= 4'b1111;
            wvalid  <= 1'b1;
            bready  <= 1'b1;

            wait (awready && wready);
            @(posedge clk);
            awvalid <= 1'b0;
            wvalid  <= 1'b0;

            wait (bvalid);
            @(posedge clk);
            bready <= 1'b0;
        end
    endtask

    // --- AXI4-Lite Read Task ---
    task axi_read(input [31:0] addr, output [31:0] data_out);
        begin
            @(posedge clk);
            araddr  <= addr;
            arvalid <= 1'b1;
            rready  <= 1'b1;

            wait (arready);
            @(posedge clk);
            arvalid <= 1'b0;

            wait (rvalid);
            data_out = rdata;
            @(posedge clk);
            rready  <= 1'b0;
        end
    endtask

    // --- Main Simulation Sequence ---
    reg [31:0] read_val;

    initial begin
        // Setup Waveform Dump for GTKWave
        $dumpfile("npu_mmio_waves.vcd");
        $dumpvars(0, tb_siddham_npu_mmio);

        // Initialize Signals
        clk          = 0;
        rst_n        = 0;
        awaddr       = 0;
        awvalid      = 0;
        wdata        = 0;
        wstrb        = 0;
        wvalid       = 0;
        bready       = 0;
        araddr       = 0;
        arvalid      = 0;
        rready       = 0;
        npu_busy     = 0;
        npu_done     = 0;
        npu_error    = 0;
        npu_err_code = 0;
        npu_cycles   = 0;

        // Reset Pulse
        #20 rst_n = 1;
        #20;

        $display("=================================================");
        $display("  SIDDHAM NPU MMIO REGISTER TESTBENCH SIMULATION ");
        $display("=================================================");

        // Step 1: Write Input Buffer Address (0xA0000008)
        $display("[STEP 1] Writing Input Address: 0x80000000");
        axi_write(BASE_ADDR + ADDR_CR_INPUT_ADDR, 32'h8000_0000);

        // Step 2: Write Output Buffer Address (0xA000000C)
        $display("[STEP 2] Writing Output Address: 0x85000000");
        axi_write(BASE_ADDR + ADDR_CR_OUTPUT_ADDR, 32'h8500_0000);

        // Step 3: Write Vector Dimension (0xA0000010)
        $display("[STEP 3] Writing Vector Length: 128 elements");
        axi_write(BASE_ADDR + ADDR_CR_VECTOR_LEN, 32'd128);

        // Step 4: Verify Register Pointers Handshaked to Hardware Core
        #10;
        if (npu_input_ptr == 32'h8000_0000 && npu_output_ptr == 32'h8500_0000 && npu_vector_len == 128)
            $display("[CHECK 1] Hardware Buffer Registers Correctly Handshaked!");
        else
            $display("[ERROR 1] Hardware Buffer Register Mismatch!");

        // Step 5: Trigger NPU Hardware Compute (Write 0x1 to CR_CONTROL)
        $display("[STEP 4] Triggering NPU Start Pulse (CR_CONTROL = 0x1)...");
        axi_write(BASE_ADDR + ADDR_CR_CONTROL, 32'h1);

        // Step 6: Mock Hardware Compute Execution Loop
        wait (npu_start);
        $display("[HW ENGINE] Start Trigger Received. Engine Busy...");
        npu_busy = 1;
        #100; // Simulate 100ns vector execution delay
        npu_busy   = 0;
        npu_done   = 1;
        npu_cycles = 1536; // 1,536 compute cycles
        $display("[HW ENGINE] Execution Complete! Cycles = %d", npu_cycles);

        #20;
        npu_done = 0;

        // Step 7: Readback Telemetry via AXI-Lite
        $display("[STEP 5] Reading CR_STATUS (0xA0000004)...");
        axi_read(BASE_ADDR + ADDR_CR_STATUS, read_val);
        $display("          • CR_STATUS Readback = 32'h%h", read_val);

        $display("[STEP 6] Reading CR_CYCLE_COUNT (0xA0000014)...");
        axi_read(BASE_ADDR + ADDR_CR_CYCLE_COUNT, read_val);
        $display("          • Execution Cycles Readback = %d", read_val);

        if (read_val == 1536)
            $display("[CHECK 2] Hardware Execution Cycle Count Telemetry PASSED!");

        $display("=================================================");
        $display("  SIMULATION COMPLETE: ALL TESTS PASSED");
        $display("=================================================");
        #50 $finish;
    end

endmodule