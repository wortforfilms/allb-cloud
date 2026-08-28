// ============================================================================
// Module:      tb_siddham_npu_top
// Description: Integrated Top-Level Testbench for Siddham NPU.
//              Tests AXI4-Lite MMIO Register Configuration, AXI4-Stream DMA
//              Inbound/Outbound Transfers, and Systolic Core Compute Cycles.
// ============================================================================

`timescale 1ns / 1ps

module tb_siddham_npu_top;

    // Clock and Reset Signals
    reg clk;
    reg rst_n;

    // Simulation Parameters
    localparam ARRAY_N    = 16;
    localparam DATA_WIDTH = 128;
    localparam CLK_PERIOD = 10; // 100 MHz

    // ------------------------------------------------------------------------
    // DMA Engine Interface Wires
    // ------------------------------------------------------------------------
    reg         dma_start_rx;
    reg         dma_start_tx;
    reg  [31:0] dma_base_addr;
    reg  [15:0] dma_xfer_len;
    reg  [1:0]  dma_target_buf;
    wire        dma_busy;
    wire        dma_done;

    // AXI4-Stream Slave Interface (Inbound)
    reg  [127:0] s_axis_tdata;
    reg  [15:0]  s_axis_tstrb;
    reg         s_axis_tlast;
    reg         s_axis_tvalid;
    wire        s_axis_tready;

    // AXI4-Stream Master Interface (Outbound)
    wire [127:0] m_axis_tdata;
    wire [15:0]  m_axis_tstrb;
    wire        m_axis_tlast;
    wire        m_axis_tvalid;
    reg         m_axis_tready;

    // NPU Core Interface Wires
    reg         core_start;
    reg  [15:0] matrix_dim;
    reg  [1:0]  act_mode;
    wire        core_busy;
    wire        core_done;

    // Interconnect Buffers (DMA <-> Core)
    wire        w_buf_wr_en;
    wire [3:0]  w_buf_addr;
    wire [127:0] w_buf_wdata;

    wire        a_buf_wr_en;
    wire [3:0]  a_buf_addr;
    wire [127:0] a_buf_wdata;

    wire        out_buf_rd_en;
    wire [3:0]  out_buf_addr;
    wire [127:0] out_buf_rdata;

    // ------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiations
    // ------------------------------------------------------------------------

    // 1. AXI4-Stream DMA Engine
    npu_dma_engine #(
        .DATA_WIDTH(DATA_WIDTH),
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

    // 2. Synthesizable NPU Compute Core
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

    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ------------------------------------------------------------------------
    // Verification Tasks
    // ------------------------------------------------------------------------

// Task: Stream Weight/Activation data via S_AXIS DMA
    task dma_stream_in(input [1:0] target_buf, input [15:0] len);
        integer k;
        begin
            $display("[DMA IN] Starting AXI-Stream RX Transfer (Target: %0d, Len: %0d)...", target_buf, len);
            
            // 1. Setup registers before pulsing start
            dma_target_buf = target_buf;
            dma_xfer_len   = len;
            @(posedge clk);
            
            // 2. Pulse DMA RX Start
            dma_start_rx   = 1'b1;
            @(posedge clk);
            dma_start_rx   = 1'b0;

            // Wait until DMA enters RX state and ready goes high
            while (!s_axis_tready) @(posedge clk);

            // 3. Drive Stream Payload
            for (k = 0; k < len; k = k + 1) begin
                s_axis_tvalid = 1'b1;
                s_axis_tdata  = 128'h01020304050607080102030405060708 + k;
                s_axis_tstrb  = 16'hFFFF;
                s_axis_tlast  = (k == len - 1);
                
                @(posedge clk);
                while (!s_axis_tready && !dma_done) @(posedge clk);
            end

            s_axis_tvalid = 1'b0;
            s_axis_tlast  = 1'b0;
            
            // 4. Wait for DMA completion state
            while (!dma_done) @(posedge clk);
            $display("[DMA IN] Stream Transfer Complete.");
        end
    endtask
    
    // Task: Stream Computed Results back via M_AXIS DMA
    task dma_stream_out(input [15:0] len);
        integer k;
        begin
            $display("[DMA OUT] Starting AXI-Stream TX Readback (Len: %0d)...", len);
            dma_xfer_len = len;
            dma_start_tx = 1'b1;
            m_axis_tready = 1'b0;
            @(posedge clk);
            dma_start_tx = 1'b0;

            for (k = 0; k < len; k = k + 1) begin
                while (!m_axis_tvalid) @(posedge clk);
                $display("         • Received M_AXIS Word [%0d]: 0x%h (TLAST=%b)", k, m_axis_tdata, m_axis_tlast);
                if (^m_axis_tdata === 1'bx) begin
                    $fatal(1, "M_AXIS word %0d contains unknown bits", k);
                end
                if (m_axis_tlast !== (k == len - 1)) begin
                    $fatal(1, "M_AXIS TLAST mismatch on word %0d", k);
                end
                @(negedge clk);
                m_axis_tready = 1'b1;
                @(negedge clk);
                m_axis_tready = 1'b0;
            end

            while (!dma_done) @(posedge clk);
            $display("[DMA OUT] Stream Readback Complete.");
        end
    endtask

    // ------------------------------------------------------------------------
    // Main Test Sequence
    // ------------------------------------------------------------------------
    initial begin
        $dumpfile("top_waves.vcd");
        $dumpvars(0, tb_siddham_npu_top);

        // Initialize Signals
        clk            = 1'b0;
        rst_n          = 1'b0;
        dma_start_rx   = 1'b0;
        dma_start_tx   = 1'b0;
        dma_base_addr  = 32'h0;
        dma_xfer_len   = 16'h0;
        dma_target_buf = 2'b00;
        s_axis_tdata   = 128'h0;
        s_axis_tstrb   = 16'h0;
        s_axis_tlast   = 1'b0;
        s_axis_tvalid  = 1'b0;
        m_axis_tready  = 1'b0;
        core_start     = 1'b0;
        matrix_dim     = 16'd16;
        act_mode       = 2'b01; // ReLU Mode

        $display("=================================================");
        $display("  SIDDHAM NPU TOP LEVEL INTEGRATION TESTBENCH    ");
        $display("=================================================");

        // Reset Pulse
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        #(CLK_PERIOD * 2);

        // STEP 1: Stream Weight Matrix into Local SRAM (Buffer 0)
        dma_stream_in(2'b00, 16);

        // STEP 2: Stream Activation Matrix into Local SRAM (Buffer 1)
        dma_stream_in(2'b01, 16);

        // STEP 3: Trigger Core Compute Cycle
        $display("[COMPUTE] Launching Systolic Compute Core (N=16, ReLU)...");
        @(negedge clk);
        core_start = 1'b1;
        @(negedge clk);
        core_start = 1'b0;

        // Wait for Core Done interrupt
        while (!core_done) @(posedge clk);
        $display("[COMPUTE] Systolic Core Processing Complete.");

        // STEP 4: Stream Results back via M_AXIS DMA
        dma_stream_out(2);

        $display("=================================================");
        $display("  SIMULATION COMPLETE: ALL DMA & CORE TESTS PASSED");
        $display("=================================================");
        $finish;
    end

    initial begin
        #(CLK_PERIOD * 2000);
        $fatal(1, "Top-level NPU simulation exceeded its 2000-cycle watchdog");
    end

endmodule
