// ============================================================================
// Module:      sandhi_engine
// Description: Phase 1 vowel sandhi (Saptādhyāyī, 6.1) as parallel match blocks
//              with an exception (apavāda) override matrix. Combinational.
//
// Each block tests its sutra's own conditions, as read with anuvṛtti (for
// example 6.1.87 आद्गुणः inherits अचि from 6.1.77, so it matches अ/आ + any vowel).
// All blocks evaluate at once; the override matrix then removes every general
// rule (utsarga) whose exception (apavāda) also matched:
//
//     6.1.101 dīrgha   overrides 6.1.77 yaṇ   (इ + इ -> ई, not यि)
//     6.1.101 dīrgha   overrides 6.1.87 guṇa  (अ + अ -> आ)
//     6.1.88  vṛddhi   overrides 6.1.87 guṇa  (अ + ए -> ऐ)
//     6.1.109 pūrvarūpa overrides 6.1.78 ayādi (pada-final ए/ओ + अ -> एऽ)
//
// For these six rules the remaining match is always unique, so 1.4.2
// (विप्रतिषेधे परं कार्यम्, "the later rule wins") is never needed;
// `conflict` flags it if a future rule set ever leaves two.
// Not modelled: the vārttika that makes ऋ and ऌ savarṇa; pluta; nasal vowels.
// ============================================================================
`timescale 1ns / 1ps
`include "panini_defs.vh"

module sandhi_engine (
    input  wire [5:0] left,       // final sound of the first part
    input  wire [5:0] right,      // first sound of the second part
    input  wire       pada_end,   // 1 = left ends a pada (word boundary); gates 6.1.109
    output wire [5:0] matched,    // {109, 101, 88, 87, 78, 77} before arbitration
    output wire [5:0] blocked,    // rules removed by an exception
    output reg  [2:0] rule,       // winning rule (RULE_*)
    output reg  [5:0] out0, out1, out2,
    output reg  [1:0] out_len,    // 0 = no change (no rule)
    output reg        avagraha,   // 6.1.109: the following अ merged into the previous vowel (written ऽ)
    output wire       conflict    // more than one rule left after the override matrix
);
    // --- pratyāhāras from the Shiva Sutra ROM (constant inputs: synthesize to constants)
    wire [63:0] ac, ik, ec, ak, eng;
    wire v0, v1, v2, v3, v4;
    sivasutra_rom r_ac  (.start(`PH_A), .marker(4'd4), .savarna_expand(1'b1), .mask(ac),  .valid(v0)); // अच्
    sivasutra_rom r_ik  (.start(`PH_I), .marker(4'd2), .savarna_expand(1'b1), .mask(ik),  .valid(v1)); // इक्
    sivasutra_rom r_ec  (.start(`PH_E), .marker(4'd4), .savarna_expand(1'b1), .mask(ec),  .valid(v2)); // एच्
    sivasutra_rom r_ak  (.start(`PH_A), .marker(4'd2), .savarna_expand(1'b1), .mask(ak),  .valid(v3)); // अक्
    sivasutra_rom r_eng (.start(`PH_E), .marker(4'd3), .savarna_expand(1'b1), .mask(eng), .valid(v4)); // एङ्

    // place of articulation (sthāna) and long form
    function [2:0] sthana(input [5:0] p);
        case (p)
            `PH_A, `PH_AA:  sthana = 3'd0; // कण्ठ
            `PH_I, `PH_II:  sthana = 3'd1; // तालु
            `PH_R, `PH_RR:  sthana = 3'd2; // मूर्धा
            `PH_L, `PH_LL:  sthana = 3'd3; // दन्त
            `PH_U, `PH_UU:  sthana = 3'd4; // ओष्ठ
            `PH_E, `PH_AI:  sthana = 3'd5; // कण्ठतालु
            `PH_O, `PH_AU:  sthana = 3'd6; // कण्ठोष्ठ
            default:        sthana = 3'd7;
        endcase
    endfunction
    function [5:0] dirgha(input [5:0] p);
        case (p)
            `PH_A: dirgha = `PH_AA; `PH_I: dirgha = `PH_II; `PH_U: dirgha = `PH_UU;
            `PH_R: dirgha = `PH_RR; `PH_L: dirgha = `PH_LL;
            default: dirgha = p;
        endcase
    endfunction

    wire is_at   = (left == `PH_A) || (left == `PH_AA);               // आत् (अ/आ)
    wire savarna = (sthana(left) == sthana(right)) && ak[left] && ak[right];

    // --- match blocks (each sutra on its own)
    wire m77  = ik[left] && ac[right];                                  // इको यणचि
    wire m78  = ec[left] && ac[right];                                  // एचोऽयवायावः
    wire m87  = is_at && ac[right];                                     // आद्गुणः (+ अचि)
    wire m88  = is_at && ec[right];                                     // वृद्धिरेचि
    wire m101 = ak[left] && savarna;                                    // अकः सवर्णे दीर्घः
    wire m109 = pada_end && eng[left] && (right == `PH_A);              // एङः पदान्तादति
    assign matched = {m109, m101, m88, m87, m78, m77};

    // --- exception override matrix
    wire b77 = m77 && m101;
    wire b87 = m87 && (m101 || m88);
    wire b78 = m78 && m109;
    assign blocked = {1'b0, 1'b0, 1'b0, b87, b78, b77};
    wire [5:0] win = matched & ~blocked;
    assign conflict = (win != 6'd0) && ((win & (win - 6'd1)) != 6'd0);

    always @* begin
        rule = `RULE_NONE; out0 = `PH_NONE; out1 = `PH_NONE; out2 = `PH_NONE; out_len = 2'd0; avagraha = 1'b0;
        if (win[5]) begin                       // 6.1.109: one vowel for both, ऽ marks the merged अ
            rule = `RULE_6_1_109; out0 = left; out_len = 2'd1; avagraha = 1'b1;
        end else if (win[4]) begin              // 6.1.101: the long vowel of that place
            rule = `RULE_6_1_101; out0 = dirgha(left); out_len = 2'd1;
        end else if (win[3]) begin              // 6.1.88: ऐ for ए/ऐ, औ for ओ/औ
            rule = `RULE_6_1_88; out0 = (sthana(right) == 3'd5) ? `PH_AI : `PH_AU; out_len = 2'd1;
        end else if (win[2]) begin              // 6.1.87: guṇa of the second vowel's place (1.1.50, 1.1.51 उरण् रपरः)
            rule = `RULE_6_1_87; out_len = 2'd1;
            case (sthana(right))
                3'd0: out0 = `PH_A;
                3'd1, 3'd5: out0 = `PH_E;
                3'd4, 3'd6: out0 = `PH_O;
                3'd2: begin out0 = `PH_A; out1 = `PH_RA; out_len = 2'd2; end
                3'd3: begin out0 = `PH_A; out1 = `PH_LA; out_len = 2'd2; end
                default: out0 = `PH_NONE;
            endcase
        end else if (win[1]) begin              // 6.1.78: ए अय्, ओ अव्, ऐ आय्, औ आव्; then the second vowel
            rule = `RULE_6_1_78; out_len = 2'd3; out2 = right;
            out0 = (left == `PH_AI || left == `PH_AU) ? `PH_AA : `PH_A;
            out1 = (left == `PH_E || left == `PH_AI) ? `PH_Y : `PH_V;
        end else if (win[0]) begin              // 6.1.77: य व र ल of the first vowel's place; then the second vowel
            rule = `RULE_6_1_77; out_len = 2'd2; out1 = right;
            case (sthana(left))
                3'd1: out0 = `PH_Y; 3'd4: out0 = `PH_V; 3'd2: out0 = `PH_RA; default: out0 = `PH_LA;
            endcase
        end
    end
endmodule
