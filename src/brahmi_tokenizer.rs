//! Canonical Brahmi tokenizer.
//!
//! This module is the single home of Brahmi akshara segmentation for the
//! MAATAA ecosystem (ADR 0002). The runtime pipeline, the native binaries and
//! the Python SDK all follow it; `tests/fixtures/brahmi_aksharas.json` is the
//! shared contract they are tested against.
//!
//! The WASM exports `tokenize_brahmi_script` / `tokenize_brahmi_zerocopy` in
//! `lib.rs` are code-point filters, not akshara segmentation.

use std::collections::HashMap;

/// Tokenizer and Vectorizer Engine for ancient scripts (Brahmi / Siddham)
pub struct BrahmiScriptTokenizer {
    vocab: HashMap<String, usize>,
    embedding_dim: usize,
}

impl BrahmiScriptTokenizer {
    pub fn new(embedding_dim: usize) -> Self {
        let mut vocab = HashMap::new();
        // let mut inv_vocab = HashMap::new();

        // Build base vocabulary for Brahmi Unicode block (U+11000 - U+1107F)
        let mut idx = 0;
        for cp in 0x11000..=0x1107F {
            if let Some(ch) = std::char::from_u32(cp) {
                let s = ch.to_string();
                vocab.insert(s.clone(), idx);
                // inv_vocab.insert(idx, s);
                idx += 1;
            }
        }

        // Special tokens
        vocab.insert("[PAD]".to_string(), idx);
        vocab.insert("[UNK]".to_string(), idx + 1);

        Self {
            vocab,
            // inv_vocab,
            embedding_dim,
        }
    }

    /// Segments Brahmi / Siddham Unicode text into grapheme clusters (Aksharas)
    /// Fixed boundary checks to cleanly separate LA (0x11038) and combining signs.
    pub fn tokenize(&self, text: &str) -> Vec<String> {
        let mut tokens = Vec::new();
        let mut cluster = String::new();

        for ch in text.chars() {
            let cp = ch as u32;
            if (0x11000..=0x1107F).contains(&cp) {
                // Independent Vowels & Consonants (New Akshara Cluster Start)
                if (0x11005..=0x11037).contains(&cp) {
                    if !cluster.is_empty() {
                        tokens.push(cluster.clone());
                    }
                    cluster = ch.to_string();
                }
                // Dependent Vowel Signs, Anusvara, Visarga & Virama (Append to Cluster)
                else if (0x11038..=0x11046).contains(&cp) || (0x11000..=0x11002).contains(&cp) {
                    cluster.push(ch);
                } else {
                    if !cluster.is_empty() {
                        tokens.push(cluster.clone());
                        cluster.clear();
                    }
                    tokens.push(ch.to_string());
                }
            } else {
                if !cluster.is_empty() {
                    tokens.push(cluster.clone());
                    cluster.clear();
                }
                tokens.push(ch.to_string());
            }
        }

        if !cluster.is_empty() {
            tokens.push(cluster);
        }

        tokens
    }

    /// Converts token strings to dense vector representations with L2 normalization
    pub fn tokens_to_embedding(&self, tokens: &[String]) -> Vec<f32> {
        let mut embedding = vec![0.0f32; self.embedding_dim];

        for (i, token) in tokens.iter().enumerate() {
            let token_id = *self
                .vocab
                .get(token)
                .unwrap_or_else(|| self.vocab.get("[UNK]").unwrap_or(&0));

            let slot = i % self.embedding_dim;
            embedding[slot] += (token_id as f32) / 256.0f32;
        }

        // Apply L2 normalization to prevent multi-segment wrapping saturation
        let norm: f32 = embedding.iter().map(|x| x * x).sum::<f32>().sqrt();
        if norm > 0.0 {
            for val in embedding.iter_mut() {
                *val /= norm;
            }
        }

        embedding
    }

    /// Dynamic symmetric INT8 Quantizer for NPU Systolic Array compatibility
    pub fn quantize_f32_to_i8(vec: &[f32], target_dim: usize) -> (Vec<i8>, f32) {
        let mut padded = vec![0.0f32; target_dim];
        let len = vec.len().min(target_dim);
        padded[..len].copy_from_slice(&vec[..len]);

        let max_abs = padded.iter().fold(0.0f32, |acc, &x| acc.max(x.abs()));
        let scale = if max_abs > 0.0 { 127.0 / max_abs } else { 1.0 };

        let quantized: Vec<i8> = padded
            .iter()
            .map(|&x| (x * scale).clamp(-128.0, 127.0).round() as i8)
            .collect();

        (quantized, scale)
    }

    /// Dequantizes hardware NPU vector back to floating-point representation
    pub fn dequantize_i8_to_f32(vec: &[i8], scale: f32) -> Vec<f32> {
        let inv_scale = if scale > 0.0 { 1.0 / scale } else { 1.0 };
        vec.iter().map(|&x| (x as f32) * inv_scale).collect()
    }

    pub fn is_ancient_sovereign_script(c: char) -> bool {
        matches!(c,
            '\u{11000}'..='\u{1107F}' | // Brahmi (11000–1107F)
            '\u{10A00}'..='\u{10A5F}' | // Kharosthi (10A00–10A5F)
            '\u{11580}'..='\u{115FF}'   // Siddham (11580–115FF)
        )
    }
}

#[cfg(test)]
mod tests {
    use super::BrahmiScriptTokenizer;

    const FIXTURE: &str = include_str!("../tests/fixtures/brahmi_aksharas.json");

    #[test]
    fn matches_shared_akshara_fixture() {
        let fixture: serde_json::Value = serde_json::from_str(FIXTURE).expect("fixture is JSON");
        let tokenizer = BrahmiScriptTokenizer::new(128);
        for case in fixture["cases"].as_array().expect("cases array") {
            let input = case["input"].as_str().expect("input");
            let expected: Vec<String> = case["aksharas"]
                .as_array()
                .expect("aksharas")
                .iter()
                .map(|t| t.as_str().expect("token").to_string())
                .collect();
            assert_eq!(tokenizer.tokenize(input), expected, "case {}", case["name"]);
        }
    }

    #[test]
    fn embedding_is_l2_normalised() {
        let tokenizer = BrahmiScriptTokenizer::new(16);
        let tokens = tokenizer.tokenize("\u{11013}\u{11038}\u{11027}");
        let embedding = tokenizer.tokens_to_embedding(&tokens);
        let norm: f32 = embedding.iter().map(|x| x * x).sum::<f32>().sqrt();
        assert!((norm - 1.0).abs() < 1e-5);
    }
}
