// ============================================================================
// Module:      prakriya_core
// Description: A Paninian derivation (prakriyā) core with speculative precedence.
//
// Slice: present tense (laṭ), active voice (kartari), 3rd person singular, roots of
// the first class (bhvādi). Input: the root as taught (upadeśa) — letters with their
// nasal and accent marks. Output: one step per clock — the sutra applied and the
// state after it (root text, vikaraṇa, ending) — until the finished word.
//
// Operations compete. Each clock the core evaluates all eight operation blocks,
// and when more than one applies it decides by the paribhāṣā
//     परनित्यान्तरङ्गापवादानामुत्तरोत्तरं बलीयः
//   antaraṅga  the operation whose condition spans fewer terms wins
//   nitya      speculative evaluation: every candidate is applied to a shadow copy
//              of the state (with its labels); an operation that still applies, with
//              the same trigger, after the other one has applied is nitya and wins
//   para       otherwise the later sutra wins (1.4.2)
// (No apavāda pair occurs in this slice.) Labels (saṃjñā, it-markers) are emitted as
// their own steps right after the operation that creates their condition, and the
// Tripādī (8.3.24, 8.4.58, 8.4.68) runs once, in order, at the end (8.2.1).
//
// Reference: hardware/scripts/prakriya_ref.py (checked against Vidyut).
// ============================================================================
`timescale 1ns / 1ps
`include "panini_defs.vh"

module prakriya_core #(
    parameter integer DMAX = 12,       // root text slots
    parameter integer TMAX = 12        // upadeśa token slots
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 start,
    input  wire [3:0]           ntok,
    input  wire [TMAX*6-1:0]    tok_letter,   // token k = [k*6 +: 6]
    input  wire [TMAX-1:0]      tok_nasal,
    input  wire [TMAX*2-1:0]    tok_accent,   // 0 none, 1 anudātta, 2 svarita
    input  wire                 ghatadi,      // root lies in the Dhātupāṭha's ghaṭādi section (01.0933)
    input  wire [1:0]           pada_choice,  // ubhayapada roots: 1 ātmanepada, 2 parasmaipada
    output reg                  step_valid,
    output reg  [4:0]           step_rule,    // see RULE ids in prakriya_ref.py
    output reg  [1:0]           step_why,     // 0 single/label, 1 antaraṅga, 2 nitya, 3 para
    output reg  [3:0]           snap_dlen,
    output reg  [DMAX*6-1:0]    snap_d,
    output reg  [1:0]           snap_t1,      // 0 none, 1 Sap, 2 a
    output reg  [2:0]           snap_t2,      // 0 none, 1 la~w, 2 l, 3 tip, 4 ti, 5 ta, 6 te
    output reg                  busy,
    output reg                  done
);
    `include "prakriya_ops.vh"
    function [4:0] op_rule(input integer k);       // operation index -> rule id
        case (k) 0: op_rule = 19; 1: op_rule = 11; 2: op_rule = 16; 3: op_rule = 20;
                 4: op_rule = 23; 5: op_rule = 10; 6: op_rule = 21; default: op_rule = 22; endcase
    endfunction

    // ------------------------------------------------------------------ arbitration
    // When more than one operation applies, the core speculates: over one clock per
    // candidate it applies that candidate to a shadow copy of the state (with its labels)
    // and evaluates every operation block on the shadow, recording which operations still
    // apply with the same trigger. Then it decides. One action unit and one extra
    // operation-block unit are shared by all candidates (time-multiplexed speculation).
    reg  [W-1:0] st;
    reg  [2:0]   op_sel;
    reg  [1:0]   pc;              // latched pada choice
    wire [NOPS*5-1:0] mcur, msh;
    wire [W-1:0] acted, shadow;
    pk_match  #(.DMAX(DMAX)) match_now (.s(st), .m(mcur));
    pk_act    #(.DMAX(DMAX)) apply_op  (.s(st), .op(op_sel), .o(acted));
    pk_labels #(.DMAX(DMAX)) relabel   (.s(acted), .pc(pc), .o(shadow));
    pk_match  #(.DMAX(DMAX)) match_sh  (.s(shadow), .m(msh));

    reg  [NOPS-1:0] cand;
    reg  [NOPS*NOPS-1:0] still;            // still[a*NOPS + b]: a still applies (same trigger) after b
    integer a, b, winner;
    reg  [1:0] why, rk;
    reg  ok, wins, multi;
    always @* begin
        for (a = 0; a < NOPS; a = a + 1) cand[a] = mcur[a*5 + 4];
        multi = (cand & (cand - 1)) != 0;
        // rk = strength of the strongest principle used: 1 para, 2 nitya, 3 antaraṅga
        winner = -1; why = 2'd0;
        for (a = 0; a < NOPS; a = a + 1) if (cand[a] && winner < 0) begin
            ok = 1'b1; rk = 2'd0;
            for (b = 0; b < NOPS; b = b + 1) if (b != a && cand[b]) begin
                if (mcur[a*5 +: 2] != mcur[b*5 +: 2]) begin wins = mcur[a*5 +: 2] < mcur[b*5 +: 2]; rk = 2'd3; end
                else if (still[a*NOPS + b] != still[b*NOPS + a]) begin wins = still[a*NOPS + b]; if (rk < 2'd2) rk = 2'd2; end
                else begin wins = (a > b); if (rk < 2'd1) rk = 2'd1; end
                if (!wins) ok = 1'b0;
            end
            if (ok) begin winner = a; why = (rk == 2'd3) ? 2'd1 : (rk == 2'd2) ? 2'd2 : (rk == 2'd1) ? 2'd3 : 2'd0; end
        end
    end
    function [2:0] winner_after(input [NOPS*NOPS-1:0] sm);
        integer x, y; reg okk, ww; reg found;
        begin
            winner_after = 0; found = 0;
            for (x = 0; x < NOPS; x = x + 1) if (cand[x] && !found) begin
                okk = 1'b1;
                for (y = 0; y < NOPS; y = y + 1) if (y != x && cand[y]) begin
                    if (mcur[x*5 +: 2] != mcur[y*5 +: 2]) ww = mcur[x*5 +: 2] < mcur[y*5 +: 2];
                    else if (sm[x*NOPS + y] != sm[y*NOPS + x]) ww = sm[x*NOPS + y];
                    else ww = (x > y);
                    if (!ww) okk = 1'b0;
                end
                if (okk) begin winner_after = x; found = 1; end
            end
        end
    endfunction
    // still-matrix column for the candidate under speculation
    reg [NOPS*NOPS-1:0] still_col;
    integer c;
    always @* begin
        still_col = still;
        for (c = 0; c < NOPS; c = c + 1)
            still_col[c*NOPS + op_sel] = cand[op_sel] && msh[c*5 + 4] && (msh[c*5 + 2 +: 2] == mcur[c*5 + 2 +: 2]);
    end

    // ------------------------------------------------------------------ root intake (combinational)
    reg  [DMAX*6-1:0] up_letters, cmp_letters;
    reg  [3:0] up_len, cmp_len;
    reg  any_nasal, last_cons, init_mark, any_it;
    reg  f_idit, f_anud, f_svar, f_nit, f_yit;
    reg  [TMAX-1:0] it;
    integer k, n;
    always @* begin
        up_letters = {DMAX*6{1'b1}}; cmp_letters = {DMAX*6{1'b1}}; it = 0; n = 0;
        for (k = 0; k < TMAX; k = k + 1) if (k < ntok) up_letters[k*6 +: 6] = tok_letter[k*6 +: 6];
        up_len = ntok;
        any_nasal = |(tok_nasal & ((1 << ntok) - 1));
        last_cons = (ntok != 0) && !is_vowel(tok_letter[(ntok-1)*6 +: 6]);
        init_mark = (ntok >= 2) && ((tok_letter[5:0] == `PH_NY && tok_letter[11:6] == `PH_I) ||
                                    (tok_letter[5:0] == `PH_TT && tok_letter[11:6] == `PH_U) ||
                                    (tok_letter[5:0] == `PH_DD && tok_letter[11:6] == `PH_U));
        f_idit = 0; f_anud = 0; f_svar = 0;
        for (k = 0; k < TMAX; k = k + 1) if (k < ntok) begin
            if (tok_nasal[k]) begin
                it[k] = 1'b1;
                if (tok_letter[k*6 +: 6] == `PH_I) f_idit = 1'b1;
                if (tok_accent[k*2 +: 2] == 2'd1) f_anud = 1'b1;
                if (tok_accent[k*2 +: 2] == 2'd2) f_svar = 1'b1;
            end
        end
        if (last_cons) it[ntok-1] = 1'b1;
        if (init_mark) begin it[0] = 1'b1; it[1] = 1'b1; end
        f_nit = last_cons && tok_letter[(ntok-1)*6 +: 6] == `PH_NG;
        f_yit = last_cons && tok_letter[(ntok-1)*6 +: 6] == `PH_NY;
        any_it = |it;
        for (k = 0; k < TMAX; k = k + 1) if (k < ntok && !it[k]) begin cmp_letters[n*6 +: 6] = tok_letter[k*6 +: 6]; n = n + 1; end
        cmp_len = n;
    end

    // ------------------------------------------------------------------ Tripādī search (combinational)
    integer j, n24;
    always @* begin
        n24 = -1;
        for (j = DMAX-2; j >= 0; j = j - 1)
            if (j < dlen(st) - 1 && (dch(st, j) == `PH_N || dch(st, j) == `PH_M) && is_jhal(dch(st, j + 1))) n24 = j;
    end
    reg word_has_a;
    always @* begin
        word_has_a = (t1(st) == T1_A);
        for (j = 0; j < DMAX; j = j + 1) if (j < dlen(st) && dch(st, j) == `PH_A) word_has_a = 1'b1;
    end

    // ------------------------------------------------------------------ sequencer
    localparam P_IDLE = 0, P_ROOT = 1, P_OPS = 2, P_LABEL = 3, P_END = 4, P_SPEC = 5, P_APPLY = 6;
    reg [2:0] phase, sub;
    reg [2:0] last_op;
    reg       label_tip;     // 3.4.78 gave tip (parasmaipada) rather than ta
    reg [3:0] pos24;
    reg       ghat;

    task emit(input [4:0] rule, input [1:0] wy, input [W-1:0] s);
        begin
            step_valid <= 1'b1; step_rule <= rule; step_why <= wy;
            snap_dlen <= dlen(s); snap_d <= s[D_LO +: DMAX*6]; snap_t1 <= t1(s); snap_t2 <= t2(s);
        end
    endtask

    reg [W-1:0] nx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= P_IDLE; busy <= 1'b0; done <= 1'b0; step_valid <= 1'b0; st <= 0; still <= 0; op_sel <= 0;
        end else begin
            step_valid <= 1'b0; done <= 1'b0;
            case (phase)
            P_IDLE: if (start) begin
                st <= 0; pc <= pada_choice; ghat <= ghatadi; busy <= 1'b1; phase <= P_ROOT; sub <= 0;
            end
            // ---- the root as taught: 1.3.1, its markers, 6.1.64/65, the gaṇasūtra
            P_ROOT: begin
                nx = st;
                case (sub)
                0: begin nx[D_LO +: DMAX*6] = up_letters; nx[LEN_LO +: 4] = up_len; st <= nx; emit(1, 0, nx); sub <= 1; end
                1: begin if (any_nasal) emit(2, 0, st); sub <= 2; end
                2: begin if (last_cons) emit(3, 0, st); sub <= 3; end
                3: begin if (init_mark) emit(4, 0, st); sub <= 4; end
                4: begin
                    nx[D_LO +: DMAX*6] = cmp_letters; nx[LEN_LO +: 4] = cmp_len;
                    nx[IDIT] = f_idit; nx[ANUD] = f_anud; nx[SVAR] = f_svar; nx[NIT] = f_nit; nx[YIT] = f_yit;
                    st <= nx; if (any_it) emit(6, 0, nx); sub <= 5;
                end
                5: begin
                    if (dch(st, 0) == `PH_SS) begin nx = set_ch(st, 4'd0, `PH_S); st <= nx; emit(7, 0, nx); end   // धात्वादेः षः सः
                    else if (dch(st, 0) == `PH_NN) begin nx = set_ch(st, 4'd0, `PH_N); st <= nx; emit(8, 0, nx); end // णो नः
                    sub <= 6;
                end
                default: begin if (ghat) emit(9, 0, st); phase <= P_OPS; end
                endcase
            end
            // ---- operations: speculate if several apply, then apply the winner
            P_OPS: begin
                if (winner < 0) begin phase <= P_END; sub <= 0; end
                else if (multi) begin still <= 0; op_sel <= 3'd0; phase <= P_SPEC; end
                else begin op_sel <= winner[2:0]; phase <= P_APPLY; end
            end
            P_SPEC: begin                                   // one candidate per clock
                still <= still_col;
                if (op_sel == NOPS - 1) begin op_sel <= winner_after(still_col); phase <= P_APPLY; end
                else op_sel <= op_sel + 3'd1;
            end
            P_APPLY: begin                                  // acted = act(op_sel, st)
                nx = acted; st <= nx;
                emit(op_rule(op_sel), multi ? why : 2'd0, nx);
                last_op <= op_sel; label_tip <= !st[ATM]; sub <= 0; phase <= P_LABEL;
            end
            // ---- the labels that operation makes applicable, each as a step
            P_LABEL: begin
                nx = st;
                if (last_op == OP_3_2_123) begin
                    case (sub)
                    0: begin emit(2, 0, st); sub <= 1; end                                       // 1.3.2
                    1: begin emit(3, 0, st); sub <= 2; end                                       // 1.3.3
                    2: begin nx[T2_LO +: 3] = T2_L; st <= nx; emit(6, 0, nx); sub <= 3; end      // 1.3.9
                    3: begin
                        nx[PADA] = 1'b1; nx[ATM] = st[ANUD] | st[NIT] | ((st[SVAR] | st[YIT]) & (pc != 2'd2)); st <= nx;
                        emit((st[ANUD] | st[NIT]) ? 5'd12 : nx[ATM] ? 5'd13 : 5'd14, 0, nx); sub <= 4;  // 1.3.12 / 1.3.72 / 1.3.78
                    end
                    default: begin
                        if (!st[ANGA]) begin nx[ANGA] = 1'b1; st <= nx; emit(15, 0, nx); end        // 1.4.13
                        phase <= P_OPS;
                    end
                    endcase
                end else if (last_op == OP_3_4_78 && label_tip) begin
                    case (sub)
                    0: begin emit(3, 0, st); sub <= 1; end                                       // 1.3.3
                    1: begin nx[T2_LO +: 3] = T2_TI; st <= nx; emit(6, 0, nx); sub <= 2; end     // 1.3.9
                    default: begin nx[T2S] = 1'b1; st <= nx; emit(17, 0, nx); phase <= P_OPS; end // 3.4.113
                    endcase
                end else if (last_op == OP_3_4_78) begin                                          // ta
                    case (sub)
                    0: begin nx[T2S] = 1'b1; st <= nx; emit(17, 0, nx); sub <= 1; end            // 3.4.113
                    default: begin nx[T2N] = 1'b1; st <= nx; emit(18, 0, nx); phase <= P_OPS; end // 1.2.4
                    endcase
                end else if (last_op == OP_3_1_68) begin
                    case (sub)
                    0: begin emit(3, 0, st); sub <= 1; end                                       // 1.3.3
                    1: begin emit(5, 0, st); sub <= 2; end                                       // 1.3.8
                    2: begin nx[T1_LO +: 2] = T1_A; st <= nx; emit(6, 0, nx); sub <= 3; end      // 1.3.9
                    default: begin nx[T1S] = 1'b1; st <= nx; emit(17, 0, nx); phase <= P_OPS; end // 3.4.113
                    endcase
                end else phase <= P_OPS;
            end
            // ---- 1.4.14, then the Tripādī once, in order
            P_END: begin
                case (sub)
                0: begin emit(24, 0, st); sub <= 1; end                                          // सुप्तिङन्तं पदम्
                1: begin
                    if (n24 >= 0) begin nx = set_ch(st, n24[3:0], `PH_ANUS); st <= nx; emit(25, 0, nx); pos24 <= n24[3:0]; sub <= 2; end // नश्चापदान्तस्य झलि
                    else sub <= 3;
                end
                2: begin
                    if (is_yay(dat(st, pos24 + 4'd1))) begin nx = set_ch(st, pos24, class_nasal(dat(st, pos24 + 4'd1))); st <= nx; emit(26, 0, nx); end // अनुस्वारस्य ययि परसवर्णः
                    sub <= 3;
                end
                3: begin if (word_has_a) emit(27, 0, st); sub <= 4; end                          // अ अ
                default: begin busy <= 1'b0; done <= 1'b1; phase <= P_IDLE; end
                endcase
            end
            default: phase <= P_IDLE;
            endcase
        end
    end
endmodule

// ---------------------------------------------------------------------------------------
// Operation blocks, one module each so that every shadow copy is a separate small circuit.
// ---------------------------------------------------------------------------------------
module pk_match #(parameter integer DMAX = 12) (input wire [DMAX*6+21:0] s, output reg [8*5-1:0] m);
    `include "prakriya_ops.vh"
    integer k;
    always @* for (k = 0; k < NOPS; k = k + 1) m[k*5 +: 5] = match(k, s);
endmodule

module pk_act #(parameter integer DMAX = 12) (input wire [DMAX*6+21:0] s, input wire [2:0] op, output wire [DMAX*6+21:0] o);
    `include "prakriya_ops.vh"
    assign o = act(op, s);
endmodule

module pk_labels #(parameter integer DMAX = 12) (input wire [DMAX*6+21:0] s, input wire [1:0] pc, output wire [DMAX*6+21:0] o);
    `include "prakriya_ops.vh"
    assign o = labels(s, pc);
endmodule
