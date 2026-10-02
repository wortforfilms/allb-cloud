// ============================================================================
// hal_classes.vh — sound classes and substitutions for consonant/visarga sandhi.
// Included inside module bodies. Codes are from panini_defs.vh.
// ============================================================================
function is_vowel(input [5:0] p);  is_vowel = (p <= `PH_AU); endfunction
function is_short(input [5:0] p);  is_short = (p == `PH_A || p == `PH_I || p == `PH_U || p == `PH_R || p == `PH_L); endfunction
function is_hal(input [5:0] p);    is_hal   = (p >= `PH_H && p <= `PH_S); endfunction
function is_hash(input [5:0] p);   is_hash  = (p >= `PH_H && p <= `PH_D); endfunction            // हश्: voiced consonants
function is_khar(input [5:0] p);   is_khar  = (p >= `PH_KH && p <= `PH_S); endfunction           // खर्: voiceless
function is_as(input [5:0] p);     is_as    = is_vowel(p) || is_hash(p); endfunction              // अश्
function is_nasal(input [5:0] p);  is_nasal = (p >= `PH_NY && p <= `PH_N); endfunction
function is_jhay(input [5:0] p);   is_jhay  = (p >= `PH_JH && p <= `PH_P); endfunction           // झय्: stops
function is_yay(input [5:0] p);    is_yay   = (p >= `PH_Y && p <= `PH_P); endfunction            // यय्: not श ष स ह
function is_am(input [5:0] p);     is_am    = is_vowel(p) || (p >= `PH_H && p <= `PH_N); endfunction // अम्
function is_at(input [5:0] p);     is_at    = is_vowel(p) || (p >= `PH_H && p <= `PH_RA); endfunction // अट्
function is_cvarga(input [5:0] p); is_cvarga = (p == `PH_C || p == `PH_CH || p == `PH_J || p == `PH_JH || p == `PH_NY); endfunction
function is_retro(input [5:0] p);  is_retro  = (p == `PH_TT || p == `PH_TTH || p == `PH_DD || p == `PH_DDH || p == `PH_NN); endfunction
function is_tvarga(input [5:0] p); is_tvarga = (p == `PH_T || p == `PH_TH || p == `PH_D || p == `PH_DH || p == `PH_N); endfunction
function is_chav(input [5:0] p);   is_chav   = (p == `PH_C || p == `PH_CH || p == `PH_TT || p == `PH_TTH || p == `PH_T || p == `PH_TH); endfunction
function is_jas(input [5:0] p);    is_jas    = (p == `PH_G || p == `PH_DD || p == `PH_D || p == `PH_B || p == `PH_J); endfunction
function is_car_src(input [5:0] p); is_car_src = is_jas(p) || (p == `PH_DH); endfunction      // jaś, and dhuṭ (8.3.30)

function [5:0] jas_of(input [5:0] p);       // 8.2.39
    case (p) `PH_K: jas_of = `PH_G; `PH_TT: jas_of = `PH_DD; `PH_T: jas_of = `PH_D; `PH_P: jas_of = `PH_B; default: jas_of = p; endcase
endfunction
function [5:0] car_of(input [5:0] p);       // 8.4.55
    case (p) `PH_G: car_of = `PH_K; `PH_DD: car_of = `PH_TT; `PH_D, `PH_DH: car_of = `PH_T; `PH_B: car_of = `PH_P; `PH_J: car_of = `PH_C; default: car_of = p; endcase
endfunction
function [5:0] nasal_of(input [5:0] p);     // 8.4.45
    case (p) `PH_G: nasal_of = `PH_NG; `PH_DD: nasal_of = `PH_NN; `PH_D: nasal_of = `PH_N; `PH_B: nasal_of = `PH_M; `PH_J: nasal_of = `PH_NY; default: nasal_of = p; endcase
endfunction
function [5:0] aspirate_of(input [5:0] p);  // 8.4.62
    case (p) `PH_G: aspirate_of = `PH_GH; `PH_DD: aspirate_of = `PH_DDH; `PH_D: aspirate_of = `PH_DH; `PH_B: aspirate_of = `PH_BH; `PH_J: aspirate_of = `PH_JH; default: aspirate_of = p; endcase
endfunction
function [5:0] scutva(input [5:0] p);       // 8.4.40
    case (p) `PH_S: scutva = `PH_SH; `PH_T: scutva = `PH_C; `PH_TH: scutva = `PH_CH; `PH_D: scutva = `PH_J; `PH_DH: scutva = `PH_JH; `PH_N: scutva = `PH_NY; default: scutva = p; endcase
endfunction
function [5:0] stutva(input [5:0] p);       // 8.4.41
    case (p) `PH_S: stutva = `PH_SS; `PH_T: stutva = `PH_TT; `PH_TH: stutva = `PH_TTH; `PH_D: stutva = `PH_DD; `PH_DH: stutva = `PH_DDH; `PH_N: stutva = `PH_NN; default: stutva = p; endcase
endfunction
function [5:0] class_nasal(input [5:0] p);  // 8.4.59: the nasal of the following sound's class; NONE if it has none
    case (p)
        `PH_K, `PH_KH, `PH_G, `PH_GH:   class_nasal = `PH_NG;
        `PH_C, `PH_CH, `PH_J, `PH_JH:   class_nasal = `PH_NY;
        `PH_TT, `PH_TTH, `PH_DD, `PH_DDH: class_nasal = `PH_NN;
        `PH_T, `PH_TH, `PH_D, `PH_DH:   class_nasal = `PH_N;
        `PH_P, `PH_PH, `PH_B, `PH_BH:   class_nasal = `PH_M;
        `PH_NY, `PH_M, `PH_NG, `PH_NN, `PH_N: class_nasal = p;
        `PH_LA:                         class_nasal = `PH_LNAS;
        default:                        class_nasal = `PH_NONE;
    endcase
endfunction
function [5:0] dirgha_aiu(input [5:0] p);   // 6.3.111 (aṇ = अ इ उ)
    case (p) `PH_A: dirgha_aiu = `PH_AA; `PH_I: dirgha_aiu = `PH_II; `PH_U: dirgha_aiu = `PH_UU; default: dirgha_aiu = p; endcase
endfunction
