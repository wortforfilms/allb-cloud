//! Z0-VESP Ingress Protocol Layer
//! Implements RFC 8785 JCS Canonicalization and Ed25519 Signing.

use ed25519_dalek::{Signer, SigningKey};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct VespPayload {
    pub script_type: String,
    pub aksharas: Vec<String>,
    pub vector_dim: usize,
    pub alignment_score: f32,
    pub timestamp: u64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct VespEnvelope {
    pub canonical_hash: String,
    pub nonce: String,
    pub signature: String,
    pub payload: VespPayload,
}

pub struct Z0VespProtocolEngine {
    signing_key: SigningKey,
}

impl Z0VespProtocolEngine {
    pub fn new(secret_bytes: &[u8; 32]) -> Self {
        let signing_key = SigningKey::from_bytes(secret_bytes);
        Self { signing_key }
    }

    /// RFC 8785 JCS Canonicalization (Deterministic JSON Encoding)
    pub fn canonicalize(&self, payload: &VespPayload) -> Result<String, serde_json::Error> {
        let json_value = serde_json::to_value(payload)?;
        Self::sort_json_value(&json_value)
    }

    fn sort_json_value(value: &Value) -> Result<String, serde_json::Error> {
        match value {
            Value::Object(map) => {
                let mut sorted_keys: Vec<_> = map.keys().collect();
                sorted_keys.sort();

                let mut entries = Vec::new();
                for key in sorted_keys {
                    let val_str = Self::sort_json_value(&map[key])?;
                    entries.push(format!("\"{}\":{}", key, val_str));
                }
                Ok(format!("{{{}}}", entries.join(",")))
            }
            Value::Array(arr) => {
                let mut items = Vec::new();
                for item in arr {
                    items.push(Self::sort_json_value(item)?);
                }
                Ok(format!("[{}]", items.join(",")))
            }
            other => serde_json::to_string(other),
        }
    }

    /// Constructs and signs the complete VESP packet envelope
    pub fn create_envelope(
        &self,
        payload: VespPayload,
    ) -> Result<VespEnvelope, Box<dyn std::error::Error>> {
        let canonical_json = self.canonicalize(&payload)?;

        // SHA-256 Digest of canonical payload
        let mut hasher = Sha256::new();
        hasher.update(canonical_json.as_bytes());
        let hash_result = hasher.finalize();
        let canonical_hash = hex::encode(hash_result);

        // Generate unique cryptographic nonce
        let nonce = format!(
            "Z0-NONCE-{}-{}",
            payload.timestamp,
            hex::encode(&hash_result[..4])
        );

        // Signature over Canonical Hash + Nonce
        let sign_target = format!("{}:{}", canonical_hash, nonce);
        let signature = self.signing_key.sign(sign_target.as_bytes());

        Ok(VespEnvelope {
            canonical_hash,
            nonce,
            signature: hex::encode(signature.to_bytes()),
            payload,
        })
    }
}
