# MAATAA Sovereign Runtime (`maataa_sovereign_runtime`)

[![CI/CD Pipeline](https://github.com/vesahe/allb.xyz/actions/workflows/deploy.yml/badge.svg)](https://github.com/vesahe/allb.xyz/actions)
[![Edge Deployment](https://img.shields.io/badge/Cloudflare_Workers-Deployed-F38020?logo=cloudflare)](https://brahmi.allb.xyz)
[![WASM Engine](https://img.shields.io/badge/Rust-WebAssembly-000000?logo=rust)](https://rustwasm.github.io/wasm-pack/)

High-performance computational engine and rule evaluation runtime built in Rust and WebAssembly (WASM). Designed for zero-allocation Brahmi script tokenization, $O(1)$ compile-time Paninian Ashtadhyayi sutra resolution, and low-latency edge deployment via Cloudflare Workers.

---

## 🏛 Architecture & Key Features

* **$O(1)$ Ashtadhyayi Sutra Engine:** Built using `phf_codegen` to compile static Paninian rule lookups directly into read-only binary memory (`.rodata`), eliminating JSON parse overhead at runtime.
* **Zero-Copy Brahmi Tokenizer:** Directly maps WebAssembly linear memory (`Uint32Array`) to Javascript runtimes, bypassing standard FFI allocation overhead (**4.75x performance gain** over native JS).
* **Paninian Derivation Pipeline:** Real-time step-by-step Sandhi transformation and rule tracking executing in sub-15 microsecond windows.
* **Hardened Edge Runtime:** Deployed to Cloudflare Workers with domain-locked dynamic CORS origin validation and IP-based rate limiting.

---

## 🚀 Edge API Usage (`https://brahmi.allb.xyz`)

### 1. Paninian Rule Evaluation (`evaluate`)
```bash
curl -X POST [https://brahmi.allb.xyz](https://brahmi.allb.xyz) \
  -H "Content-Type: application/json" \
  -d '{"action": "evaluate", "base_term": "nara", "pratyaya": "+indra"}'
