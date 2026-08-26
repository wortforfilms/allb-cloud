use std::time::{SystemTime, UNIX_EPOCH};
use maataa_runtime::brahmi_tokenizer::BrahmiScriptTokenizer;
use maataa_runtime::maataa_hal::SovereignHardwareAccelerator;
use maataa_runtime::panini_engine::{PaniniEngineConfig, PaniniSutraEngine};
use maataa_runtime::z0_vesp_protocol::{VespPayload, Z0VespProtocolEngine};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("=================================================");
    println!("  Z0-VESP EDGE ANTI-REPLAY PRODUCTION TEST       ");
    println!("  Target: https://brahmi.allb.xyz                ");
    println!("=================================================");

    // 1. Initialize Pipeline & Hardware Driver
    let embedding_dim = 128;
    let tokenizer = BrahmiScriptTokenizer::new(embedding_dim);
    let accelerator = SovereignHardwareAccelerator::new()?;
    let sutra_engine = PaniniSutraEngine::new(PaniniEngineConfig::default());
    let vesp_protocol = Z0VespProtocolEngine::new(&[42u8; 32]);

    // 2. Tokenize & NPU Vector Processing
    let tokens = tokenizer.tokenize("𑀮𑀺𑀧𑀺");
    let input_vector = tokenizer.tokens_to_embedding(&tokens);
    let (output_vector, _) = accelerator.process_vector(&input_vector)?;

    // 3. Panini Sutra Rule Engine Validation
    let current_time = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();
    let alignment_score = sutra_engine.validate_vector(&input_vector, &output_vector, current_time, current_time)?;

    // 4. Construct Envelope
    let payload = VespPayload {
        script_type: "BRAHMI".to_string(),
        aksharas: tokens,
        vector_dim: embedding_dim,
        alignment_score,
        timestamp: current_time,
    };
    let envelope = vesp_protocol.create_envelope(payload)?;
    
    println!("[TEST PAYLOAD]");
    println!("  • Nonce ID : {}", envelope.nonce);
    println!("  • JCS Hash : {}", envelope.canonical_hash);
    println!("-------------------------------------------------");

    let client = reqwest::Client::new();
    let target_url = "https://brahmi.allb.xyz";

    // --- TRANSMISSION 1: Initial Post ---
    println!("\n[TRANSMISSION 1] Sending fresh envelope to edge...");
    let res1 = client.post(target_url).json(&envelope).send().await?;
    let status1 = res1.status();
    let body1: serde_json::Value = res1.json().await?;

    println!("Response 1: Status {}", status1);
    println!("{}", serde_json::to_string_pretty(&body1)?);

    // --- TRANSMISSION 2: Replay Post (Same Envelope) ---
    println!("\n[TRANSMISSION 2] Re-sending EXACT same envelope (Replay Attack Simulation)...");
    let res2 = client.post(target_url).json(&envelope).send().await?;
    let status2 = res2.status();
    let body2: serde_json::Value = res2.json().await?;

    println!("Response 2: Status {}", status2);
    println!("{}", serde_json::to_string_pretty(&body2)?);

    println!("\n=================================================");
    if status1.is_success() && status2.as_u16() == 403 {
        println!("VERIFICATION RESULT: SUCCESS (KV Anti-Replay Engine Verified)");
    } else {
        println!("VERIFICATION RESULT: UNEXPECTED RESPONSE PATTERN");
    }
    println!("=================================================");

    Ok(())
}