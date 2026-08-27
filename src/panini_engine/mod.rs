pub mod evaluator;
pub mod phoneme_codec;
pub mod sandhi_matrix;

// Export from evaluator.rs
pub use evaluator::{execute_sandhi_gate, PaniniEngineConfig, PaniniEvaluator, SandhiGateResult};

// Export from sandhi_matrix.rs
pub use sandhi_matrix::{execute_sandhi_gate_fast, DerivationTrace, SandhiResult};