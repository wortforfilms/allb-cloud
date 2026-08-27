//! Maataa Sovereign Runtime Edge Daemon (maataad)
//! Manages local Unix Domain Socket IPC calls and schedules NPU processing tasks.

use tokio::net::{UnixListener, UnixStream};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use std::sync::Arc;
use std::path::Path;
use serde::{Deserialize, Serialize};

use maataa_sovereign_runtime::maataa_runtime_pipeline::MaataaRuntimePipeline;

#[derive(Serialize, Deserialize, Debug)]
pub struct IpcRequest {
    pub command: String, // "eval_sandhi" | "tokenize" | "npu_vector"
    pub payload_left: String,
    pub payload_right: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct IpcResponse {
    pub status: String,
    pub result: String,
    pub latency_ms: f32,
}

pub struct SovereignDaemon {
    pipeline: Arc<MaataaRuntimePipeline>,
    socket_path: String,
}

impl SovereignDaemon {
    pub fn new(socket_path: &str, embedding_dim: usize) -> Result<Self, &'static str> {
        let pipeline = Arc::new(
            MaataaRuntimePipeline::new(embedding_dim)
                .map_err(|_| "Failed to initialize hardware pipeline in daemon")?
        );

        Ok(Self {
            pipeline,
            socket_path: socket_path.to_string(),
        })
    }

    pub async fn run(&self) -> Result<(), Box<dyn std::error::Error>> {
        if Path::new(&self.socket_path).exists() {
            tokio::fs::remove_file(&self.socket_path).await?;
        }

        let listener = UnixListener::bind(&self.socket_path)?;
        println!("[MAATAAD] Sovereign Edge Daemon listening on {}", self.socket_path);

        loop {
            let (stream, _) = listener.accept().await?;
            let pipeline = Arc::clone(&self.pipeline);

            tokio::spawn(async move {
                if let Err(e) = Self::handle_client(stream, pipeline).await {
                    eprintln!("[MAATAAD_ERR] IPC handling error: {}", e);
                }
            });
        }
    }

    async fn handle_client(
        mut stream: UnixStream, 
        pipeline: Arc<MaataaRuntimePipeline>
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut buffer = vec![0u8; 4096];
        let n = stream.read(&mut buffer).await?;
        if n == 0 { return Ok(()); }

        let req: IpcRequest = serde_json::from_slice(&buffer[..n])?;
        let start = std::time::Instant::now();

        let response = match req.command.as_str() {
            "eval_sandhi" => {
                let text_input = format!("{}{}", req.payload_left, req.payload_right);
                match pipeline.process_script_text(&text_input) {
                    Ok(res) => IpcResponse {
                        status: "OK".to_string(),
                        result: format!("{:?}", res.input_tokens),
                        latency_ms: start.elapsed().as_secs_f32() * 1000.0,
                    },
                    Err(_) => IpcResponse {
                        status: "ERROR".to_string(),
                        result: "NPU Execution Failed".to_string(),
                        latency_ms: 0.0,
                    },
                }
            }
            _ => IpcResponse {
                status: "UNSUPPORTED".to_string(),
                result: "Unknown Command".to_string(),
                latency_ms: 0.0,
            },
        };

        let resp_bytes = serde_json::to_vec(&response)?;
        stream.write_all(&resp_bytes).await?;
        Ok(())
    }
}