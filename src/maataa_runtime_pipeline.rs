//! Maataa Sovereign AI Runtime Kernel
//! Binds the Brahmi/Siddham Tokenizer Engine, INT8 Dynamic Quantizer,
//! and Siddham Hardware Abstraction Layer (HAL) into a zero-copy execution pipeline.

use std::sync::Arc;

use crate::maataa_hal::{ExecutionMetrics, HalStatus, SovereignHardwareAccelerator};

/// The tokenizer lives in `crate::brahmi_tokenizer` (ADR 0002).
pub use crate::brahmi_tokenizer::BrahmiScriptTokenizer;

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
        let (raw_hw_output, metrics) = self.accelerator.process_vector(&hw_input_vector)?;

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
        let pipeline =
            MaataaRuntimePipeline::new(256).expect("Failed to initialize Maataa Runtime Pipeline");

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
        println!(
            "Transformed Output:   [{}, {}, {}, ...]",
            res.transformed_embedding[0],
            res.transformed_embedding[1],
            res.transformed_embedding[2]
        );
        println!("=================================================");
    }
}
