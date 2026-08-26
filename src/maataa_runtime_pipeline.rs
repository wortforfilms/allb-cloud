//! Maataa Sovereign AI Runtime Kernel
//! Binds the Brahmi/Siddham Tokenizer Engine directly with the C++/Rust HAL Driver.

use std::collections::HashMap;
use std::sync::Arc;

// Import the Rust HAL Driver created in the previous step
use crate::maataa_hal::{ExecutionMetrics, HalStatus, SovereignHardwareAccelerator};

/// Tokenizer engine for ancient scripts (Brahmi / Siddham)
pub struct BrahmiScriptTokenizer {
    vocab: HashMap<String, usize>,
    inv_vocab: HashMap<usize, String>,
    embedding_dim: usize,
}

impl BrahmiScriptTokenizer {
    pub fn new(embedding_dim: usize) -> Self {
        let mut vocab = HashMap::new();
        let mut inv_vocab = HashMap::new();

        // Build base vocabulary for Brahmi Unicode block (U+11000 - U+1107F)
        let mut idx = 0;
        for cp in 0x11000..=0x1107F {
            if let Some(ch) = std::char::from_u32(cp) {
                let s = ch.to_string();
                vocab.insert(s.clone(), idx);
                inv_vocab.insert(idx, s);
                idx += 1;
            }
        }

        // Special tokens
        vocab.insert("[PAD]".to_string(), idx);
        vocab.insert("[UNK]".to_string(), idx + 1);

        Self {
            vocab,
            inv_vocab,
            embedding_dim,
        }
    }

    /// Segments Brahmi / Siddham Unicode text into grapheme clusters (Aksharas)
    pub fn tokenize(&self, text: &str) -> Vec<String> {
        let mut tokens = Vec::new();
        let mut cluster = String::new();

        for ch in text.chars() {
            let cp = ch as u32;
            if (0x11000..=0x1107F).contains(&cp) {
                // Consonants and independent vowels start new clusters
                if (0x11013..=0x11038).contains(&cp) || (0x11005..=0x11012).contains(&cp) {
                    if !cluster.is_empty() {
                        tokens.push(cluster.clone());
                    }
                    cluster = ch.to_string();
                } else if (0x11038..=0x11047).contains(&cp) {
                    // Dependent vowel signs / Virama append to current cluster
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

    /// Converts token strings to dense vector representations for NPU processing
    pub fn tokens_to_embedding(&self, tokens: &[String]) -> Vec<f32> {
        let mut embedding = vec![0.0f32; self.embedding_dim];
        
        for (i, token) in tokens.iter().enumerate() {
            let token_id = *self.vocab.get(token).unwrap_or(
                self.vocab.get("[UNK]").unwrap_or(&0)
            );
            
            // Normalize ID value into embedding space
            let slot = i % self.embedding_dim;
            embedding[slot] += (token_id as f32) / 256.0f32;
        }

        embedding
    }
}

/// Unified Sovereign Runtime Pipeline
pub struct MaataaRuntimePipeline {
    tokenizer: BrahmiScriptTokenizer,
    accelerator: Arc<SovereignHardwareAccelerator>,
}

#[derive(Debug)]
pub struct PipelineExecutionResult {
    pub input_tokens: Vec<String>,
    pub transformed_embedding: Vec<f32>,
    pub metrics: ExecutionMetrics,
}

impl MaataaRuntimePipeline {
    pub fn new(embedding_dim: usize) -> Result<Self, &'static str> {
        let tokenizer = BrahmiScriptTokenizer::new(embedding_dim);
        let accelerator = Arc::new(SovereignHardwareAccelerator::new()?);

        Ok(Self {
            tokenizer,
            accelerator,
        })
    }

    /// End-to-End Execution Loop: Text -> Tokenize -> Vectorize -> NPU Dispatch
    pub fn process_script_text(&self, text: &str) -> Result<PipelineExecutionResult, HalStatus> {
        // Step 1: Tokenize Brahmi/Siddham text into Aksharas
        let tokens = self.tokenizer.tokenize(text);

        // Step 2: Convert tokens to dense float vector input
        let input_embedding = self.tokenizer.tokens_to_embedding(&tokens);

        // Step 3: Dispatch directly through Rust HAL to physical Siddham Edge NPU
        let (transformed_embedding, metrics) = self
            .accelerator
            .process_vector(&input_embedding)?;

        Ok(PipelineExecutionResult {
            input_tokens: tokens,
            transformed_embedding,
            metrics,
        })
    }
}

// -----------------------------------------------------------------------------
// Integration Test Suite
// -----------------------------------------------------------------------------
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_full_script_pipeline_execution() {
        // Initialize pipeline with 128-dimensional embedding space
        let pipeline = MaataaRuntimePipeline::new(128)
            .expect("Failed to initialize Maataa Runtime Pipeline");

        // Brahmi Text Input: "𑀮𑀺𑀧𑀺" (Lipi)
        let sample_text = "𑀮𑀺𑀧𑀺";

        let result = pipeline.process_script_text(sample_text);
        assert!(result.is_ok(), "Pipeline execution failed");

        let res = result.unwrap();
        println!("=================================================");
        println!("MAATAA RUNTIME HARDWARE EXECUTION COMPLETE");
        println!("=================================================");
        println!("Input Script:         {}", sample_text);
        println!("Extracted Aksharas:   {:?}", res.input_tokens);
        println!("NPU Latency:          {:.3} ms", res.metrics.latency_ms);
        println!("Execution Cycles:     {}", res.metrics.execution_cycles);
        println!("Transformed Output:   [{}, {}, {}, ...]", 
            res.transformed_embedding[0], 
            res.transformed_embedding[1], 
            res.transformed_embedding[2]
        );
        println!("=================================================");
    }
}