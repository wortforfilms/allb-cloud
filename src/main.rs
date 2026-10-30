use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use maataa_runtime::brahmi_tokenizer::BrahmiScriptTokenizer;
use maataa_runtime::maataa_hal::SovereignHardwareAccelerator;
use maataa_runtime::z0_vesp_protocol::{VespPayload, Z0VespProtocolEngine};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("=================================================");
    println!("   MAATAA SOVEREIGN AI RUNTIME NODE (STAGE 4)   ");
    println!("=================================================");

    // 1. Pipeline Setup
    let embedding_dim = 128;
    let tokenizer = BrahmiScriptTokenizer::new(embedding_dim);
    let accelerator = Arc::new(SovereignHardwareAccelerator::new()?);
    let signing_key = signing_key_from_env()?;
    let vesp_protocol = Z0VespProtocolEngine::new(&signing_key);

    // 2. Tokenize & Execute NPU Vector
    let tokens = tokenizer.tokenize("𑀮𑀺𑀧𑀺");
    let input_vector = tokenizer.tokens_to_embedding(&tokens);
    let (output_vector, _metrics) = accelerator.process_vector(&input_vector)?;

    // 3. Panini Sutra Check
    let current_time = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();
    let alignment_score = cosine_similarity(&input_vector, &output_vector);

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
    let target_url = std::env::var("MAATAA_EDGE_URL").map_err(|_| {
        std::io::Error::other(
            "MAATAA_EDGE_URL must be set explicitly; production is never the default",
        )
    })?;

    println!(
        "[STAGE 5] Transmitting Packet to Explicit Edge Worker ({})",
        target_url
    );

    let client = reqwest::Client::new();
    let res = client.post(&target_url).json(&envelope).send().await?;

    let status = res.status();
    let body: serde_json::Value = res.json().await?;

    println!("=================================================");
    println!("EDGE GATEWAY RESPONSE (Status {}):", status);
    println!("{}", serde_json::to_string_pretty(&body)?);
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
