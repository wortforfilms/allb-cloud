// ============================================================================
// hal_sandhi_stages.v — the three rule stages of consonant/visarga sandhi.
//
// Each stage is combinational and works on one candidate:
//   {valid, avagraha, trace, V, C1, C2, R}   (see panini_defs.vh)
// and may also emit one forked candidate when an optional rule applies.
// The fork is a snapshot taken at that rule, so later rules of the same stage
// do not apply to it — the same as the reference (hardware/scripts/hal_ref.py).
// ============================================================================
`timescale 1ns / 1ps
`include "panini_defs.vh"

// ---------------------------------------------------------------------------
// Stage A — Saptādhyāyī tuk (6.1.73 / 6.1.76), then 8.2.39 and 8.2.66
// ---------------------------------------------------------------------------
module hal_stage_a (
    input  wire [`CW-1:0] in,
    output reg  [`CW-1:0] main,
    output reg  [`CW-1:0] fork_out
);
    `include "hal_classes.vh"
    function [`CW-1:0] tripadi_8_2(input [`CW-1:0] c);
        reg [`CW-1:0] x;
        begin
            x = c;
            if (x[`C_C1] == `PH_K || x[`C_C1] == `PH_TT || x[`C_C1] == `PH_T || x[`C_C1] == `PH_P) begin
                x[`C_C1] = jas_of(x[`C_C1]); x[24 + `T_8_2_39] = 1'b1;      // झलां जशोऽन्ते
            end
            if (x[`C_C1] == `PH_S) begin
                x[`C_C1] = `PH_RU; x[24 + `T_8_2_66] = 1'b1;               // ससजुषो रुः
            end
            tripadi_8_2 = x;
        end
    endfunction
    reg [`CW-1:0] m, f;
    always @* begin
        m = in; f = {`CW{1'b0}};
        if (in[`C_VALID] && in[`C_C1] == `PH_NONE && in[`C_R] == `PH_CH && in[`C_V] != `PH_NONE) begin
            if (is_short(in[`C_V])) begin
                m[`C_C1] = `PH_T; m[24 + `T_6_1_73] = 1'b1;                // छे च
            end else begin
                f = in; f[`C_C1] = `PH_T; f[24 + `T_6_1_76] = 1'b1;        // पदान्ताद्वा (optional)
            end
        end
        main     = in[`C_VALID] ? tripadi_8_2(m) : {`CW{1'b0}};
        fork_out = f[`C_VALID] ? tripadi_8_2(f) : {`CW{1'b0}};
    end
endmodule

// ---------------------------------------------------------------------------
// Stage B — 8.3, with the bypass for the Saptādhyāyī rules that name a Tripādī
// result (6.1.113, 6.1.114 name ru; 6.3.111 names the loss of r by 8.3.14).
// ---------------------------------------------------------------------------
module hal_stage_b (
    input  wire [`CW-1:0] in,
    input  wire [5:0]     r2,
    output reg  [`CW-1:0] main,
    output reg  [`CW-1:0] fork_out
);
    `include "hal_classes.vh"
    reg [`CW-1:0] c, f;
    reg done;
    always @* begin
        c = in; f = {`CW{1'b0}}; done = 1'b0;
        if (in[`C_VALID]) begin
            // bypass: 6.1.113 अतो रोरप्लुतादप्लुते + 6.1.87 + 6.1.109
            if (c[`C_C1] == `PH_RU && c[`C_V] == `PH_A && c[`C_R] == `PH_A) begin
                c[`C_V] = `PH_O; c[`C_C1] = `PH_NONE; c[`C_R] = `PH_NONE; c[`C_AVG] = 1'b1;
                c[24 + `T_6_1_113] = 1'b1; c[24 + `T_6_1_87] = 1'b1; c[24 + `T_6_1_109] = 1'b1; done = 1'b1;
            end else if (c[`C_C1] == `PH_RU && c[`C_V] == `PH_A && is_hash(c[`C_R])) begin
                // bypass: 6.1.114 हशि च + 6.1.87
                c[`C_V] = `PH_O; c[`C_C1] = `PH_NONE;
                c[24 + `T_6_1_114] = 1'b1; c[24 + `T_6_1_87] = 1'b1; done = 1'b1;
            end
            if (!done) begin
                if (c[`C_C1] == `PH_N && is_chav(c[`C_R]) && is_am(r2)) begin        // नश्छव्यप्रशान्, 8.3.4
                    c[`C_C1] = `PH_ANUS; c[`C_C2] = `PH_RU; c[24 + `T_8_3_7] = 1'b1; c[24 + `T_8_3_4] = 1'b1;
                end
                if ((c[`C_C1] == `PH_RA || c[`C_C1] == `PH_RU) && c[`C_R] == `PH_RA) begin  // रो रि
                    c[`C_C1] = `PH_NONE; c[24 + `T_8_3_14] = 1'b1;
                    if (c[`C_V] == `PH_A || c[`C_V] == `PH_I || c[`C_V] == `PH_U) begin  // bypass: 6.3.111
                        c[`C_V] = dirgha_aiu(c[`C_V]); c[24 + `T_6_3_111] = 1'b1;
                    end
                end
                if ((c[`C_C1] == `PH_RA || c[`C_C1] == `PH_RU) && (c[`C_R] == `PH_NONE || is_khar(c[`C_R]))) begin
                    c[`C_C1] = `PH_VIS; c[24 + `T_8_3_15] = 1'b1;                   // खरवसानयोर्विसर्जनीयः
                end
                if ((c[`C_C2] == `PH_RA || c[`C_C2] == `PH_RU) && (c[`C_R] == `PH_NONE || is_khar(c[`C_R]))) begin
                    c[`C_C2] = `PH_VIS; c[24 + `T_8_3_15] = 1'b1;
                end
                if (c[`C_C1] == `PH_RU && (c[`C_V] == `PH_A || c[`C_V] == `PH_AA) && is_as(c[`C_R])) begin
                    c[`C_C1] = `PH_Y; c[24 + `T_8_3_17] = 1'b1;                     // भोभगोअघोअपूर्वस्य योऽशि
                    if (is_vowel(c[`C_R])) begin
                        f = c; f[`C_C1] = `PH_NONE; f[24 + `T_8_3_19] = 1'b1;          // लोपः शाकल्यस्य (optional)
                    end else begin
                        c[`C_C1] = `PH_NONE; c[24 + `T_8_3_22] = 1'b1;              // हलि सर्वेषाम्
                    end
                end
                if (c[`C_C1] == `PH_RU) c[`C_C1] = `PH_RA;
                if (c[`C_C1] == `PH_M && is_hal(c[`C_R])) begin
                    c[`C_C1] = `PH_ANUS; c[24 + `T_8_3_23] = 1'b1;                  // मोऽनुस्वारः
                end
                if (c[`C_C1] == `PH_N && c[`C_C2] == `PH_NONE) begin
                    if (c[`C_R] == `PH_S) begin
                        f = c; f[`C_C2] = `PH_DH; f[24 + `T_8_3_30] = 1'b1;           // नश्च: dhuṭ (optional)
                    end
                    if (c[`C_R] == `PH_SH) begin
                        f = c; f[`C_C2] = `PH_T; f[24 + `T_8_3_31] = 1'b1;            // शि तुक् (optional)
                    end
                    if (is_short(c[`C_V]) && is_vowel(c[`C_R])) begin
                        c[`C_C2] = `PH_N; c[24 + `T_8_3_32] = 1'b1;                 // ङमो ह्रस्वादचि ङमुण्नित्यम्
                    end
                end
                // 8.3.34–8.3.37 on a visarga in C1, then in C2
                if (c[`C_C1] == `PH_VIS && is_khar(c[`C_R])) begin
                    if (c[`C_R] == `PH_K || c[`C_R] == `PH_KH || c[`C_R] == `PH_P || c[`C_R] == `PH_PH) begin
                        f = c; f[`C_C1] = (c[`C_R] == `PH_K || c[`C_R] == `PH_KH) ? `PH_JIHVA : `PH_UPADH; f[24 + `T_8_3_37] = 1'b1;
                    end else if (c[`C_R] == `PH_SH || c[`C_R] == `PH_SS || c[`C_R] == `PH_S) begin
                        f = c; f[24 + `T_8_3_36] = 1'b1;                              // वा शरि: visarga stays (optional)
                        c[`C_C1] = `PH_S; c[24 + `T_8_3_34] = 1'b1;
                    end else begin
                        c[`C_C1] = `PH_S; c[24 + `T_8_3_34] = 1'b1;                   // विसर्जनीयस्य सः
                    end
                end
                if (c[`C_C2] == `PH_VIS && is_khar(c[`C_R])) begin
                    if (c[`C_R] == `PH_K || c[`C_R] == `PH_KH || c[`C_R] == `PH_P || c[`C_R] == `PH_PH) begin
                        f = c; f[`C_C2] = (c[`C_R] == `PH_K || c[`C_R] == `PH_KH) ? `PH_JIHVA : `PH_UPADH; f[24 + `T_8_3_37] = 1'b1;
                    end else if (c[`C_R] == `PH_SH || c[`C_R] == `PH_SS || c[`C_R] == `PH_S) begin
                        f = c; f[24 + `T_8_3_36] = 1'b1;
                        c[`C_C2] = `PH_S; c[24 + `T_8_3_34] = 1'b1;
                    end else begin
                        c[`C_C2] = `PH_S; c[24 + `T_8_3_34] = 1'b1;
                    end
                end
            end
        end
        main = c; fork_out = f;
    end
endmodule

// ---------------------------------------------------------------------------
// Stage C — 8.4
// ---------------------------------------------------------------------------
module hal_stage_c (
    input  wire [`CW-1:0] in,
    input  wire [5:0]     r2,
    output reg  [`CW-1:0] main,
    output reg  [`CW-1:0] fork_out
);
    `include "hal_classes.vh"
    reg [`CW-1:0] c, f;
    reg [5:0] x, nxt;
    reg use_c2;
    always @* begin
        c = in; f = {`CW{1'b0}};
        if (in[`C_VALID]) begin
            use_c2 = (c[`C_C2] != `PH_NONE);
            // 8.4.40 स्तोः श्चुना श्चुः — right to left, so a changed sound feeds the one before it
            if (use_c2 && (c[`C_C2] == `PH_S || is_tvarga(c[`C_C2])) && (c[`C_R] == `PH_SH || is_cvarga(c[`C_R]))) begin
                c[`C_C2] = scutva(c[`C_C2]); c[24 + `T_8_4_40] = 1'b1;
            end
            nxt = use_c2 ? c[`C_C2] : c[`C_R];
            if (c[`C_C1] != `PH_NONE && nxt != `PH_NONE && (c[`C_C1] == `PH_S || is_tvarga(c[`C_C1])) && (nxt == `PH_SH || is_cvarga(nxt))) begin
                c[`C_C1] = scutva(c[`C_C1]); c[24 + `T_8_4_40] = 1'b1;
            end
            // 8.4.41 ष्टुना ष्टुः (the reverse direction is barred here by 8.4.42)
            if (use_c2 && (c[`C_C2] == `PH_S || is_tvarga(c[`C_C2])) && (c[`C_R] == `PH_SS || is_retro(c[`C_R]))) begin
                c[`C_C2] = stutva(c[`C_C2]); c[24 + `T_8_4_41] = 1'b1;
            end
            nxt = use_c2 ? c[`C_C2] : c[`C_R];
            if (c[`C_C1] != `PH_NONE && nxt != `PH_NONE && (c[`C_C1] == `PH_S || is_tvarga(c[`C_C1])) && (nxt == `PH_SS || is_retro(nxt))) begin
                c[`C_C1] = stutva(c[`C_C1]); c[24 + `T_8_4_41] = 1'b1;
            end
            x = use_c2 ? c[`C_C2] : c[`C_C1];                                       // the sound before R
            if (is_jas(x) && is_nasal(c[`C_R])) begin                               // यरोऽनुनासिकेऽनुनासिको वा
                f = c; if (use_c2) f[`C_C2] = nasal_of(x); else f[`C_C1] = nasal_of(x); f[24 + `T_8_4_45] = 1'b1;
            end
            if (is_car_src(c[`C_C1]) && use_c2 && is_khar(c[`C_C2])) begin          // खरि च, inside the juncture
                c[`C_C1] = car_of(c[`C_C1]); c[24 + `T_8_4_55] = 1'b1;
            end
            x = use_c2 ? c[`C_C2] : c[`C_C1];
            if (is_car_src(x) && is_khar(c[`C_R])) begin                            // खरि च
                if (use_c2) c[`C_C2] = car_of(x); else c[`C_C1] = car_of(x); c[24 + `T_8_4_55] = 1'b1;
            end else if (is_car_src(x) && c[`C_R] == `PH_NONE) begin                // वावसाने (optional)
                f = c; if (use_c2) f[`C_C2] = car_of(x); else f[`C_C1] = car_of(x); f[24 + `T_8_4_56] = 1'b1;
            end
            if (c[`C_C1] == `PH_ANUS && !use_c2 && is_yay(c[`C_R]) && class_nasal(c[`C_R]) != `PH_NONE) begin
                f = c; f[`C_C1] = class_nasal(c[`C_R]); f[24 + `T_8_4_59] = 1'b1;    // वा पदान्तस्य (optional)
            end
            x = use_c2 ? c[`C_C2] : c[`C_C1];
            if ((x == `PH_D || x == `PH_N) && c[`C_R] == `PH_LA) begin              // तोर्लि
                if (use_c2) c[`C_C2] = (x == `PH_D) ? `PH_LA : `PH_LNAS; else c[`C_C1] = (x == `PH_D) ? `PH_LA : `PH_LNAS;
                c[24 + `T_8_4_60] = 1'b1;
            end
            x = use_c2 ? c[`C_C2] : c[`C_C1];
            if (c[`C_R] == `PH_H && is_jas(x)) begin                                // झयो होऽन्यतरस्याम् (optional)
                f = c; f[`C_R] = aspirate_of(x); f[24 + `T_8_4_62] = 1'b1;
            end
            if (c[`C_R] == `PH_SH && is_jhay(x) && is_at(r2)) begin                 // शश्छोऽटि (optional)
                f = c; f[`C_R] = `PH_CH; f[24 + `T_8_4_63] = 1'b1;
            end
        end
        main = c; fork_out = f;
    end
endmodule
