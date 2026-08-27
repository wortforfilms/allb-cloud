//! Maataa Sovereign AI Runtime Kernel
//! Binds the Brahmi/Siddham Tokenizer Engine, INT8 Dynamic Quantizer, 
//! and Siddham Hardware Abstraction Layer (HAL) into a zero-copy execution pipeline.

use std::collections::HashMap;
use std::sync::Arc;

use crate::maataa_hal::{ExecutionMetrics, HalStatus, SovereignHardwareAccelerator};

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
                } 
                else {
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
            let token_id = *self.vocab.get(token).unwrap_or_else(|| {
                self.vocab.get("[UNK]").unwrap_or(&0)
            });
            
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
}

/// Unified Sovereign Runtime Pipeline
pub struct MaataaRuntimePipeline {
    tokenizer: BrahmiScriptTokenizer,
    accelerator: Arc<SovereignHardwareAccelerator>,
    embedding_dim: usize,
}

#[derive(Debug)]
pub struct PipelineExecutionResult {
    pub input_tokens: Vec<String>,
    pub quantized_input: Vec<i8>,
    pub transformed_embedding: Vec<f32>,
    pub quant_scale: f32,
    pub metrics: ExecutionMetrics,
}

impl MaataaRuntimePipeline {
    pub fn new(embedding_dim: usize) -> Result<Self, HalStatus> {
        let tokenizer = BrahmiScriptTokenizer::new(embedding_dim);
        let accelerator = Arc::new(SovereignHardwareAccelerator::new()?);

        Ok(Self {
            tokenizer,
            accelerator,
            embedding_dim,
        })
    }

    /// End-to-End Sovereign Execution Loop: 
    /// Script Text -> Akshara Tokenize -> L2 Embedding -> Dynamic INT8 Quant -> NPU Accelerator Dispatch
    pub fn process_script_text(&self, text: &str) -> Result<PipelineExecutionResult, HalStatus> {
        // Step 1: Tokenize Brahmi/Siddham text into Aksharas
        let tokens = self.tokenizer.tokenize(text);

        // Step 2: Convert tokens to L2-normalized dense float vector
        let f32_embedding = self.tokenizer.tokens_to_embedding(&tokens);

        // Step 3: Dynamically quantize float embedding to INT8 array for 16x16 NPU DMA payload
        let (quantized_input, quant_scale) = 
            BrahmiScriptTokenizer::quantize_f32_to_i8(&f32_embedding, self.embedding_dim);

        // Convert i8 payload to f32 slice for HAL dispatch interface compatibility
        let hw_input_vector: Vec<f32> = quantized_input.iter().map(|&x| x as f32).collect();

        // Step 4: Dispatch payload through HAL to physical Siddham Edge NPU
        let (raw_hw_output, metrics) = self
            .accelerator
            .process_vector(&hw_input_vector)?;

        // Step 5: Convert and dequantize hardware response back to float embedding space
        let hw_i8_output: Vec<i8> = raw_hw_output
            .iter()
            .map(|&x| x.clamp(-128.0, 127.0).round() as i8)
            .collect();
            
        let transformed_embedding = 
            BrahmiScriptTokenizer::dequantize_i8_to_f32(&hw_i8_output, quant_scale);

        Ok(PipelineExecutionResult {
            input_tokens: tokens,
            quantized_input,
            transformed_embedding,
            quant_scale,
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
        // Initialize pipeline with 256-dimensional embedding space (matches 16x16 PE matrix width)
        let pipeline = MaataaRuntimePipeline::new(256)
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
        println!("Quantization Scale:   {:.4}", res.quant_scale);
        println!("INT8 Input Vector:    {:?}", &res.quantized_input[0..4]);
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