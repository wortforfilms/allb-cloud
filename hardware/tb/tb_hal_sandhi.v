// ============================================================================
// Testbench: tb_hal_sandhi
// Streams every juncture of the reference model (hardware/scripts/hal_ref.py)
// through hal_sandhi_pipeline, one per clock, and checks each result lane by
// lane: V, C1, C2, R, avagraha and the trace of sutras applied, plus the number
// of forms. 14 left vowels (or none) x 9 endings x 47 next sounds x 2 contexts.
// The reference itself is checked against Vidyut by the script
// (hardware/tb/vectors/hal_vidyut_report.md).
// ============================================================================
`timescale 1ns / 1ps
`include "panini_defs.vh"
`include "vectors/hal_counts.vh"

module tb_hal_sandhi;
    localparam integer LANES = 3, WORDS = 5 + LANES * 6;
    reg clk = 0, rst_n = 0, in_valid = 0;
    reg [5:0] in_v = 0, in_c1 = 0, in_r = 0, in_r2 = 0;
    wire out_valid, out_overflow;
    wire [LANES*`CW-1:0] out_lanes;
    wire [2:0] out_count;
    hal_sandhi_pipeline #(.LANES(LANES)) dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_v(in_v), .in_c1(in_c1),
        .in_r(in_r), .in_r2(in_r2), .out_valid(out_valid), .out_lanes(out_lanes), .out_count(out_count), .out_overflow(out_overflow));
    always #5 clk = ~clk;

    reg [31:0] mem [0:`HAL_REF_CASES*WORDS-1];
    integer sent = 0, checked = 0, errors = 0, forms = 0, k, b;
    reg [`CW-1:0] lane;
    reg bad;

    // checker: results arrive in order, three clocks after their inputs
    always @(posedge clk) begin
      #1;
      if (rst_n && out_valid) begin
        b = checked * WORDS; bad = 0;
        if (out_overflow || out_count !== mem[b+4][2:0]) bad = 1;
        for (k = 0; k < LANES; k = k + 1) begin
            lane = out_lanes[k*`CW +: `CW];
            if (k < mem[b+4]) begin
                if (!lane[`C_VALID] || lane[`C_V] !== mem[b+5+k*6][5:0] || lane[`C_C1] !== mem[b+6+k*6][5:0] ||
                    lane[`C_C2] !== mem[b+7+k*6][5:0] || lane[`C_R] !== mem[b+8+k*6][5:0] ||
                    lane[`C_AVG] !== mem[b+9+k*6][0] || lane[`C_TRACE] !== mem[b+10+k*6]) bad = 1;
            end else if (lane[`C_VALID]) bad = 1;
        end
        if (bad) begin
            errors = errors + 1;
            if (errors <= 10) $display("FAIL case %0d: V=%0d C1=%0d R=%0d R2=%0d forms %0d (expected %0d) lane0 V=%0d C1=%0d C2=%0d R=%0d trace=%h (expected %h)",
                checked, mem[b], mem[b+1], mem[b+2], mem[b+3], out_count, mem[b+4], out_lanes[`C_V], out_lanes[`C_C1], out_lanes[`C_C2],
                out_lanes[`C_R], out_lanes[`C_TRACE], mem[b+10]);
        end
        forms = forms + mem[b+4];
        checked = checked + 1;
      end
    end

    initial begin
        $readmemh("vectors/hal_ref.mem", mem);
        #12 rst_n = 1;
        for (sent = 0; sent < `HAL_REF_CASES; sent = sent + 1) begin
            @(negedge clk);
            b = sent * WORDS;
            in_v = mem[b][5:0]; in_c1 = mem[b+1][5:0]; in_r = mem[b+2][5:0]; in_r2 = mem[b+3][5:0]; in_valid = 1'b1;
        end
        @(negedge clk) in_valid = 1'b0;
        repeat (5) @(posedge clk);
        #2;
        $display("Hal sandhi pipeline: %0d of %0d junctures agree (%0d correct forms checked, with every sutra in each trace)",
                 checked - errors, `HAL_REF_CASES, forms);
        if (checked != `HAL_REF_CASES) $fatal(1, "HAL SANDHI: only %0d results for %0d inputs", checked, `HAL_REF_CASES);
        if (errors) $fatal(1, "HAL SANDHI: %0d mismatches", errors);
        $display("HAL SANDHI: PASS");
        $finish;
    end
endmodule
