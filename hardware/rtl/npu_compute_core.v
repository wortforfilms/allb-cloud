// ============================================================================
// Module:        npu_compute_core (Fixed Module Interface & Counter Bit-Widths)
// Description:   N x N Systolic Array Engine with Int8 SIMD Quantization.
// ============================================================================

`timescale 1ns / 1ps

// ----------------------------------------------------------------------------
// Single Processing Element (PE) - Signed Int8 MAC with 32-Bit Accumulator
// ----------------------------------------------------------------------------
module processing_element #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         clr_acc,
    input  wire                         en,
    input  wire signed [DATA_WIDTH-1:0] in_a,
    input  wire signed [DATA_WIDTH-1:0] in_b,
    output reg  signed [DATA_WIDTH-1:0] out_a,
    output reg  signed [DATA_WIDTH-1:0] out_b,
    output reg  signed [ACC_WIDTH-1:0]  acc
);

    // Sign-extend 8-bit inputs to 18-bit to match ECP5 MULT18X18D slice width
    wire signed [17:0] a_ext = {{10{in_a[DATA_WIDTH-1]}}, in_a};
    wire signed [17:0] b_ext = {{10{in_b[DATA_WIDTH-1]}}, in_b};

    (* use_dsp = "yes" *) wire signed [35:0] mult_out_36 = a_ext * b_ext;
    wire signed [15:0] pe_mult_result = mult_out_36[15:0];

    always @(posedge clk) begin
        if (!rst_n) begin
            out_a <= {DATA_WIDTH{1'b0}};
            out_b <= {DATA_WIDTH{1'b0}};
            acc   <= {ACC_WIDTH{1'b0}};
        end else begin
            if (clr_acc) begin
                acc <= {ACC_WIDTH{1'b0}};
            end else if (en) begin
                acc <= acc + {{(ACC_WIDTH-16){pe_mult_result[15]}}, pe_mult_result};
            end

            if (en) begin
                out_a <= in_a;
                out_b <= in_b;
            end
        end
    end

endmodule

// ----------------------------------------------------------------------------
// Pipelined Activation Unit (Int8 Quantized Saturation)
// ----------------------------------------------------------------------------
module activation_unit #(
    parameter ACC_WIDTH  = 32,
    parameter DATA_WIDTH = 8
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire signed [ACC_WIDTH-1:0]  in_data,
    input  wire [1:0]                   act_mode,
    output reg  signed [DATA_WIDTH-1:0] out_data
);

    wire signed [ACC_WIDTH-1:0] leaky_val = (in_data >= 0) ? in_data : (in_data >>> 3);
    reg  signed [ACC_WIDTH-1:0] activated_val;

    always @(*) begin
        case (act_mode)
            2'b01:   activated_val = (in_data > 0) ? in_data : {ACC_WIDTH{1'b0}}; // ReLU
            2'b10:   activated_val = leaky_val;                                   // Leaky ReLU
            default: activated_val = in_data;                                     // Pass-through
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            out_data <= {DATA_WIDTH{1'b0}};
        end else begin
            if (activated_val > 32'sd127) begin
                out_data <= 8'sd127;
            end else if (activated_val < -32'sd128) begin
                out_data <= -8'sd128;
            end else begin
                out_data <= activated_val[7:0];
            end
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
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         start,
    input  wire [15:0]                  matrix_dim,
    input  wire [1:0]                   act_mode,

    // Weight SRAM Write Interface
    input  wire                         w_buf_wr_en,
    input  wire [$clog2(ARRAY_N)-1:0]   w_buf_addr,
    input  wire [127:0]                 w_buf_wdata,

    // Activation SRAM Write Interface
    input  wire                         a_buf_wr_en,
    input  wire [$clog2(ARRAY_N)-1:0]   a_buf_addr,
    input  wire [127:0]                 a_buf_wdata,

    // Result SRAM Read Interface
    input  wire                         out_buf_rd_en,
    input  wire [$clog2(ARRAY_N)-1:0]   out_buf_addr,
    output reg  [127:0]                 out_buf_rdata,

    // Execution Flags
    output reg                          core_busy,
    output reg                          core_done
);

    // Local SRAM Buffers
    reg [127:0] weight_sram     [0:ARRAY_N-1];
    reg [127:0] activation_sram [0:ARRAY_N-1];

    (* ram_style = "block" *) reg [127:0] result_sram [0:ARRAY_N-1];

    always @(posedge clk) begin
        if (w_buf_wr_en) weight_sram[w_buf_addr]     <= w_buf_wdata;
        if (a_buf_wr_en) activation_sram[a_buf_addr] <= a_buf_wdata;
    end

    // FSM State Parameters & Wide Control Signals
    localparam STATE_IDLE      = 2'b00;
    localparam STATE_RUN       = 2'b01;
    localparam STATE_WRITEBACK = 2'b10;

    reg [1:0]  state;
    reg [15:0] cycle_cnt;
    reg [15:0] col_cnt;
    reg [15:0] wb_cnt;

    wire [15:0] total_cycles = matrix_dim + (2 * ARRAY_N);

    // PE Interconnect & Skew Declarations
    wire signed [DATA_WIDTH-1:0] pe_a_wire [0:ARRAY_N-1][0:ARRAY_N];
    wire signed [DATA_WIDTH-1:0] pe_b_wire [0:ARRAY_N][0:ARRAY_N-1];
    wire signed [ACC_WIDTH-1:0]  pe_acc    [0:ARRAY_N-1][0:ARRAY_N-1];
    wire signed [DATA_WIDTH-1:0] pe_act_out[0:ARRAY_N-1][0:ARRAY_N-1];

    reg pe_clr_acc;
    reg pe_en;
    reg clear_skew;

    reg [7:0] act_skew [0:ARRAY_N-1][0:ARRAY_N-1];
    reg [7:0] wgt_skew [0:ARRAY_N-1][0:ARRAY_N-1];

    reg [127:0] act_new_col, wgt_new_col;

    wire [7:0] act_col_byte [0:ARRAY_N-1];
    wire [7:0] wgt_col_byte [0:ARRAY_N-1];

    genvar idx;
    generate
        for (idx = 0; idx < ARRAY_N; idx = idx + 1) begin : EXTRACT_BYTES
            assign act_col_byte[idx] = act_new_col[8*idx +: 8];
            assign wgt_col_byte[idx] = wgt_new_col[8*idx +: 8];
        end
    endgenerate

    // Shift Logic for Systolic Delay Lines
    integer i, j;
    always @(posedge clk) begin
        if (!rst_n || clear_skew) begin
            for (i = 0; i < ARRAY_N; i = i + 1) begin
                for (j = 0; j < ARRAY_N; j = j + 1) begin
                    act_skew[i][j] <= 8'd0;
                    wgt_skew[i][j] <= 8'd0;
                end
            end
        end else if (pe_en) begin
            for (i = 0; i < ARRAY_N; i = i + 1) begin
                act_skew[i][0] <= act_col_byte[i];
                for (j = 1; j < ARRAY_N; j = j + 1) begin
                    act_skew[i][j] <= act_skew[i][j-1];
                end
            end
            for (j = 0; j < ARRAY_N; j = j + 1) begin
                wgt_skew[j][0] <= wgt_col_byte[j];
                for (i = 1; i < ARRAY_N; i = i + 1) begin
                    wgt_skew[j][i] <= wgt_skew[j][i-1];
                end
            end
        end
    end

    // Boundary Assignments
    genvar g_i;
    generate
        for (g_i = 0; g_i < ARRAY_N; g_i = g_i + 1) begin : BOUNDARY_ASSIGN
            if (g_i == 0) begin
                assign pe_a_wire[0][0] = pe_en ? act_col_byte[0] : {DATA_WIDTH{1'b0}};
                assign pe_b_wire[0][0] = pe_en ? wgt_col_byte[0] : {DATA_WIDTH{1'b0}};
            end else begin
                assign pe_a_wire[g_i][0] = pe_en ? act_skew[g_i][g_i-1] : {DATA_WIDTH{1'b0}};
                assign pe_b_wire[0][g_i] = pe_en ? wgt_skew[g_i][g_i-1] : {DATA_WIDTH{1'b0}};
            end
        end
    endgenerate

    // Systolic Array Generation
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
                    .clk      (clk),
                    .rst_n    (rst_n),
                    .in_data  (pe_acc[r][c]),
                    .act_mode (act_mode),
                    .out_data (pe_act_out[r][c])
                );
            end
        end
    endgenerate

    // FSM Control Process
    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= STATE_IDLE;
            cycle_cnt   <= 16'd0;
            col_cnt     <= 16'd0;
            wb_cnt      <= 16'd0;
            pe_en       <= 1'b0;
            pe_clr_acc  <= 1'b1;
            clear_skew  <= 1'b1;
            core_busy   <= 1'b0;
            core_done   <= 1'b0;
            act_new_col <= 128'd0;
            wgt_new_col <= 128'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (start) begin
                        state       <= STATE_RUN;
                        cycle_cnt   <= 16'd0;
                        col_cnt     <= 16'd0;
                        pe_clr_acc  <= 1'b0;
                        clear_skew  <= 1'b0;
                        pe_en       <= 1'b1;
                        core_busy   <= 1'b1;
                        core_done   <= 1'b0;
                        act_new_col <= 128'd0;
                        wgt_new_col <= 128'd0;
                    end else begin
                        core_busy   <= 1'b0;
                        pe_clr_acc  <= 1'b1;
                        clear_skew  <= 1'b1;
                        pe_en       <= 1'b0;
                    end
                end

                STATE_RUN: begin
                    cycle_cnt <= cycle_cnt + 1'b1;

                    if (col_cnt < matrix_dim) begin
                        act_new_col <= activation_sram[col_cnt];
                        wgt_new_col <= weight_sram[col_cnt];
                        col_cnt     <= col_cnt + 1'b1;
                    end else begin
                        act_new_col <= 128'd0;
                        wgt_new_col <= 128'd0;
                    end

                    if (cycle_cnt >= total_cycles - 1) begin
                        state  <= STATE_WRITEBACK;
                        wb_cnt <= 16'd0;
                        pe_en  <= 1'b0;
                    end
                end

                STATE_WRITEBACK: begin
                    if (wb_cnt == ARRAY_N - 1) begin
                        state     <= STATE_IDLE;
                        core_done <= 1'b1;
                        core_busy <= 1'b0;
                    end else begin
                        wb_cnt <= wb_cnt + 1'b1;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

    // Dynamic Result SRAM Packing
    integer k;
    reg [127:0] row_packed;
    always @(*) begin
        row_packed = 128'd0;
        if (state == STATE_WRITEBACK && wb_cnt < ARRAY_N) begin
            for (k = 0; k < ARRAY_N; k = k + 1) begin
                row_packed[k*8 +: 8] = pe_act_out[wb_cnt][k];
            end
        end
    end

    always @(posedge clk) begin
        if (state == STATE_WRITEBACK) begin
            result_sram[wb_cnt] <= row_packed;
        end
        if (out_buf_rd_en) begin
            out_buf_rdata <= result_sram[out_buf_addr];
        end
    end

endmodule
