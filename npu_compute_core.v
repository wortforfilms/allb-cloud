// ============================================================================
// Module:      npu_compute_core
// Description: Synthesizable N x N Systolic Array Engine with Int8 SIMD 
//              Quantization, 32-Bit Accumulators, and Configurable Activations.
// Activation Modes (act_mode):
//   2'b00 : PASS_THROUGH (Linear / Bypass)
//   2'b01 : RELU         (max(0, x))
//   2'b10 : LEAKY_RELU   (x >= 0 ? x : x >>> 3)  [0.125 slope]
// ============================================================================

`timescale 1ns / 1ps

// ----------------------------------------------------------------------------
// Single Processing Element (PE) - Signed Int8 MAC with 32-Bit Accumulator
// ----------------------------------------------------------------------------
module processing_element #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   clr_acc,
    input  wire                   en,
    input  wire signed [DATA_WIDTH-1:0] in_a, // Signed Int8 Activation Input
    input  wire signed [DATA_WIDTH-1:0] in_b, // Signed Int8 Weight Input
    output reg  signed [DATA_WIDTH-1:0] out_a, // Systolic Pass Right
    output reg  signed [DATA_WIDTH-1:0] out_b, // Systolic Pass Down
    output reg  signed [ACC_WIDTH-1:0]  acc   // 32-Bit Signed Accumulator
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_a <= {DATA_WIDTH{1'b0}};
            out_b <= {DATA_WIDTH{1'b0}};
            acc   <= {ACC_WIDTH{1'b0}};
        end else if (clr_acc) begin
            acc   <= {ACC_WIDTH{1'b0}};
            out_a <= {DATA_WIDTH{1'b0}};
            out_b <= {DATA_WIDTH{1'b0}};
        end else if (en) begin
            out_a <= in_a;
            out_b <= in_b;
            // Signed Int8 x Int8 multiplication extended into 32-bit Accumulator
            acc   <= acc + ($signed(in_a) * $signed(in_b));
        end
    end

endmodule

// ----------------------------------------------------------------------------
// Activation Pipeline Unit (Int8 Quantized Saturation)
// ----------------------------------------------------------------------------
module activation_unit #(
    parameter ACC_WIDTH  = 32,
    parameter DATA_WIDTH = 8
)(
    input  wire signed [ACC_WIDTH-1:0]  in_data,
    input  wire [1:0]                   act_mode,
    output reg  signed [DATA_WIDTH-1:0] out_data
);

    wire signed [ACC_WIDTH-1:0] leaky_val = (in_data >= 0) ? in_data : (in_data >>> 3);
    reg  signed [ACC_WIDTH-1:0] activated_val;

    always @(*) begin
        case (act_mode)
            2'b01:   activated_val = (in_data > 0) ? in_data : {ACC_WIDTH{1'b0}}; // ReLU
            2'b10:   activated_val = leaky_val;                                   // Leaky ReLU (0.125)
            default: activated_val = in_data;                                     // Bypass / Linear
        endcase

        // Int8 Quantization & Saturation Logic (-128 to 127)
        if (activated_val > 32'sd127) begin
            out_data = 8'sd127;
        end else if (activated_val < -32'sd128) begin
            out_data = -8'sd128;
        end else begin
            out_data = activated_val[7:0];
        end
    end

endmodule

// ----------------------------------------------------------------------------
// Top-Level Compute Core Module
// ----------------------------------------------------------------------------
module npu_compute_core #(
    parameter ARRAY_N    = 16,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       start,
    input  wire [15:0]                matrix_dim,
    input  wire [1:0]                 act_mode, // 00: Bypass, 01: ReLU, 10: Leaky ReLU

    // Weight SRAM Write Interface (DMA In)
    input  wire                       w_buf_wr_en,
    input  wire [$clog2(ARRAY_N)-1:0] w_buf_addr,
    input  wire [63:0]                w_buf_wdata,

    // Activation SRAM Write Interface (DMA In)
    input  wire                       a_buf_wr_en,
    input  wire [$clog2(ARRAY_N)-1:0] a_buf_addr,
    input  wire [63:0]                a_buf_wdata,

    // Result SRAM Read Interface (DMA Out)
    input  wire                       out_buf_rd_en,
    input  wire [$clog2(ARRAY_N)-1:0] out_buf_addr,
    output wire [63:0]                out_buf_rdata,

    // Execution Flags
    output reg                        core_busy,
    output reg                        core_done
);

    // ------------------------------------------------------------------------
    // Local SRAM Buffers
    // ------------------------------------------------------------------------
    reg [63:0] weight_sram     [0:ARRAY_N-1];
    reg [63:0] activation_sram [0:ARRAY_N-1];
    reg [63:0] result_sram     [0:ARRAY_N-1];

    always @(posedge clk) begin
        if (w_buf_wr_en) weight_sram[w_buf_addr] <= w_buf_wdata;
        if (a_buf_wr_en) activation_sram[a_buf_addr] <= a_buf_wdata;
    end

    assign out_buf_rdata = (out_buf_rd_en) ? result_sram[out_buf_addr] : 64'h0;

    // ------------------------------------------------------------------------
    // Interconnects & Processing Elements
    // ------------------------------------------------------------------------
    wire signed [DATA_WIDTH-1:0] pe_a_wire [0:ARRAY_N-1][0:ARRAY_N];
    wire signed [DATA_WIDTH-1:0] pe_b_wire [0:ARRAY_N][0:ARRAY_N-1];
    wire signed [ACC_WIDTH-1:0]  pe_acc    [0:ARRAY_N-1][0:ARRAY_N-1];
    wire signed [DATA_WIDTH-1:0] pe_act_out[0:ARRAY_N-1][0:ARRAY_N-1];

    reg  pe_clr_acc;
    reg  pe_en;

    genvar i;
    generate
        for (i = 0; i < ARRAY_N; i = i + 1) begin : BOUNDARY_FEED
            assign pe_a_wire[i][0] = pe_en ? activation_sram[i][(DATA_WIDTH-1):0] : {DATA_WIDTH{1'b0}};
            assign pe_b_wire[0][i] = pe_en ? weight_sram[i][(DATA_WIDTH-1):0]     : {DATA_WIDTH{1'b0}};
        end
    endgenerate

    genvar r, c;
    generate
        for (r = 0; r < ARRAY_N; r = r + 1) begin : ROW
            for (c = 0; c < ARRAY_N; c = c + 1) begin : COL
                processing_element #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) u_pe (
                    .clk     (clk),
                    .rst_n   (rst_n),
                    .clr_acc (pe_clr_acc),
                    .en      (pe_en),
                    .in_a    (pe_a_wire[r][c]),
                    .in_b    (pe_b_wire[r][c]),
                    .out_a   (pe_a_wire[r][c+1]),
                    .out_b   (pe_b_wire[r+1][c]),
                    .acc     (pe_acc[r][c])
                );

                activation_unit #(
                    .ACC_WIDTH(ACC_WIDTH),
                    .DATA_WIDTH(DATA_WIDTH)
                ) u_act (
                    .in_data  (pe_acc[r][c]),
                    .act_mode (act_mode),
                    .out_data (pe_act_out[r][c])
                );
            end
        end
    endgenerate

// ------------------------------------------------------------------------
    // State Machine
    // ------------------------------------------------------------------------
    localparam STATE_IDLE = 2'b00;
    localparam STATE_RUN  = 2'b01;
    localparam STATE_DONE = 2'b10;

    reg [1:0]  state;
    reg [15:0] cycle_cnt;
    wire [15:0] total_cycles = matrix_dim + (3 * ARRAY_N) - 2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= STATE_IDLE;
            cycle_cnt  <= 16'd0;
            pe_en      <= 1'b0;
            pe_clr_acc <= 1'b1;
            core_busy  <= 1'b0;
            core_done  <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    core_done <= 1'b0;
                    if (start) begin
                        state      <= STATE_RUN;
                        cycle_cnt  <= 16'd0;
                        pe_clr_acc <= 1'b1;
                        pe_en      <= 1'b0;
                        core_busy  <= 1'b1;
                    end else begin
                        core_busy  <= 1'b0;
                        pe_clr_acc <= 1'b0;
                    end
                end

                STATE_RUN: begin
                    pe_clr_acc <= 1'b0;
                    pe_en      <= 1'b1;
                    cycle_cnt  <= cycle_cnt + 1'b1;

                    if (cycle_cnt >= total_cycles) begin
                        state <= STATE_DONE;
                        pe_en <= 1'b0;
                    end
                end

                STATE_DONE: begin
                    // Write Int8 quantized post-activation outputs to Result SRAM
                    result_sram[0] <= {48'b0, pe_act_out[0][1], pe_act_out[0][0]};
                    result_sram[1] <= {48'b0, pe_act_out[1][1], pe_act_out[1][0]};

                    core_busy <= 1'b0;
                    core_done <= 1'b1;
                    state     <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule