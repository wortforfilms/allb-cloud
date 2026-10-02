// ============================================================================
// Module:      panini_datapath
// Description: Two-phase Paninian control for vowel sandhi at one juncture.
//
//   Phase 1 — Saptādhyāyī loop (1.1–8.1). The sandhi engine evaluates all rule
//             blocks in parallel each cycle; the exception matrix picks the
//             winner; the result is latched and the new juncture re-checked.
//             The loop ends when no rule matches (bounded by MAX_ITER).
//   Phase 2 — Tripādī pipeline (8.2–8.4). By 8.2.1 पूर्वत्रासिद्धम् these rules
//             are invisible to Phase 1 and apply once, in order, with no
//             feedback. Stage 1 is 8.3.19 लोपः शाकल्यस्य: an optional loss of
//             pada-final य/व after अ/आ before a vowel (ए + इ -> अयि or अ इ).
//             Because Phase 1 cannot see it, अ इ is NOT merged again into ए.
//
// Optional rules give two correct results, so the datapath returns both:
// the result without the optional rule and, when alt_valid, the one with it.
// ============================================================================
`timescale 1ns / 1ps
`include "panini_defs.vh"

module panini_datapath #(
    parameter integer MAX_ITER = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [5:0] left,
    input  wire [5:0] right,
    input  wire       pada_end,
    output reg        busy,
    output reg        done,          // one-cycle pulse; outputs are stable until the next start
    output reg  [5:0] res0, res1, res2,
    output reg  [1:0] res_len,
    output reg        avagraha,
    output reg        alt_valid,     // 8.3.19 also gives this second correct form
    output reg  [5:0] alt0, alt1, alt2,
    output reg  [1:0] alt_len,
    output reg  [11:0] trace,        // up to four Phase 1 rules, oldest in [2:0]
    output reg  [2:0] iterations,    // Phase 1 cycles, including the final no-match check
    output reg        error          // loop limit reached or an arbitration conflict
);
    localparam S_IDLE = 2'd0, S_LOOP = 2'd1, S_TRIPADI = 2'd2;
    reg [1:0] state;

    // juncture under test and the word segment built so far
    reg  [5:0] jl, jr;
    reg        jvalid;
    reg  [5:0] q0, q1, q2;
    reg  [1:0] qlen;
    reg        qavg;

    wire [5:0] m, b;
    wire [2:0] rule;
    wire [5:0] o0, o1, o2;
    wire [1:0] olen;
    wire       oavg, conflict;
    sandhi_engine engine (.left(jl), .right(jr), .pada_end(pada_end), .matched(m), .blocked(b),
                          .rule(rule), .out0(o0), .out1(o1), .out2(o2), .out_len(olen),
                          .avagraha(oavg), .conflict(conflict));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; busy <= 1'b0; done <= 1'b0; error <= 1'b0;
            res0 <= `PH_NONE; res1 <= `PH_NONE; res2 <= `PH_NONE; res_len <= 2'd0; avagraha <= 1'b0;
            alt_valid <= 1'b0; alt0 <= `PH_NONE; alt1 <= `PH_NONE; alt2 <= `PH_NONE; alt_len <= 2'd0;
            trace <= 12'd0; iterations <= 3'd0; jvalid <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
            S_IDLE: if (start) begin
                jl <= left; jr <= right; jvalid <= 1'b1;
                q0 <= left; q1 <= right; q2 <= `PH_NONE; qlen <= 2'd2; qavg <= 1'b0;
                trace <= 12'd0; iterations <= 3'd0; error <= 1'b0; busy <= 1'b1;
                state <= S_LOOP;
            end
            // ---------------- Phase 1: iterate until no rule matches -------------------
            S_LOOP: begin
                iterations <= iterations + 3'd1;
                if (conflict) error <= 1'b1;
                if (!jvalid || rule == `RULE_NONE) begin
                    state <= S_TRIPADI;
                end else if (iterations + 3'd1 >= MAX_ITER) begin
                    error <= 1'b1; state <= S_TRIPADI;
                end else begin
                    trace <= trace | ({9'd0, rule} << (3 * iterations));
                    q0 <= o0; q1 <= o1; q2 <= o2; qlen <= olen; qavg <= qavg | oavg;
                    // the new juncture is the last two sounds of the result, if any
                    if (olen >= 2'd2) begin
                        jl <= (olen == 2'd3) ? o1 : o0;
                        jr <= (olen == 2'd3) ? o2 : o1;
                        jvalid <= 1'b1;
                    end else jvalid <= 1'b0;
                end
            end
            // ---------------- Phase 2: Tripādī, once, in order, no feedback -------------
            S_TRIPADI: begin
                res0 <= q0; res1 <= q1; res2 <= q2; res_len <= qlen; avagraha <= qavg;
                // 8.3.19 लोपः शाकल्यस्य (optional): अ/आ + pada-final य/व + vowel
                if (pada_end && qlen == 2'd3 && (q0 == `PH_A || q0 == `PH_AA) &&
                    (q1 == `PH_Y || q1 == `PH_V) && q2 <= `PH_AU) begin
                    alt_valid <= 1'b1; alt0 <= q0; alt1 <= q2; alt2 <= `PH_NONE; alt_len <= 2'd2;
                end else begin
                    alt_valid <= 1'b0; alt0 <= `PH_NONE; alt1 <= `PH_NONE; alt2 <= `PH_NONE; alt_len <= 2'd0;
                end
                busy <= 1'b0; done <= 1'b1; state <= S_IDLE;
            end
            default: state <= S_IDLE;
            endcase
        end
    end
endmodule
