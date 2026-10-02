// ============================================================================
// Module:      sivasutra_rom
// Description: Pratyāhāra membership in one combinational step.
//
// Panini's 14 Shiva Sutras list 43 sound slots, each sutra closed by a marker
// (it). A pratyāhāra = first sound + marker names every sound from that sound
// up to the end of the marker's sutra (1.1.71 आदिरन्त्येन सहेता). This is a
// range in a fixed order, so it needs position comparators, not a CAM.
//
// The two known quirks are handled exactly:
//   ह  appears in sutra 5 (हयवरट्) and sutra 14 (हल्). A pratyāhāra that starts
//      with ह starts at the first one; ह is a member if EITHER slot is in range
//      (so शल् = श ष स ह includes ह, through slot 42).
//   ण् closes sutra 1 (अइउण्) and sutra 6 (लण्). The marker is given as the
//      sutra number, so aṇ(1) = अ इ उ (used by 1.1.51 उरण् रपरः) and
//      aṇ(6) = अ … ल (used elsewhere, e.g. 1.1.69) are different inputs.
//
// savarna_expand: by 1.1.69 अणुदित् सवर्णस्य चाप्रत्ययः a short vowel letter
// also names its long form, so ac covers आ ई ऊ ॠ ॡ as well.
// ============================================================================
`timescale 1ns / 1ps
`include "panini_defs.vh"

module sivasutra_rom (
    input  wire [5:0]  start,          // phoneme code of the first sound
    input  wire [3:0]  marker,         // Shiva Sutra number of the closing marker (1..14)
    input  wire        savarna_expand, // 1.1.69: include long vowels
    output reg  [63:0] mask,           // bit p set = phoneme code p is a member
    output reg         valid           // start sound found and lies before the marker
);
    localparam integer SLOTS = 43;

    function [5:0] slot_code(input integer s);
        case (s)
            0: slot_code = `PH_A;   1: slot_code = `PH_I;   2: slot_code = `PH_U;
            3: slot_code = `PH_R;   4: slot_code = `PH_L;
            5: slot_code = `PH_E;   6: slot_code = `PH_O;
            7: slot_code = `PH_AI;  8: slot_code = `PH_AU;
            9: slot_code = `PH_H;  10: slot_code = `PH_Y;  11: slot_code = `PH_V;  12: slot_code = `PH_RA;
           13: slot_code = `PH_LA;
           14: slot_code = `PH_NY; 15: slot_code = `PH_M;  16: slot_code = `PH_NG; 17: slot_code = `PH_NN; 18: slot_code = `PH_N;
           19: slot_code = `PH_JH; 20: slot_code = `PH_BH;
           21: slot_code = `PH_GH; 22: slot_code = `PH_DDH; 23: slot_code = `PH_DH;
           24: slot_code = `PH_J;  25: slot_code = `PH_B;  26: slot_code = `PH_G;  27: slot_code = `PH_DD; 28: slot_code = `PH_D;
           29: slot_code = `PH_KH; 30: slot_code = `PH_PH; 31: slot_code = `PH_CH; 32: slot_code = `PH_TTH; 33: slot_code = `PH_TH;
           34: slot_code = `PH_C;  35: slot_code = `PH_TT; 36: slot_code = `PH_T;
           37: slot_code = `PH_K;  38: slot_code = `PH_P;
           39: slot_code = `PH_SH; 40: slot_code = `PH_SS; 41: slot_code = `PH_S;
           42: slot_code = `PH_H;
           default: slot_code = `PH_NONE;
        endcase
    endfunction

    // First slot of a sound (ह -> slot 9, its first occurrence); 63 = not a Shiva Sutra sound.
    function [5:0] first_slot(input [5:0] p);
        case (p)
            `PH_A: first_slot = 6'd0;   `PH_I: first_slot = 6'd1;   `PH_U: first_slot = 6'd2;
            `PH_R: first_slot = 6'd3;   `PH_L: first_slot = 6'd4;   `PH_E: first_slot = 6'd5;
            `PH_O: first_slot = 6'd6;   `PH_AI: first_slot = 6'd7;  `PH_AU: first_slot = 6'd8;
            `PH_H: first_slot = 6'd9;   `PH_Y: first_slot = 6'd10;  `PH_V: first_slot = 6'd11;
            `PH_RA: first_slot = 6'd12; `PH_LA: first_slot = 6'd13; `PH_NY: first_slot = 6'd14;
            `PH_M: first_slot = 6'd15;  `PH_NG: first_slot = 6'd16; `PH_NN: first_slot = 6'd17;
            `PH_N: first_slot = 6'd18;  `PH_JH: first_slot = 6'd19; `PH_BH: first_slot = 6'd20;
            `PH_GH: first_slot = 6'd21; `PH_DDH: first_slot = 6'd22; `PH_DH: first_slot = 6'd23;
            `PH_J: first_slot = 6'd24;  `PH_B: first_slot = 6'd25;  `PH_G: first_slot = 6'd26;
            `PH_DD: first_slot = 6'd27; `PH_D: first_slot = 6'd28;  `PH_KH: first_slot = 6'd29;
            `PH_PH: first_slot = 6'd30; `PH_CH: first_slot = 6'd31; `PH_TTH: first_slot = 6'd32;
            `PH_TH: first_slot = 6'd33; `PH_C: first_slot = 6'd34;  `PH_TT: first_slot = 6'd35;
            `PH_T: first_slot = 6'd36;  `PH_K: first_slot = 6'd37;  `PH_P: first_slot = 6'd38;
            `PH_SH: first_slot = 6'd39; `PH_SS: first_slot = 6'd40; `PH_S: first_slot = 6'd41;
            default: first_slot = 6'd63;   // long vowels are named through their short form (1.1.69)
        endcase
    endfunction

    // Last slot of each sutra (the sound just before its marker); 63 = no such sutra.
    function [5:0] sutra_end(input [3:0] m);
        case (m)
            4'd1: sutra_end = 6'd2;   4'd2: sutra_end = 6'd4;   4'd3: sutra_end = 6'd6;   4'd4: sutra_end = 6'd8;
            4'd5: sutra_end = 6'd12;  4'd6: sutra_end = 6'd13;  4'd7: sutra_end = 6'd18;  4'd8: sutra_end = 6'd20;
            4'd9: sutra_end = 6'd23;  4'd10: sutra_end = 6'd28; 4'd11: sutra_end = 6'd36; 4'd12: sutra_end = 6'd38;
            4'd13: sutra_end = 6'd41; 4'd14: sutra_end = 6'd42;
            default: sutra_end = 6'd63;
        endcase
    endfunction

    wire [5:0] first = first_slot(start);
    wire [5:0] last  = sutra_end(marker);
    integer s;
    always @* begin
        valid = (first != 6'd63) && (last != 6'd63) && (first <= last);
        mask  = 64'd0;
        for (s = 0; s < SLOTS; s = s + 1)
            if (valid && s[5:0] >= first && s[5:0] <= last) mask[slot_code(s)] = 1'b1;  // ह: either slot sets the same bit
        if (savarna_expand) begin
            if (mask[`PH_A]) mask[`PH_AA] = 1'b1;
            if (mask[`PH_I]) mask[`PH_II] = 1'b1;
            if (mask[`PH_U]) mask[`PH_UU] = 1'b1;
            if (mask[`PH_R]) mask[`PH_RR] = 1'b1;
            if (mask[`PH_L]) mask[`PH_LL] = 1'b1;
        end
    end
endmodule
