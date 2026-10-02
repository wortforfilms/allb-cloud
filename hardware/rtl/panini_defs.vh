// ============================================================================
// panini_defs.vh — shared codes for the Paninian datapath (Maataa AAI × Siddham)
//
// Phoneme codes (6 bits). Vowels first, long forms included, because sandhi
// distinguishes length; consonants follow in Shiva Sutra order.
// Sound text and rules: Ashtadhyayi (data/sources/vidyut, MIT licence).
// ============================================================================
`ifndef PANINI_DEFS_VH
`define PANINI_DEFS_VH

// --- vowels (ac) ------------------------------------------------------------
`define PH_A    6'd0   // अ a
`define PH_AA   6'd1   // आ ā
`define PH_I    6'd2   // इ i
`define PH_II   6'd3   // ई ī
`define PH_U    6'd4   // उ u
`define PH_UU   6'd5   // ऊ ū
`define PH_R    6'd6   // ऋ ṛ
`define PH_RR   6'd7   // ॠ ṝ
`define PH_L    6'd8   // ऌ ḷ
`define PH_LL   6'd9   // ॡ ḹ
`define PH_E    6'd10  // ए e
`define PH_AI   6'd11  // ऐ ai
`define PH_O    6'd12  // ओ o
`define PH_AU   6'd13  // औ au
// --- consonants (hal), Shiva Sutra order -------------------------------------
`define PH_H    6'd14  // ह (sutras 5 and 14)
`define PH_Y    6'd15  // य
`define PH_V    6'd16  // व
`define PH_RA   6'd17  // र
`define PH_LA   6'd18  // ल
`define PH_NY   6'd19  // ञ
`define PH_M    6'd20  // म
`define PH_NG   6'd21  // ङ
`define PH_NN   6'd22  // ण
`define PH_N    6'd23  // न
`define PH_JH   6'd24  // झ
`define PH_BH   6'd25  // भ
`define PH_GH   6'd26  // घ
`define PH_DDH  6'd27  // ढ
`define PH_DH   6'd28  // ध
`define PH_J    6'd29  // ज
`define PH_B    6'd30  // ब
`define PH_G    6'd31  // ग
`define PH_DD   6'd32  // ड
`define PH_D    6'd33  // द
`define PH_KH   6'd34  // ख
`define PH_PH   6'd35  // फ
`define PH_CH   6'd36  // छ
`define PH_TTH  6'd37  // ठ
`define PH_TH   6'd38  // थ
`define PH_C    6'd39  // च
`define PH_TT   6'd40  // ट
`define PH_T    6'd41  // त
`define PH_K    6'd42  // क
`define PH_P    6'd43  // प
`define PH_SH   6'd44  // श
`define PH_SS   6'd45  // ष
`define PH_S    6'd46  // स
`define PH_NONE 6'd63  // empty slot

// --- rule ids reported by the sandhi engine -----------------------------------
`define RULE_NONE      3'd0
`define RULE_6_1_77    3'd1  // इको यणचि            ik + ac  -> yaṇ
`define RULE_6_1_78    3'd2  // एचोऽयवायावः          ec + ac  -> ay av āy āv
`define RULE_6_1_87    3'd3  // आद्गुणः              a/ā + ac -> guṇa (ekādeśa)
`define RULE_6_1_88    3'd4  // वृद्धिरेचि            a/ā + ec -> vṛddhi (ekādeśa)
`define RULE_6_1_101   3'd5  // अकः सवर्णे दीर्घः      ak + savarṇa -> dīrgha (ekādeśa)
`define RULE_6_1_109   3'd6  // एङः पदान्तादति         eṅ at pada end + a -> pūrvarūpa

`endif
