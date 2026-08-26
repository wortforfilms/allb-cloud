use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use maataa_runtime::brahmi_tokenizer::BrahmiScriptTokenizer;
use maataa_runtime::maataa_hal::SovereignHardwareAccelerator;
use maataa_runtime::panini_engine::{PaniniEngineConfig, PaniniSutraEngine};
use maataa_runtime::z0_vesp_protocol::{VespPayload, Z0VespProtocolEngine};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("=================================================");
    println!("  MAATAA SOVEREIGN AI RUNTIME KERNEL (STAGE 4)  ");
    println!("=================================================");

    // 1. Pipeline Setup
    let embedding_dim = 128;
    let tokenizer = BrahmiScriptTokenizer::new(embedding_dim);
    let accelerator = Arc::new(SovereignHardwareAccelerator::new()?);
    let sutra_engine = PaniniSutraEngine::new(PaniniEngineConfig::default());
    let vesp_protocol = Z0VespProtocolEngine::new(&[42u8; 32]);

    // 2. Tokenize & Execute NPU Vector
    let tokens = tokenizer.tokenize("𑀮𑀺𑀧𑀺");
    let input_vector = tokenizer.tokens_to_embedding(&tokens);
    let (output_vector, metrics) = accelerator.process_vector(&input_vector)?;

    // 3. Panini Sutra Check
    let current_time = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();
    let alignment_score = sutra_engine.validate_vector(&input_vector, &output_vector, current_time, current_time)?;

    // 4. Create VESP Signed Envelope
    let payload = VespPayload {
        script_type: "BRAHMI".to_string(),
        aksharas: tokens,
        vector_dim: embedding_dim,
        alignment_score,
        timestamp: current_time,
    };
    let envelope = vesp_protocol.create_envelope(payload)?;

    // 5. Send to Local Cloudflare Wrangler Worker Gateway
    // println!("[STAGE 5] Transmitting  Packet to Local Edge Worker (http://127.0.0.1:8787)...");
    // let client = reqwest::Client::new();
    // let res = client
    //     .post("http://127.0.0.1:8787")
    //     .json(&envelope)
    //     .send()
    //     .await?;
    // Replace localhost with your live Cloudflare Workers deployment URL
let target_url = "https://brahmi.allb.xyz";

println!("[STAGE 5] Transmitting Packet to Production Edge Worker ({})", target_url);

let client = reqwest::Client::new();
let res = client
    .post(target_url)
    .json(&envelope)
    .send()
    .await?;

    let status = res.status();
    let body: serde_json::Value = res.json().await?;

    println!("=================================================");
    println!("EDGE GATEWAY RESPONSE (Status {}):", status);
    println!("{}", serde_json::to_string_pretty(&body)?);
    println!("=================================================");

    Ok(())
}