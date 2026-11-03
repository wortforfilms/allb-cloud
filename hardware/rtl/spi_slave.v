// ============================================================================
// Module:      spi_slave
// Description: SPI mode 0 slave (CPOL 0, CPHA 0, MSB first), byte-wide, for a
//              microcontroller master (maataa-os on a NUCLEO-F411RE, SPI2).
//
// SCLK, CS and MOSI are sampled in the `clk` domain through two flip-flops
// each, so `clk` must be at least 8x SCLK (27 MHz clk: SCLK up to 3 MHz).
//
// Receive: rx_valid pulses for one clk with each complete byte (rx_byte).
// Transmit: the slave asks for the byte it will send next through tx_idx
//   (combinational) and samples tx_byte in the same clk:
//     - when CS falls it loads byte 0 and puts its MSB on MISO at once, so
//       the master's first rising edge reads it (mode 0);
//     - on the 8th rising edge of each byte it loads byte n+1, whose MSB goes
//       out on the following falling edge.
//   The top level answers tx_idx with a plain combinational read.
// frame_start / frame_end pulse when CS falls / rises; rx_count is the
// number of bytes received in the current (or just finished) frame.
//
// siddham_spi_bridge.v is not used here: its MISO side reloads its shift
// register whenever s_axis_tvalid is high and tready is low, so with a
// source that keeps tvalid high it reloads every second clk, in the middle
// of a byte.
// ============================================================================
`timescale 1ns / 1ps

module spi_slave (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       spi_sclk,
    input  wire       spi_cs_n,
    input  wire       spi_mosi,
    output reg        spi_miso,

    output reg        frame_start,
    output reg        frame_end,
    output reg        rx_valid,
    output reg  [7:0] rx_byte,
    output reg  [7:0] rx_count,

    output wire [7:0] tx_idx,
    input  wire [7:0] tx_byte
);
    reg [2:0] sclk_s, cs_s;
    reg [1:0] mosi_s;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_s <= 3'b000; cs_s <= 3'b111; mosi_s <= 2'b00;
        end else begin
            sclk_s <= {sclk_s[1:0], spi_sclk};
            cs_s   <= {cs_s[1:0], spi_cs_n};
            mosi_s <= {mosi_s[0], spi_mosi};
        end
    end
    // Edges are taken between the 2nd and 3rd stage; MOSI from its 2nd stage
    // lines up with the SCLK edge seen.
    wire sclk_rise = sclk_s[2:1] == 2'b01;
    wire sclk_fall = sclk_s[2:1] == 2'b10;
    wire cs_fall   = cs_s[2:1] == 2'b10;
    wire cs_rise   = cs_s[2:1] == 2'b01;
    wire active    = ~cs_s[1];
    wire mosi      = mosi_s[1];

    reg [2:0] bit_n;
    reg [6:0] rx_sh;
    reg [7:0] tx_sh;
    reg [7:0] byte_n;                     // index of the byte now being sent
    wire last_bit = active && sclk_rise && bit_n == 3'd7;
    assign tx_idx = cs_fall ? 8'd0 : byte_n + 8'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_miso <= 1'b0; frame_start <= 1'b0; frame_end <= 1'b0;
            rx_valid <= 1'b0; rx_byte <= 8'd0; rx_count <= 8'd0;
            bit_n <= 3'd0; rx_sh <= 7'd0; tx_sh <= 8'd0; byte_n <= 8'd0;
        end else begin
            frame_start <= cs_fall;
            frame_end   <= cs_rise;
            rx_valid    <= 1'b0;
            if (cs_fall) begin
                bit_n    <= 3'd0;
                byte_n   <= 8'd0;
                rx_count <= 8'd0;
                spi_miso <= tx_byte[7];
                tx_sh    <= {tx_byte[6:0], 1'b0};
            end else if (active) begin
                if (sclk_rise) begin
                    bit_n <= bit_n + 3'd1;
                    rx_sh <= {rx_sh[5:0], mosi};
                    if (last_bit) begin
                        rx_byte  <= {rx_sh, mosi};
                        rx_valid <= 1'b1;
                        rx_count <= rx_count + 8'd1;
                        byte_n   <= byte_n + 8'd1;
                        tx_sh    <= tx_byte;     // byte n+1; its MSB goes out next
                    end
                end
                if (sclk_fall) begin
                    spi_miso <= tx_sh[7];
                    tx_sh    <= {tx_sh[6:0], 1'b0};
                end
            end
        end
    end
endmodule
