//! Sandhi Matrix & Fast Byte-level Junction Engine

use crate::panini_engine::phoneme_codec::{devanagari_to_slp1, slp1_to_devanagari};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DerivationTrace {
    pub sutra_id: String,
    pub gate_triggered: String,
    pub sthani: String,
    pub adesha: String,
    pub result_form_devanagari: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SandhiResult {
    pub original_left: String,
    pub original_right: String,
    pub combined_form: String,
    pub trace: Option<DerivationTrace>,
}

#[inline]
fn is_slp1_vowel_byte(b: u8) -> bool {
    matches!(
        b,
        b'a' | b'A' | b'i' | b'I' | b'u' | b'U' | b'f' | b'F' | b'e' | b'E' | b'o' | b'O'
    )
}

#[inline]
fn get_vowel_family(b: u8) -> u8 {
    match b {
        b'a' | b'A' => 1,
        b'i' | b'I' => 2,
        b'u' | b'U' => 3,
        b'f' | b'F' => 4,
        _ => 0,
    }
}

#[inline]
fn get_long_vowel(b: u8) -> &'static str {
    match b {
        b'a' | b'A' => "A",
        b'i' | b'I' => "I",
        b'u' | b'U' => "U",
        b'f' | b'F' => "F",
        _ => "",
    }
}

#[inline]
fn apply_scutva(b: u8) -> Option<u8> {
    match b {
        b's' => Some(b'S'),
        b't' => Some(b'c'),
        b'T' => Some(b'C'),
        b'd' => Some(b'j'),
        b'D' => Some(b'J'),
        b'n' => Some(b'Y'),
        _ => None,
    }
}

#[inline]
fn is_scutva_trigger(b: u8) -> bool {
    matches!(b, b'S' | b'c' | b'C' | b'j' | b'J' | b'Y')
}

#[allow(dead_code)]
#[inline]
fn is_soft_consonant_or_a_byte(b: u8) -> bool {
    matches!(
        b,
        b'a' | b'g'
            | b'G'
            | b'N'
            | b'j'
            | b'J'
            | b'Y'
            | b'q'
            | b'Q'
            | b'R'
            | b'd'
            | b'D'
            | b'n'
            | b'b'
            | b'B'
            | b'm'
            | b'y'
            | b'r'
            | b'l'
            | b'v'
            | b'h'
    )
}

pub fn execute_sandhi_gate_fast(left_dev: &str, right_dev: &str) -> SandhiResult {
    let left_slp1 = devanagari_to_slp1(left_dev);
    let right_slp1 = devanagari_to_slp1(right_dev);

    let left_bytes = left_slp1.as_bytes();
    let right_bytes = right_slp1.as_bytes();

    if left_bytes.is_empty() || right_bytes.is_empty() {
        return SandhiResult {
            original_left: left_dev.to_string(),
            original_right: right_dev.to_string(),
            combined_form: format!("{}{}", left_dev, right_dev),
            trace: None,
        };
    }

    let last_b = left_bytes[left_bytes.len() - 1];
    let first_b = right_bytes[0];

    // 1. SCUTVA-SANDHI GATE (8.4.40)
    if let Some(scutva_subst) = apply_scutva(last_b) {
        if is_scutva_trigger(first_b) {
            let prefix = &left_slp1[..left_slp1.len() - 1];
            let combined_slp1 = format!("{}{}{}", prefix, scutva_subst as char, right_slp1);
            let combined_dev = slp1_to_devanagari(&combined_slp1);

            return SandhiResult {
                original_left: left_dev.to_string(),
                original_right: right_dev.to_string(),
                combined_form: combined_dev.clone(),
                trace: Some(DerivationTrace {
                    sutra_id: "8.4.40".to_string(),
                    gate_triggered: "SANDHI_GATE_TYPE_6_SCUTVA".to_string(),
                    sthani: "सकार/तवर्ग".to_string(),
                    adesha: "शकार/चवर्ग".to_string(),
                    result_form_devanagari: combined_dev,
                }),
            };
        }
    }

    // 2. SAVARNA DIRGHA-SANDHI GATE (6.1.101)
    let family_left = get_vowel_family(last_b);
    let family_right = get_vowel_family(first_b);
    if family_left > 0 && family_left == family_right {
        let prefix = &left_slp1[..left_slp1.len() - 1];
        let long_vowel = get_long_vowel(last_b);
        let suffix = &right_slp1[1..];
        let combined_slp1 = format!("{}{}{}", prefix, long_vowel, suffix);
        let combined_dev = slp1_to_devanagari(&combined_slp1);

        return SandhiResult {
            original_left: left_dev.to_string(),
            original_right: right_dev.to_string(),
            combined_form: combined_dev.clone(),
            trace: Some(DerivationTrace {
                sutra_id: "6.1.101".to_string(),
                gate_triggered: "SANDHI_GATE_TYPE_5_DIRGHA".to_string(),
                sthani: "सवर्ण अकः".to_string(),
                adesha: "दीर्घ स्वर".to_string(),
                result_form_devanagari: combined_dev,
            }),
        };
    }

    // 3. YAN-SANDHI GATE (6.1.77)
    if matches!(last_b, b'i' | b'I' | b'u' | b'U' | b'f' | b'F') && is_slp1_vowel_byte(first_b) {
        let prefix = &left_slp1[..left_slp1.len() - 1];
        let (semivowel, sthani_desc, adesha_desc) = match last_b {
            b'i' | b'I' => ("y", "इ/ई (i)", "य् (y)"),
            b'u' | b'U' => ("v", "उ/ऊ (u)", "व् (v)"),
            b'f' | b'F' => ("r", "ऋ/ॠ (f)", "र् (r)"),
            _ => ("", "", ""),
        };

        let combined_slp1 = format!("{}{}{}", prefix, semivowel, right_slp1);
        let combined_dev = slp1_to_devanagari(&combined_slp1);

        return SandhiResult {
            original_left: left_dev.to_string(),
            original_right: right_dev.to_string(),
            combined_form: combined_dev.clone(),
            trace: Some(DerivationTrace {
                sutra_id: "6.1.77".to_string(),
                gate_triggered: "SANDHI_GATE_TYPE_1_YAN".to_string(),
                sthani: sthani_desc.to_string(),
                adesha: adesha_desc.to_string(),
                result_form_devanagari: combined_dev,
            }),
        };
    }

    // 4. GUNA-SANDHI GATE (6.1.87)
    if (last_b == b'a' || last_b == b'A') && matches!(first_b, b'i' | b'I' | b'u' | b'U') {
        let prefix = &left_slp1[..left_slp1.len() - 1];
        let suffix = &right_slp1[1..];
        let (subst, adesha_desc) = match first_b {
            b'i' | b'I' => ("e", "ए (e)"),
            b'u' | b'U' => ("o", "ओ (o)"),
            _ => ("", ""),
        };
        let combined_slp1 = format!("{}{}{}", prefix, subst, suffix);
        let combined_dev = slp1_to_devanagari(&combined_slp1);

        return SandhiResult {
            original_left: left_dev.to_string(),
            original_right: right_dev.to_string(),
            combined_form: combined_dev.clone(),
            trace: Some(DerivationTrace {
                sutra_id: "6.1.87".to_string(),
                gate_triggered: "SANDHI_GATE_TYPE_2_GUNA".to_string(),
                sthani: "अ/आ + इ/ई/उ/ऊ".to_string(),
                adesha: adesha_desc.to_string(),
                result_form_devanagari: combined_dev,
            }),
        };
    }

    SandhiResult {
        original_left: left_dev.to_string(),
        original_right: right_dev.to_string(),
        combined_form: format!("{}{}", left_dev, right_dev),
        trace: None,
    }
}
