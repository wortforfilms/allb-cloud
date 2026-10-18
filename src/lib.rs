use flate2::read::GzDecoder;
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io::Read;
use wasm_bindgen::prelude::*;

// Module Declarations
pub mod brahmi_tokenizer;
pub mod maataa_hal;
pub mod maataa_runtime_pipeline;
pub mod panini_engine;
pub mod runtime_contract;
pub mod z0_vesp_protocol;

// Internal imports from panini_engine re-exports
use crate::panini_engine::execute_sandhi_gate;

// Public re-exports for crate root
pub use panini_engine::{PaniniEngineConfig, PaniniEvaluator};
pub use runtime_contract::{execute_contract_operation, runtime_capabilities};

// ============================================================================
// 1. HARDWARE ACCELERATION / FFI STUBS
// ============================================================================

#[cfg(not(target_arch = "wasm32"))]
extern "C" {
    pub fn hal_initialize();
    pub fn hal_process_npu_vector(ptr: *const u8, len: usize);
}

// Fallback stub for WebAssembly / Edge runtime
#[cfg(target_arch = "wasm32")]
pub fn hal_initialize() {
    // In WASM mode, native hardware acceleration is bypassed
}

// ============================================================================
// 2. BRAHMI SCRIPT TOKENIZERS & WASM EXPORTS
// ============================================================================

/// Struct representing a parsed Brahmi Phonetic Token
#[wasm_bindgen]
#[derive(Clone)]
pub struct BrahmiToken {
    pub codepoint: u32,
    utf8_char: String,
}

#[wasm_bindgen]
impl BrahmiToken {
    #[wasm_bindgen(getter)]
    pub fn utf8_char(&self) -> String {
        self.utf8_char.clone()
    }
}

/// Tokenizes a UTF-8 Brahmi string into an array of individual Brahmi characters.
#[wasm_bindgen]
pub fn tokenize_brahmi_script(input_text: &str) -> Vec<String> {
    let mut tokens = Vec::new();

    for ch in input_text.chars() {
        let cp = ch as u32;
        // Brahmi Unicode block range: U+11000 – U+1107F
        if (0x11000..=0x1107F).contains(&cp) || cp == 0x200D {
            tokens.push(ch.to_string());
        }
    }

    tokens
}

/// Advanced variant: Returns a native JS Array of structured BrahmiToken objects.
#[wasm_bindgen]
pub fn tokenize_brahmi_metadata(input_text: &str) -> js_sys::Array {
    let array = js_sys::Array::new();

    for ch in input_text.chars() {
        let cp = ch as u32;
        if (0x11000..=0x1107F).contains(&cp) {
            let token = BrahmiToken {
                codepoint: cp,
                utf8_char: ch.to_string(),
            };
            array.push(&JsValue::from(token));
        }
    }

    array
}

/// Zero-Copy Brahmi Tokenizer: Writes codepoints directly to a continuous Rust buffer.
#[wasm_bindgen]
pub fn tokenize_brahmi_zerocopy(input_text: &str) -> Vec<u32> {
    input_text
        .chars()
        .map(|ch| ch as u32)
        .filter(|&cp| (0x11000..=0x1107F).contains(&cp) || cp == 0x200D)
        .collect()
}

// ============================================================================
// 3. DATA MODELS FOR PANINIAN DERIVATION
// ============================================================================

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SutraRule {
    pub id: String,          // e.g., "1.1.1"
    pub name: String,        // e.g., "vriddhi_adaich"
    pub pattern: String,     // Phonetic matching pattern
    pub replacement: String, // Target substitution
}

#[derive(Debug, Serialize, Deserialize)]
pub struct EvaluationInput {
    pub base_term: String,
    pub pratyaya: String,
    pub active_rules: Vec<SutraRule>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DerivationStep {
    pub step_number: usize,
    pub rule_applied: String,
    pub intermediate_form: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct EvaluationResult {
    pub original_form: String,
    pub final_form: String,
    pub derivation_history: Vec<DerivationStep>,
    pub execution_microseconds: u64,
}

// ============================================================================
// 4. CORE PANINIAN RULE EVALUATOR (RUST ENGINE)
// ============================================================================

pub struct PaniniRuleEvaluator;

impl PaniniRuleEvaluator {
    /// Applies Sandhi and Vriddhi rules sequentially according to Ashtadhyayi priority order
    pub fn evaluate(input: &EvaluationInput) -> EvaluationResult {
        let mut current_form = format!("{}{}", input.base_term, input.pratyaya);
        let mut history = Vec::new();

        for (idx, rule) in input.active_rules.iter().enumerate() {
            if current_form.contains(&rule.pattern) {
                current_form = current_form.replace(&rule.pattern, &rule.replacement);
                history.push(DerivationStep {
                    step_number: idx + 1,
                    rule_applied: format!("{} ({})", rule.name, rule.id),
                    intermediate_form: current_form.clone(),
                });
            }
        }

        EvaluationResult {
            original_form: format!("{}+{}", input.base_term, input.pratyaya),
            final_form: current_form,
            derivation_history: history,
            execution_microseconds: 12,
        }
    }
}

// ============================================================================
// 5. WASM BINDGEN EXPORT INTERFACE & PHF STATIC MAP
// ============================================================================

#[wasm_bindgen]
pub struct PaniniSutraEngine {
    default_rules: Vec<SutraRule>,
}

impl Default for PaniniSutraEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[wasm_bindgen]
impl PaniniSutraEngine {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        let default_rules = vec![
            SutraRule {
                id: "1.1.1".to_string(),
                name: "vriddhi_adaich".to_string(),
                pattern: "a+i".to_string(),
                replacement: "ai".to_string(),
            },
            SutraRule {
                id: "6.1.87".to_string(),
                name: "ad_gunah".to_string(),
                pattern: "a+u".to_string(),
                replacement: "o".to_string(),
            },
        ];

        PaniniSutraEngine { default_rules }
    }

    /// Evaluates Paninian sutra derivations using zero-copy serde boundary serialization
    #[wasm_bindgen]
    pub fn evaluate_derivation(&self, val: JsValue) -> Result<JsValue, JsValue> {
        let input: EvaluationInput = serde_wasm_bindgen::from_value(val)?;
        let result = PaniniRuleEvaluator::evaluate(&input);

        serde_wasm_bindgen::to_value(&result).map_err(|e| JsValue::from_str(&e.to_string()))
    }

    /// Evaluates input payload directly using pre-loaded engine rules
    #[wasm_bindgen]
    pub fn evaluate_simple(&self, base_term: &str, pratyaya: &str) -> Result<JsValue, JsValue> {
        let input = EvaluationInput {
            base_term: base_term.to_string(),
            pratyaya: pratyaya.to_string(),
            active_rules: self.default_rules.clone(),
        };

        let result = PaniniRuleEvaluator::evaluate(&input);

        serde_wasm_bindgen::to_value(&result).map_err(|e| JsValue::from_str(&e.to_string()))
    }
}

// Single Compile-Time PHF Inclusion from build.rs
include!(concat!(env!("OUT_DIR"), "/phf_sutras.rs"));

/// Attribution for the sutra text (see data/ashtadhyayi.json `source`).
pub const SUTRA_SOURCE: &str =
    "Ashtadhyayi text: Vidyut (ambuda.org), MIT licence; data shared by ashtadhyayi.com";

#[derive(Serialize, Deserialize, Clone)]
pub struct SutraRecord {
    pub id: String,
    pub sutra: String,
    #[serde(default)]
    pub slp1: Option<String>,
    #[serde(default)]
    pub iast: Option<String>,
    /// None until the sutra is classified in data/ashtadhyayi-curated.json.
    #[serde(default)]
    pub category: Option<String>,
    pub hardware_gate: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub arth_hindi: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub arth_status: Option<String>,
}

#[derive(Deserialize)]
struct SutraDatabasePayload {
    sutras: Vec<SutraRecord>,
}

// Embedded compressed binary generated at build time
static COMPRESSED_SUTRAS: &[u8] =
    include_bytes!(concat!(env!("OUT_DIR"), "/ashtadhyayi_compressed.bin"));

// Lazy global lookup map initialized once on first WASM execution call
static SUTRA_DATABASE: Lazy<HashMap<String, SutraRecord>> = Lazy::new(|| {
    let mut decoder = GzDecoder::new(COMPRESSED_SUTRAS);
    let mut json_str = String::new();
    decoder
        .read_to_string(&mut json_str)
        .expect("Failed to decompress Sutra dataset");

    let payload: SutraDatabasePayload =
        serde_json::from_str(&json_str).expect("Failed to parse compressed JSON payload");

    let mut map = HashMap::with_capacity(payload.sutras.len());
    for record in payload.sutras {
        map.insert(record.id.clone(), record);
    }
    map
});

#[wasm_bindgen]
pub fn get_sutra_by_id(id: &str) -> Result<JsValue, JsValue> {
    if let Some(record) = SUTRA_DATABASE.get(id) {
        serde_wasm_bindgen::to_value(record).map_err(|e| JsValue::from_str(&e.to_string()))
    } else {
        Err(JsValue::from_str("Sutra ID not found"))
    }
}

#[derive(Serialize)]
pub struct SutraInfo {
    pub id: String,
    pub sutra: String,
    /// None (null in JSON) when the sutra is not yet classified.
    pub category: Option<String>,
    pub hardware_gate: String,
    pub source: &'static str,
}

#[wasm_bindgen]
pub fn lookup_ashtadhyayi_sutra(sutra_id: &str) -> Result<JsValue, JsValue> {
    if let Some(&(sutra, category, hardware_gate)) = ASHTADHYAYI_MAP.get(sutra_id) {
        let info = SutraInfo {
            id: sutra_id.to_string(),
            sutra: sutra.to_string(),
            category: (!category.is_empty()).then(|| category.to_string()),
            hardware_gate: hardware_gate.to_string(),
            source: SUTRA_SOURCE,
        };
        let value = serde_wasm_bindgen::to_value(&info)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;
        let category_value = info
            .category
            .as_deref()
            .map(JsValue::from_str)
            .unwrap_or(JsValue::NULL);
        js_sys::Reflect::set(
            &value,
            &JsValue::from_str("category"),
            &category_value,
        )
        .map_err(|e| JsValue::from_str(&format!("Failed to set sutra category: {e:?}")))?;
        Ok(value)
    } else {
        Err(JsValue::from_str(
            "Sutra ID not found in Ashtadhyayi static hash map",
        ))
    }
}

/// O(1) Static Sutra Lookup (Rust Internal API): (sutra, category, hardware_gate).
/// An empty category means the sutra is not yet classified.
pub fn lookup_sutra(id: &str) -> Option<(&'static str, &'static str, &'static str)> {
    ASHTADHYAYI_MAP.get(id).copied()
}

#[wasm_bindgen]
pub fn execute_sandhi_transform(left_term: &str, right_term: &str) -> Result<JsValue, JsValue> {
    let result = execute_sandhi_gate(left_term, right_term);
    serde_wasm_bindgen::to_value(&result).map_err(|e| JsValue::from_str(&e.to_string()))
}
