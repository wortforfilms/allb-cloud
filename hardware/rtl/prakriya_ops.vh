// prakriya_ops.vh — state layout and operation blocks of prakriya_core (included in module bodies).
    localparam W = DMAX*6 + 4 + 10 + 2 + 3 + 3;
    localparam D_LO = 0, LEN_LO = DMAX*6, F_LO = DMAX*6 + 4;
    localparam IDIT = F_LO+0, ANUD = F_LO+1, SVAR = F_LO+2, NIT = F_LO+3, YIT = F_LO+4,
               NUM = F_LO+5, GUNA = F_LO+6, ANGA = F_LO+7, PADA = F_LO+8, ATM = F_LO+9;
    localparam T1_LO = F_LO+10, T2_LO = F_LO+12, T2S = F_LO+15, T2N = F_LO+16, T1S = F_LO+17;
    localparam [2:0] T2_NONE = 0, T2_LAW = 1, T2_L = 2, T2_TIP = 3, T2_TI = 4, T2_TA = 5, T2_TE = 6;
    localparam [1:0] T1_NONE = 0, T1_SAP = 1, T1_A = 2;
    localparam integer OP_3_1_68 = 0, OP_3_2_123 = 1, OP_3_4_78 = 2, OP_3_4_79 = 3,
                       OP_6_1_78 = 4, OP_7_1_58 = 5, OP_7_3_84 = 6, OP_7_3_86 = 7, NOPS = 8;
    function [5:0] dch(input [W-1:0] s, input integer i); dch = s[D_LO + i*6 +: 6]; endfunction   // constant i only
    function [3:0] dlen(input [W-1:0] s); dlen = s[LEN_LO +: 4]; endfunction
    function [1:0] t1(input [W-1:0] s); t1 = s[T1_LO +: 2]; endfunction
    function [2:0] t2(input [W-1:0] s); t2 = s[T2_LO +: 3]; endfunction
    function is_vowel(input [5:0] p); is_vowel = (p <= `PH_AU); endfunction
    function is_ik(input [5:0] p); is_ik = (p >= `PH_I && p <= `PH_LL); endfunction
    function is_short_ik(input [5:0] p); is_short_ik = (p == `PH_I || p == `PH_U || p == `PH_R || p == `PH_L); endfunction
    function is_ec(input [5:0] p); is_ec = (p >= `PH_E && p <= `PH_AU); endfunction
    function is_jhal(input [5:0] p); is_jhal = (p >= `PH_JH && p <= `PH_S) || p == `PH_H; endfunction
    function is_yay(input [5:0] p); is_yay = (p >= `PH_Y && p <= `PH_P); endfunction
    function [5:0] class_nasal(input [5:0] p);
        case (p)
            `PH_K, `PH_KH, `PH_G, `PH_GH:     class_nasal = `PH_NG;
            `PH_C, `PH_CH, `PH_J, `PH_JH:     class_nasal = `PH_NY;
            `PH_TT, `PH_TTH, `PH_DD, `PH_DDH: class_nasal = `PH_NN;
            `PH_T, `PH_TH, `PH_D, `PH_DH:     class_nasal = `PH_N;
            `PH_P, `PH_PH, `PH_B, `PH_BH:     class_nasal = `PH_M;
            default:                          class_nasal = p;
        endcase
    endfunction

    // insert letter c at position pos (shifting the rest right)
    function [W-1:0] ins_at(input [W-1:0] s, input [3:0] pos, input [5:0] c);
        integer i; reg [W-1:0] x;
        begin
            x = s;
            for (i = 0; i < DMAX; i = i + 1)
                if (i[3:0] == pos) x[D_LO + i*6 +: 6] = c;
                else if (i > 0 && i[3:0] > pos) x[D_LO + i*6 +: 6] = s[D_LO + (i-1)*6 +: 6];
            x[LEN_LO +: 4] = dlen(s) + 4'd1;
            ins_at = x;
        end
    endfunction
    function [W-1:0] set_ch(input [W-1:0] s, input [3:0] pos, input [5:0] c);
        integer i; reg [W-1:0] x;
        begin x = s; for (i = 0; i < DMAX; i = i + 1) if (i[3:0] == pos) x[D_LO + i*6 +: 6] = c; set_ch = x; end
    endfunction
    function [5:0] dat(input [W-1:0] s, input [3:0] pos);
        integer i; begin dat = `PH_NONE; for (i = 0; i < DMAX; i = i + 1) if (i[3:0] == pos) dat = s[D_LO + i*6 +: 6]; end
    endfunction

    // guṇa of the letter at pos (1.1.2; ṛ ḷ take र् ल् by 1.1.51 उरण् रपरः)
    function [W-1:0] guna_at(input [W-1:0] s, input [3:0] pos);
        reg [5:0] c;
        begin
            c = dat(s, pos);
            if (c == `PH_I || c == `PH_II)      guna_at = set_ch(s, pos, `PH_E);
            else if (c == `PH_U || c == `PH_UU) guna_at = set_ch(s, pos, `PH_O);
            else if (c == `PH_R || c == `PH_RR) guna_at = ins_at(set_ch(s, pos, `PH_A), pos + 1, `PH_RA);
            else                                guna_at = ins_at(set_ch(s, pos, `PH_A), pos + 1, `PH_LA);
        end
    endfunction

    // ------------------------------------------------------------------ labels (state effect)
    function [W-1:0] labels(input [W-1:0] s, input [1:0] pc);
        reg [W-1:0] x;
        begin
            x = s;
            if (t2(x) == T2_LAW) begin                         // 1.3.2 1.3.3 1.3.9; 1.3.12 / 1.3.72 / 1.3.78; 1.4.13
                x[T2_LO +: 3] = T2_L; x[PADA] = 1'b1; x[ANGA] = 1'b1;
                x[ATM] = x[ANUD] | x[NIT] | ((x[SVAR] | x[YIT]) & (pc != 2'd2));
            end
            if (t2(x) == T2_TIP) begin x[T2_LO +: 3] = T2_TI; x[T2S] = 1'b1; end   // 1.3.3 1.3.9 3.4.113
            if (t2(x) == T2_TA && !x[T2S]) begin x[T2S] = 1'b1; x[T2N] = 1'b1; end  // 3.4.113 1.2.4
            if (t1(x) == T1_SAP) begin x[T1_LO +: 2] = T1_A; x[T1S] = 1'b1; end     // 1.3.3 1.3.8 1.3.9 3.4.113
            labels = x;
        end
    endfunction

    // ------------------------------------------------------------------ operations
    // the affix right after the aṅga, if it can trigger guṇa (sārvadhātuka, not ṅit-like: 1.1.5)
    function [1:0] guna_trig(input [W-1:0] s);
        if (t1(s) != T1_NONE)            guna_trig = (s[T1S]) ? 2'd2 : 2'd0;
        else if (s[T2S] && !s[T2N])      guna_trig = 2'd3;
        else                             guna_trig = 2'd0;
    endfunction

    // {valid, trigger(2), scope(2)}: trigger 0 none, 1 root, 2 vikaraṇa, 3 ending
    function [4:0] match(input integer k, input [W-1:0] s);
        reg [5:0] last, pen; reg [1:0] g;
        begin
            last = dat(s, dlen(s) - 4'd1); pen = dat(s, dlen(s) - 4'd2); g = guna_trig(s);
            case (k)
                OP_7_1_58:  match = {s[IDIT] && !s[NUM], 2'd1, 2'd1};                       // इदितो नुम् धातोः
                OP_3_2_123: match = {t2(s) == T2_NONE, 2'd0, 2'd2};                         // वर्तमाने लट्
                OP_3_4_78:  match = {t2(s) == T2_L && s[PADA], 2'd3, 2'd1};                 // तिप्तस्झि…
                OP_3_1_68:  match = {t1(s) == T1_NONE && s[T2S] && t2(s) >= T2_TI, 2'd3, 2'd2}; // कर्तरि शप्
                OP_3_4_79:  match = {t2(s) == T2_TA, 2'd3, 2'd1};                           // टित आत्मनेपदानां टेरे
                OP_7_3_84:  match = {g != 0 && is_ik(last) && !s[GUNA], g, 2'd2};           // सार्वधातुकार्धधातुकयोः
                OP_7_3_86:  match = {g != 0 && dlen(s) >= 2 && !is_vowel(last) && is_short_ik(pen) && !s[GUNA], g, 2'd2}; // पुगन्तलघूपधस्य च
                default:    match = {t1(s) == T1_A && is_ec(last), 2'd2, 2'd2};             // एचोऽयवायावः
            endcase
        end
    endfunction

    function [W-1:0] act(input integer k, input [W-1:0] s);
        integer i; reg [3:0] lv; reg [W-1:0] x; reg [5:0] last;
        begin
            x = s; last = dat(s, dlen(s) - 4'd1); lv = 0;
            case (k)
                OP_7_1_58: begin
                    for (i = 0; i < DMAX; i = i + 1) if (i < dlen(s) && is_vowel(dch(s, i))) lv = i;
                    x = ins_at(s, lv + 4'd1, `PH_N); x[NUM] = 1'b1;
                end
                OP_3_2_123: x[T2_LO +: 3] = T2_LAW;
                OP_3_4_78:  x[T2_LO +: 3] = s[ATM] ? T2_TA : T2_TIP;
                OP_3_1_68:  x[T1_LO +: 2] = T1_SAP;
                OP_3_4_79:  x[T2_LO +: 3] = T2_TE;
                OP_7_3_84:  begin x = guna_at(s, dlen(s) - 4'd1); x[GUNA] = 1'b1; end
                OP_7_3_86:  begin x = guna_at(s, dlen(s) - 4'd2); x[GUNA] = 1'b1; end
                default: begin                                                  // e o ai au -> ay av āy āv
                    x = set_ch(s, dlen(s) - 4'd1, (last == `PH_AI || last == `PH_AU) ? `PH_AA : `PH_A);
                    x = ins_at(x, dlen(s), (last == `PH_E || last == `PH_AI) ? `PH_Y : `PH_V);
                end
            endcase
            act = x;
        end
    endfunction

