// ============================================================================
// Module:      hal_sandhi_pipeline
// Description: Consonant and visarga sandhi at a word boundary, as a three-stage
//              pipeline with candidate lanes for optional rules.
//
//   in  : V (last vowel of word 1), C1 (its final consonant: क ट त प न म स र or none),
//         R (first sound of word 2; none = pause), R2 (the sound after R)
//   out : up to LANES correct forms, each {V, C1, C2, R, avagraha, trace}
//
//   Stage A  Saptādhyāyī tuk, then 8.2.39 / 8.2.66            (register)
//   Stage B  8.3, with the bypass for 6.1.113, 6.1.114, 6.3.111 (register)
//   Stage C  8.4                                                (register)
//
// The Tripādī stages never feed back. The bypass exists because those three
// Saptādhyāyī rules name a Tripādī result (ru, the loss of r) and so must see it
// despite 8.2.1 पूर्वत्रासिद्धम्.
//
// An optional rule forks a candidate into a free lane. Lane 0 never takes an
// optional rule. One juncture can enter per clock; results appear 3 clocks later.
// ============================================================================
`timescale 1ns / 1ps
`include "panini_defs.vh"

module hal_sandhi_pipeline #(
    parameter integer LANES = 3
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  in_valid,
    input  wire [5:0]            in_v, in_c1, in_r, in_r2,
    output wire                  out_valid,
    output wire [LANES*`CW-1:0]  out_lanes,     // lane k = out_lanes[k*CW +: CW]
    output wire [2:0]            out_count,
    output wire                  out_overflow    // more correct forms than lanes
);
    // ---------------- pipeline registers ----------------
    reg [LANES*`CW-1:0] sa, sb, sc;
    reg [5:0]           r2a, r2b;
    reg                 va, vb, vc, ova, ovb, ovc;

    // ---------------- stage A (one input candidate) ----------------
    wire [`CW-1:0] cand_in = {in_valid, 1'b0, 32'd0, in_v, in_c1, `PH_NONE, in_r};
    wire [`CW-1:0] a_main, a_fork;
    hal_stage_a stage_a (.in(cand_in), .main(a_main), .fork_out(a_fork));

    // ---------------- stage B and C: one rule block per lane ----------------
    wire [LANES*`CW-1:0] b_main, b_fork, c_main, c_fork;
    genvar k;
    generate for (k = 0; k < LANES; k = k + 1) begin : lanes
        hal_stage_b stage_b (.in(sa[k*`CW +: `CW]), .r2(r2a), .main(b_main[k*`CW +: `CW]), .fork_out(b_fork[k*`CW +: `CW]));
        hal_stage_c stage_c (.in(sb[k*`CW +: `CW]), .r2(r2b), .main(c_main[k*`CW +: `CW]), .fork_out(c_fork[k*`CW +: `CW]));
    end endgenerate

    // ---------------- lane compaction ----------------
    // Valid mains are already packed from lane 0. Each stage applies at most one optional
    // rule (checked by the reference model on every juncture), so a single fork slot is
    // placed right after the mains. A second fork, or no free lane, raises overflow.
    function [LANES*`CW:0] compact(input [LANES*`CW-1:0] mains, input [LANES*`CW-1:0] forks);
        integer i, nm, nf;
        reg [`CW-1:0] f;
        reg [LANES*`CW-1:0] o;
        begin
            nm = 0; nf = 0; f = {`CW{1'b0}};
            for (i = 0; i < LANES; i = i + 1) begin
                if (mains[i*`CW + `C_VALID]) nm = nm + 1;
                if (forks[i*`CW + `C_VALID]) begin if (nf == 0) f = forks[i*`CW +: `CW]; nf = nf + 1; end
            end
            for (i = 0; i < LANES; i = i + 1)
                o[i*`CW +: `CW] = (i < nm) ? mains[i*`CW +: `CW] : (i == nm && nf != 0) ? f : {`CW{1'b0}};
            compact = {(nf > 1) || (nf != 0 && nm >= LANES), o};
        end
    endfunction

    wire [LANES*`CW-1:0] a_mains = {{(LANES-1)*`CW{1'b0}}, a_main};
    wire [LANES*`CW-1:0] a_forks = {{(LANES-1)*`CW{1'b0}}, a_fork};
    wire [LANES*`CW:0] a_next = compact(a_mains, a_forks);
    wire [LANES*`CW:0] b_next = compact(b_main, b_fork);
    wire [LANES*`CW:0] c_next = compact(c_main, c_fork);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sa <= 0; sb <= 0; sc <= 0; va <= 0; vb <= 0; vc <= 0; ova <= 0; ovb <= 0; ovc <= 0; r2a <= 0; r2b <= 0;
        end else begin
            sa <= a_next[LANES*`CW-1:0]; va <= in_valid; ova <= a_next[LANES*`CW]; r2a <= in_r2;
            sb <= b_next[LANES*`CW-1:0]; vb <= va;       ovb <= ova | b_next[LANES*`CW]; r2b <= r2a;
            sc <= c_next[LANES*`CW-1:0]; vc <= vb;       ovc <= ovb | c_next[LANES*`CW];
        end
    end

    assign out_valid    = vc;
    assign out_lanes    = sc;
    assign out_overflow = ovc;
    function [2:0] count(input [LANES*`CW-1:0] l);
        integer i; begin count = 0; for (i = 0; i < LANES; i = i + 1) if (l[i*`CW + `C_VALID]) count = count + 1; end
    endfunction
    assign out_count = count(sc);
endmodule
