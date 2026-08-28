#!/usr/bin/env bash
set -euo pipefail

echo "==> Compiling WebAssembly module for Edge Worker (Bundler Target)..."
wasm-pack build --target web --out-dir pkg --release

if command -v wasm-opt >/dev/null 2>&1; then
  echo "==> Running Binaryen wasm-opt (-Oz)..."
  wasm-opt -Oz \
    --enable-bulk-memory \
    --enable-mutable-globals \
    pkg/maataa_runtime_bg.wasm \
    -o pkg/maataa_runtime_bg.wasm
else
  echo "==> [WARN] wasm-opt not found in PATH. Skipping secondary optimization."
  echo "==> Run 'brew install binaryen' to enable maximum WASM compression."
fi

echo "==> Production WebAssembly Payload Size:"
ls -lh pkg/maataa_runtime_bg.wasm
