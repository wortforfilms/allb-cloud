use maataa_runtime::brahmi_tokenizer::BrahmiScriptTokenizer;
use maataa_runtime::maataa_hal::SovereignHardwareAccelerator;
use maataa_runtime::z0_vesp_protocol::{VespPayload, Z0VespProtocolEngine};
use std::time::{SystemTime, UNIX_EPOCH};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("=================================================");
    println!("  Z0-VESP EDGE ANTI-REPLAY PRODUCTION TEST       ");
    println!("  Target: explicit MAATAA_EDGE_URL               ");
    println!("=================================================");

    // 1. Initialize Pipeline & Hardware Driver
    let embedding_dim = 128;
    let tokenizer = BrahmiScriptTokenizer::new(embedding_dim);
    let accelerator = SovereignHardwareAccelerator::new()?;
    let signing_key = signing_key_from_env()?;
    let vesp_protocol = Z0VespProtocolEngine::new(&signing_key);

    // 2. Tokenize & NPU Vector Processing
    let tokens = tokenizer.tokenize("𑀮𑀺𑀧𑀺");
    let input_vector = tokenizer.tokens_to_embedding(&tokens);
    let (output_vector, _) = accelerator.process_vector(&input_vector)?;

    // 3. Panini Sutra Rule Engine Validation
    let current_time = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();
    let alignment_score = cosine_similarity(&input_vector, &output_vector);

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
    let target_url = std::env::var("MAATAA_EDGE_URL").map_err(|_| {
        std::io::Error::other(
            "MAATAA_EDGE_URL must be set explicitly; production is never the default",
        )
    })?;

    // --- TRANSMISSION 1: Initial Post ---
    println!("\n[TRANSMISSION 1] Sending fresh envelope to edge...");
    let res1 = client.post(&target_url).json(&envelope).send().await?;
    let status1 = res1.status();
    let body1: serde_json::Value = res1.json().await?;

    println!("Response 1: Status {}", status1);
    println!("{}", serde_json::to_string_pretty(&body1)?);

    // --- TRANSMISSION 2: Replay Post (Same Envelope) ---
    println!("\n[TRANSMISSION 2] Re-sending EXACT same envelope (Replay Attack Simulation)...");
    let res2 = client.post(&target_url).json(&envelope).send().await?;
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

fn cosine_similarity(left: &[f32], right: &[f32]) -> f32 {
    let (dot, left_norm, right_norm) = left.iter().zip(right).fold(
        (0.0_f32, 0.0_f32, 0.0_f32),
        |(dot, left_norm, right_norm), (&a, &b)| {
            (dot + a * b, left_norm + a * a, right_norm + b * b)
        },
    );
    if left_norm == 0.0 || right_norm == 0.0 {
        0.0
    } else {
        dot / (left_norm.sqrt() * right_norm.sqrt())
    }
}

fn signing_key_from_env() -> Result<[u8; 32], Box<dyn std::error::Error>> {
    let encoded = std::env::var("MAATAA_SIGNING_KEY_HEX").map_err(|_| {
        std::io::Error::other("MAATAA_SIGNING_KEY_HEX must contain an explicit 32-byte hex key")
    })?;
    let decoded = hex::decode(encoded)
        .map_err(|_| std::io::Error::other("MAATAA_SIGNING_KEY_HEX is not valid hex"))?;
    decoded.try_into().map_err(|_| {
        std::io::Error::other("MAATAA_SIGNING_KEY_HEX must decode to exactly 32 bytes").into()
    })
}
