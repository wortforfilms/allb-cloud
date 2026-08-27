`timescale 1ns / 1ps

module siddham_spi_bridge #(
    parameter integer DATA_WIDTH = 8
)(
    input  wire                  clk_sys,
    input  wire                  rst_n,
    input  wire                  spi_sclk,
    input  wire                  spi_cs_n,
    input  wire                  spi_mosi,
    output reg                   spi_miso,

    output reg  [DATA_WIDTH-1:0] m_axis_tdata,
    output reg                   m_axis_tvalid,
    input  wire                  m_axis_tready,
    output reg                   m_axis_tlast,

    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                  s_axis_tvalid,
    output reg                   s_axis_tready,
    input  wire                  s_axis_tlast
);

    // 2-Stage CDC Synchronizers
    reg [1:0] sclk_sync;
    reg [1:0] cs_sync;
    reg [1:0] mosi_sync;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync <= 2'b00;
            cs_sync   <= 2'b11;
            mosi_sync <= 2'b00;
        end else begin
            sclk_sync <= {sclk_sync[0], spi_sclk};
            cs_sync   <= {cs_sync[0], spi_cs_n};
            mosi_sync <= {mosi_sync[0], spi_mosi};
        end
    end

    wire sclk_rising  = (sclk_sync == 2'b01);
    wire sclk_falling = (sclk_sync == 2'b10);
    wire cs_active    = ~cs_sync[0];
    wire cs_falling   = (cs_sync == 2'b10);
    wire cs_rising    = (cs_sync == 2'b01);
    wire mosi_bit     = mosi_sync[0];

    reg [2:0]            bit_cnt;
    reg [DATA_WIDTH-1:0] rx_shift_reg;
    reg [DATA_WIDTH-1:0] tx_shift_reg;

    // MOSI Deserializer
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt       <= 3'b000;
            rx_shift_reg  <= {DATA_WIDTH{1'b0}};
            m_axis_tdata  <= {DATA_WIDTH{1'b0}};
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end

            if (cs_falling) begin
                bit_cnt <= 3'b000;
            end else if (cs_active) begin
                if (sclk_rising) begin
                    rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-2:0], mosi_bit};
                    bit_cnt      <= bit_cnt + 1'b1;

                    if (bit_cnt == 3'b111) begin
                        m_axis_tdata  <= {rx_shift_reg[DATA_WIDTH-2:0], mosi_bit};
                        m_axis_tvalid <= 1'b1;
                    end
                end
            end else if (cs_rising) begin
                if (m_axis_tvalid) begin
                    m_axis_tlast <= 1'b1;
                end
            end
        end
    end

    // MISO Serializer
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            tx_shift_reg  <= {DATA_WIDTH{1'b0}};
            spi_miso      <= 1'b0;
            s_axis_tready <= 1'b0;
        end else begin
            if (!cs_active) begin
                spi_miso      <= 1'b0;
                s_axis_tready <= 1'b0;
            end else begin
                if (s_axis_tvalid && !s_axis_tready) begin
                    tx_shift_reg  <= s_axis_tdata << 1;
                    spi_miso      <= s_axis_tdata[DATA_WIDTH-1];
                    s_axis_tready <= 1'b1;
                end else begin
                    s_axis_tready <= 1'b0;
                end

                if (sclk_falling) begin
                    spi_miso     <= tx_shift_reg[DATA_WIDTH-1];
                    tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0], 1'b0};
                end
            end
        end
    end

endmodule