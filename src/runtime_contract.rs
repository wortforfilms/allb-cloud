use crate::{execute_sandhi_gate, lookup_sutra, tokenize_brahmi_script};
use serde_json::json;
use sha2::{Digest, Sha256};
use siddham_contracts::{
    ExecutionMode, ExecutionResult, ExecutionStatus, RuntimeCapability, RuntimeOperation,
    SCHEMA_VERSION,
};
use std::time::Instant;

pub fn runtime_capabilities() -> Vec<RuntimeCapability> {
    vec![
        RuntimeCapability {
            id: "brahmi:tokenize".into(),
            available: true,
            mode: ExecutionMode::SoftwareNative,
            detail: "Native Rust tokenizer".into(),
        },
        RuntimeCapability {
            id: "panini:sandhi".into(),
            available: true,
            mode: ExecutionMode::SoftwareNative,
            detail: "Bounded Paninian Sandhi evaluator".into(),
        },
        RuntimeCapability {
            id: "sutra:lookup".into(),
            available: true,
            mode: ExecutionMode::SoftwareNative,
            detail: "Compile-time Ashtadhyayi lookup".into(),
        },
        RuntimeCapability {
            id: "siddham:npu".into(),
            available: false,
            mode: ExecutionMode::SiddhamNpu,
            detail: "Physical NPU capability is not detected by this contract surface".into(),
        },
    ]
}

pub fn execute_contract_operation(
    request_id: &str,
    operation_id: &str,
    operation: &RuntimeOperation,
) -> Result<ExecutionResult, String> {
    let started = Instant::now();
    let input = serde_json::to_vec(operation).map_err(|error| error.to_string())?;
    let input_digest = digest(&input);
    let output = match operation {
        RuntimeOperation::TokenizeBrahmi { text } => {
            json!({ "tokens": tokenize_brahmi_script(text) })
        }
        RuntimeOperation::EvaluateSandhi { left, right } => {
            serde_json::to_value(execute_sandhi_gate(left, right))
                .map_err(|error| error.to_string())?
        }
        RuntimeOperation::LookupSutra { sutra_id } => {
            let (sutra, category, hardware_gate) =
                lookup_sutra(sutra_id).ok_or_else(|| format!("Sutra {sutra_id} not found"))?;
            json!({
                "id": sutra_id,
                "sutra": sutra,
                "category": (!category.is_empty()).then_some(category),
                "hardwareGate": hardware_gate,
                "source": crate::SUTRA_SOURCE,
            })
        }
    };
    let output_bytes = serde_json::to_vec(&output).map_err(|error| error.to_string())?;
    Ok(ExecutionResult {
        schema_version: SCHEMA_VERSION.into(),
        operation_id: operation_id.into(),
        request_id: request_id.into(),
        runtime_version: env!("CARGO_PKG_VERSION").into(),
        execution_mode: ExecutionMode::SoftwareNative,
        status: ExecutionStatus::Succeeded,
        input_digest,
        output_digest: digest(&output_bytes),
        output,
        duration_micros: started.elapsed().as_micros().try_into().unwrap_or(u64::MAX),
    })
}

fn digest(bytes: &[u8]) -> String {
    hex::encode(Sha256::digest(bytes))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn reports_truthful_capabilities() {
        let capabilities = runtime_capabilities();
        assert!(capabilities
            .iter()
            .any(|item| item.id == "brahmi:tokenize" && item.available));
        assert!(capabilities
            .iter()
            .any(|item| item.id == "siddham:npu" && !item.available));
    }
    #[test]
    fn executes_typed_tokenization() {
        let result = execute_contract_operation(
            "REQ-1",
            "OP-1",
            &RuntimeOperation::TokenizeBrahmi {
                text: "𑀅𑀆A".into()
            },
        )
        .unwrap();
        assert_eq!(result.status, ExecutionStatus::Succeeded);
        assert_eq!(result.output["tokens"].as_array().unwrap().len(), 2);
        assert_ne!(result.input_digest, result.output_digest);
    }
    #[test]
    fn looks_up_real_sutras_with_attribution() {
        let result = execute_contract_operation(
            "REQ-2",
            "OP-2",
            &RuntimeOperation::LookupSutra {
                sutra_id: "6.1.77".into(),
            },
        )
        .unwrap();
        assert_eq!(result.output["sutra"], "इको यणचि");
        assert_eq!(result.output["category"], "विधि (Vidhi)");
        assert!(result.output["source"].as_str().unwrap().contains("MIT"));
        let unclassified = execute_contract_operation(
            "REQ-3",
            "OP-3",
            &RuntimeOperation::LookupSutra {
                sutra_id: "8.4.68".into(),
            },
        )
        .unwrap();
        assert_eq!(unclassified.output["sutra"], "अ अ");
        assert!(unclassified.output["category"].is_null());
        // The first pada has 75 sutras; the old placeholder data answered 1.1.101.
        assert!(execute_contract_operation(
            "REQ-4",
            "OP-4",
            &RuntimeOperation::LookupSutra {
                sutra_id: "1.1.101".into(),
            },
        )
        .is_err());
    }
    #[test]
    fn every_sutra_the_sandhi_engine_cites_exists() {
        for id in ["1.1.1", "6.1.77", "6.1.87", "6.1.101", "8.4.40"] {
            assert!(lookup_sutra(id).is_some(), "{id}");
        }
        assert_eq!(lookup_sutra("6.1.87").unwrap().0, "आद्गुणः");
        assert_eq!(lookup_sutra("6.1.101").unwrap().0, "अकः सवर्णे दीर्घः");
        assert_eq!(lookup_sutra("8.4.40").unwrap().0, "स्तोः श्चुना श्चुः");
    }
}
