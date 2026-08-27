`timescale 1ns / 1ps

module tb_siddham_spi_bridge;

    parameter DATA_WIDTH       = 8;
    parameter CLK_SYS_PERIOD   = 7.22;
    parameter SCLK_HALF_PERIOD = 20.0;

    reg                  clk_sys;
    reg                  rst_n;
    reg                  spi_sclk;
    reg                  spi_cs_n;
    reg                  spi_mosi;
    wire                 spi_miso;

    wire [DATA_WIDTH-1:0] m_axis_tdata;
    wire                  m_axis_tvalid;
    reg                   m_axis_tready;
    wire                  m_axis_tlast;

    reg  [DATA_WIDTH-1:0] s_axis_tdata;
    reg                   s_axis_tvalid;
    wire                  s_axis_tready;
    reg                   s_axis_tlast;

    integer error_count = 0;
    reg [7:0] miso_captured_byte;

    siddham_spi_bridge #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk_sys       (clk_sys),
        .rst_n         (rst_n),
        .spi_sclk      (spi_sclk),
        .spi_cs_n      (spi_cs_n),
        .spi_mosi      (spi_mosi),
        .spi_miso      (spi_miso),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .m_axis_tlast  (m_axis_tlast),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tlast  (s_axis_tlast)
    );

    initial begin
        clk_sys = 1'b0;
        forever #(CLK_SYS_PERIOD / 2.0) clk_sys = ~clk_sys;
    end

    task spi_transfer_byte;
        input  [7:0] tx_mosi_byte;
        output [7:0] rx_miso_byte;
        integer i;
        begin
            rx_miso_byte = 8'h00;
            for (i = 7; i >= 0; i = i - 1) begin
                spi_mosi = tx_mosi_byte[i];
                #SCLK_HALF_PERIOD;

                spi_sclk = 1'b1;
                #(CLK_SYS_PERIOD * 3);
                rx_miso_byte[i] = spi_miso;
                #(SCLK_HALF_PERIOD - (CLK_SYS_PERIOD * 3));

                spi_sclk = 1'b0;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_siddham_spi_bridge.vcd");
        $dumpvars(0, tb_siddham_spi_bridge);

        rst_n         = 1'b0;
        spi_sclk      = 1'b0;
        spi_cs_n      = 1'b1;
        spi_mosi      = 1'b0;
        m_axis_tready = 1'b1;
        s_axis_tdata  = 8'h00;
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;

        $display("==================================================");
        $display("STARTING SIDDHAM SPI BRIDGE TESTBENCH SIMULATION");
        $display("==================================================");

        #(CLK_SYS_PERIOD * 10);
        rst_n = 1'b1;
        #(CLK_SYS_PERIOD * 10);

        // TEST 1
        $display("[TEST 1] Transmitting Single Byte 0xA5 over MOSI...");
        spi_cs_n = 1'b0;
        #(CLK_SYS_PERIOD * 4);

        spi_transfer_byte(8'hA5, miso_captured_byte);

        wait(m_axis_tvalid == 1'b1);
        if (m_axis_tdata === 8'hA5) begin
            $display("[PASS] AXI-Stream Master captured byte: 0x%02X", m_axis_tdata);
        end else begin
            $display("[FAIL] Data Mismatch! Expected: 0xA5, Captured: 0x%02X", m_axis_tdata);
            error_count = error_count + 1;
        end

        #SCLK_HALF_PERIOD;
        spi_cs_n = 1'b1;
        #(CLK_SYS_PERIOD * 10);

        // TEST 2
        $display("[TEST 2] Transmitting 2-Byte Burst: 0x3C, 0x7E...");
        spi_cs_n = 1'b0;
        #(CLK_SYS_PERIOD * 4);

        spi_transfer_byte(8'h3C, miso_captured_byte);
        wait(m_axis_tvalid == 1'b1);
        if (m_axis_tdata === 8'h3C) begin
            $display("[PASS] Byte 1 Matched: 0x%02X", m_axis_tdata);
        end else begin
            $display("[FAIL] Byte 1 Mismatch! Expected 0x3C, Got 0x%02X", m_axis_tdata);
            error_count = error_count + 1;
        end

        spi_transfer_byte(8'h7E, miso_captured_byte);
        wait(m_axis_tvalid == 1'b1);
        if (m_axis_tdata === 8'h7E) begin
            $display("[PASS] Byte 2 Matched: 0x%02X", m_axis_tdata);
        end else begin
            $display("[FAIL] Byte 2 Mismatch! Expected 0x7E, Got 0x%02X", m_axis_tdata);
            error_count = error_count + 1;
        end

        spi_cs_n = 1'b1;
        #(CLK_SYS_PERIOD * 10);

        // TEST 3
        $display("[TEST 3] Staging AXI RX Payload 0xDE for MISO Serialization...");
        s_axis_tdata  = 8'hDE;
        s_axis_tvalid = 1'b1;

        spi_cs_n = 1'b0;
        #(CLK_SYS_PERIOD * 4);

        spi_transfer_byte(8'h00, miso_captured_byte);

        if (miso_captured_byte === 8'hDE) begin
            $display("[PASS] MISO Readback matched AXI RX payload: 0x%02X", miso_captured_byte);
        end else begin
            $display("[FAIL] MISO Readback Mismatch! Expected 0xDE, Got 0x%02X", miso_captured_byte);
            error_count = error_count + 1;
        end

        spi_cs_n = 1'b1;
        s_axis_tvalid = 1'b0;
        #(CLK_SYS_PERIOD * 10);

        $display("==================================================");
        if (error_count == 0) begin
            $display("SIMULATION RESULT: PASSED (0 Errors)");
        end else begin
            $display("SIMULATION RESULT: FAILED (%0d Errors)", error_count);
        end
        $display("==================================================");

        $finish;
    end

endmodule