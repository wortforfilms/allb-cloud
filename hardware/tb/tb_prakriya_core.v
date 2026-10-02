// ============================================================================
// Testbench: tb_prakriya_core
// Runs every form of the reference slice (hardware/scripts/prakriya_ref.py) through
// prakriya_core and checks every step: the sutra, the deciding principle (antaraṅga /
// nitya / para) and the full state after it (root text, vikaraṇa, ending).
// The reference itself is checked against Vidyut's derivations by the script.
// ============================================================================
`timescale 1ns / 1ps
`include "panini_defs.vh"
`include "vectors/prakriya_counts.vh"

module tb_prakriya_core;
    localparam integer DMAX = 12, TMAX = 12, SMAX = 26, SW = 17, IN = 1 + TMAX*3 + 2, WORDS = IN + 1 + SMAX*SW;
    reg clk = 0, rst_n = 0, start = 0;
    reg [3:0] ntok; reg [TMAX*6-1:0] tl; reg [TMAX-1:0] tn; reg [TMAX*2-1:0] ta; reg gh; reg [1:0] pc;
    wire step_valid, busy, done; wire [4:0] rule; wire [1:0] why, t1; wire [2:0] t2; wire [3:0] dlen; wire [DMAX*6-1:0] d;
    prakriya_core dut (.clk(clk), .rst_n(rst_n), .start(start), .ntok(ntok), .tok_letter(tl), .tok_nasal(tn), .tok_accent(ta),
        .ghatadi(gh), .pada_choice(pc), .step_valid(step_valid), .step_rule(rule), .step_why(why), .snap_dlen(dlen),
        .snap_d(d), .snap_t1(t1), .snap_t2(t2), .busy(busy), .done(done));
    always #5 clk = ~clk;

    reg [31:0] mem [0:`PRAKRIYA_FORMS*WORDS-1];
    integer f, k, b, sb, nsteps, got, errors = 0, bad_forms = 0, total_steps = 0, nitya = 0, antar = 0, para = 0, cyc;
    reg bad;
    initial begin
        $readmemh("vectors/prakriya_ref.mem", mem);
        #12 rst_n = 1;
        for (f = 0; f < `PRAKRIYA_FORMS; f = f + 1) begin
            b = f * WORDS;
            ntok = mem[b][3:0];
            for (k = 0; k < TMAX; k = k + 1) begin
                tl[k*6 +: 6] = mem[b+1+k*3][5:0]; tn[k] = mem[b+2+k*3][0]; ta[k*2 +: 2] = mem[b+3+k*3][1:0];
            end
            gh = mem[b+1+TMAX*3][0]; pc = mem[b+2+TMAX*3][1:0];
            nsteps = mem[b+IN]; got = 0; bad = 0;
            @(negedge clk) start = 1; @(negedge clk) start = 0;
            cyc = 0;
            while (!done && cyc < 400) begin
                @(posedge clk); #1; cyc = cyc + 1;
                if (step_valid) begin
                    sb = b + IN + 1 + got * SW;
                    if (got >= nsteps || rule !== mem[sb][4:0] || why !== mem[sb+1][1:0] || dlen !== mem[sb+2][3:0] ||
                        t1 !== mem[sb+15][1:0] || t2 !== mem[sb+16][2:0]) bad = 1;
                    for (k = 0; k < DMAX; k = k + 1) if (k < dlen && d[k*6 +: 6] !== mem[sb+3+k][5:0]) bad = 1;
                    if (bad && errors < 6) begin
                        $display("FAIL form %0d step %0d: rule %0d why %0d len %0d t1 %0d t2 %0d — expected rule %0d why %0d len %0d t1 %0d t2 %0d",
                                 f, got, rule, why, dlen, t1, t2, mem[sb], mem[sb+1], mem[sb+2], mem[sb+15], mem[sb+16]);
                        errors = errors + 1;
                    end
                    if (why == 1) antar = antar + 1; if (why == 2) nitya = nitya + 1; if (why == 3) para = para + 1;
                    got = got + 1;
                end
            end
            if (got != nsteps) bad = 1;
            if (bad) bad_forms = bad_forms + 1;
            total_steps = total_steps + got;
        end
        $display("Prakriya core: %0d of %0d forms agree step by step (%0d steps; decided by antaranga %0d, nitya %0d, para %0d)",
                 `PRAKRIYA_FORMS - bad_forms, `PRAKRIYA_FORMS, total_steps, antar, nitya, para);
        if (bad_forms) $fatal(1, "PRAKRIYA CORE: %0d forms differ", bad_forms);
        $display("PRAKRIYA CORE: PASS");
        $finish;
    end
endmodule
