// ============================================================================
// Testbench: tb_panini_datapath
//   1. Shiva Sutra ROM: named pratyāhāras, including the ह and ण् quirks.
//   2. Datapath vs the Python reference (hardware/scripts/panini_ref.py):
//      all 13 x 13 vowel pairs, inside a word and at a word boundary (338 cases):
//      winning rule, result, avagraha, the optional 8.3.19 form, loop count.
//   3. Datapath vs Vidyut (golden, MIT): Vidyut's word-boundary result must be
//      the datapath's result or its 8.3.19 alternative (143 cases).
// Any mismatch ends the run with $fatal. Regenerate vectors after changing rules:
//   python3 hardware/scripts/panini_ref.py
// ============================================================================
`timescale 1ns / 1ps
`include "panini_defs.vh"
`include "vectors/counts.vh"

module tb_panini_datapath;
    // ---------------------------------------------------------------- ROM checks
    reg  [5:0]  rom_start; reg [3:0] rom_marker; reg rom_expand;
    wire [63:0] rom_mask;  wire rom_valid;
    sivasutra_rom rom (.start(rom_start), .marker(rom_marker), .savarna_expand(rom_expand), .mask(rom_mask), .valid(rom_valid));

    integer errors = 0, i;
    reg [63:0] want;

    task check_rom(input [5:0] s, input [3:0] m, input [63:0] expected, input [8*12-1:0] name);
        begin
            rom_start = s; rom_marker = m; rom_expand = 1'b1; #1;
            if (!rom_valid || rom_mask !== expected) begin
                $display("FAIL rom %0s: got %h want %h (valid %b)", name, rom_mask, expected, rom_valid); errors = errors + 1;
            end
        end
    endtask

    function [63:0] range_mask(input integer lo, input integer hi);
        integer k; begin range_mask = 64'd0; for (k = lo; k <= hi; k = k + 1) range_mask[k] = 1'b1; end
    endfunction

    // ---------------------------------------------------------------- datapath
    reg clk = 0, rst_n = 0, start = 0, pada_end = 0;
    reg [5:0] left = 0, right = 0;
    wire busy, done, avagraha, alt_valid, error;
    wire [5:0] res0, res1, res2, alt0, alt1, alt2;
    wire [1:0] res_len, alt_len;
    wire [11:0] trace; wire [2:0] iterations;
    panini_datapath dut (.clk(clk), .rst_n(rst_n), .start(start), .left(left), .right(right), .pada_end(pada_end),
        .busy(busy), .done(done), .res0(res0), .res1(res1), .res2(res2), .res_len(res_len), .avagraha(avagraha),
        .alt_valid(alt_valid), .alt0(alt0), .alt1(alt1), .alt2(alt2), .alt_len(alt_len),
        .trace(trace), .iterations(iterations), .error(error));
    always #5 clk = ~clk;

    task run(input [5:0] l, input [5:0] r, input pe);
        begin
            @(negedge clk); left = l; right = r; pada_end = pe; start = 1'b1;
            @(negedge clk); start = 1'b0;
            while (!done) @(posedge clk);
            #1;
        end
    endtask

    reg [7:0] refm [0:`PANINI_REF_CASES*14-1];
    reg [7:0] vid  [0:`PANINI_VIDYUT_CASES*7-1];
    integer n, base, ref_ok = 0, vid_ok = 0, cycles_max = 0;
    reg prim, altm;

    initial begin
        // 1 --------------------------------------------------------------------
        check_rom(`PH_A, 4'd4,  range_mask(0, 13), "ac");
        check_rom(`PH_H, 4'd14, range_mask(14, 46), "hal");
        check_rom(`PH_I, 4'd2,  range_mask(2, 9), "ik");
        check_rom(`PH_A, 4'd2,  range_mask(0, 9), "ak");
        check_rom(`PH_E, 4'd4,  range_mask(10, 13), "ec");
        want = 64'd0; want[`PH_E] = 1; want[`PH_O] = 1;                       check_rom(`PH_E, 4'd3, want, "eng");
        check_rom(`PH_Y, 4'd6,  range_mask(15, 18), "yan");
        check_rom(`PH_A, 4'd1,  range_mask(0, 5), "an(1)");                   // ण् of sutra 1: अ इ उ (+ long)
        want = range_mask(0, 18); want[`PH_NY] = 0; want[`PH_M] = 0; want[`PH_NG] = 0; want[`PH_NN] = 0; want[`PH_N] = 0;
        want = range_mask(0, 18) & ~range_mask(19, 23);                       check_rom(`PH_A, 4'd6, want, "an(6)"); // ण् of sutra 6: up to ल
        want = range_mask(44, 46); want[`PH_H] = 1;                           check_rom(`PH_SH, 4'd14, want, "shal");   // ह via slot 42
        want = range_mask(24, 46); want[`PH_H] = 1;                           check_rom(`PH_JH, 4'd14, want, "jhal");
        want = range_mask(14, 33);                                             check_rom(`PH_H, 4'd10, want, "has");     // ह via slot 9
        rom_start = `PH_K; rom_marker = 4'd1; #1;
        if (rom_valid) begin $display("FAIL rom: k..(1) must be invalid"); errors = errors + 1; end
        $display("Shiva Sutra ROM: %0s", errors ? "FAILED" : "13 pratyahara checks passed");

        // 2 --------------------------------------------------------------------
        $readmemh("vectors/panini_ref.mem", refm);
        $readmemh("vectors/vidyut.mem", vid);
        #12 rst_n = 1;
        for (n = 0; n < `PANINI_REF_CASES; n = n + 1) begin
            base = n * 14;
            run(refm[base][5:0], refm[base+1][5:0], refm[base+2][0]);
            if (error || trace[2:0] !== refm[base+3][2:0] || res_len !== refm[base+4][1:0] ||
                res0 !== refm[base+5][5:0] || (res_len > 1 && res1 !== refm[base+6][5:0]) || (res_len > 2 && res2 !== refm[base+7][5:0]) ||
                avagraha !== refm[base+8][0] || alt_valid !== refm[base+9][0] ||
                (alt_valid && (alt_len !== refm[base+10][1:0] || alt0 !== refm[base+11][5:0] || alt1 !== refm[base+12][5:0])) ||
                iterations !== 3'd2) begin
                $display("FAIL ref case %0d: %0d + %0d pada_end=%0d -> rule %0d len %0d [%0d %0d %0d] avg %0d alt %0d [%0d %0d] iter %0d err %0d",
                    n, refm[base], refm[base+1], refm[base+2], trace[2:0], res_len, res0, res1, res2, avagraha, alt_valid, alt0, alt1, iterations, error);
                errors = errors + 1;
            end else ref_ok = ref_ok + 1;
        end
        $display("Reference model: %0d of %0d cases agree (rule, result, avagraha, 8.3.19 option, 2 loop cycles)", ref_ok, `PANINI_REF_CASES);

        // 3 --------------------------------------------------------------------
        for (n = 0; n < `PANINI_VIDYUT_CASES; n = n + 1) begin
            base = n * 7;
            run(vid[base][5:0], vid[base+1][5:0], 1'b1);
            prim = (res_len === vid[base+2][1:0]) && res0 === vid[base+3][5:0] && (res_len < 2 || res1 === vid[base+4][5:0]) &&
                   (res_len < 3 || res2 === vid[base+5][5:0]) && avagraha === vid[base+6][0];
            altm = alt_valid && !vid[base+6][0] && alt_len === vid[base+2][1:0] && alt0 === vid[base+3][5:0] && alt1 === vid[base+4][5:0];
            if (!error && (prim || altm)) vid_ok = vid_ok + 1;
            else begin
                $display("FAIL vidyut case %0d: %0d + %0d -> datapath [%0d %0d %0d] alt [%0d %0d], Vidyut len %0d [%0d %0d %0d]",
                    n, vid[base], vid[base+1], res0, res1, res2, alt0, alt1, vid[base+2], vid[base+3], vid[base+4], vid[base+5]);
                errors = errors + 1;
            end
        end
        $display("Vidyut golden: %0d of %0d word-boundary cases agree", vid_ok, `PANINI_VIDYUT_CASES);

        if (errors) $fatal(1, "PANINI DATAPATH: %0d mismatches", errors);
        $display("PANINI DATAPATH: PASS");
        $finish;
    end
endmodule
