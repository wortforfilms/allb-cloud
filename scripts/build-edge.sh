#!/usr/bin/env bash
set -euo pipefail

echo "==> Compiling WebAssembly module for Edge Worker (Bundler Target)..."
if command -v rustup >/dev/null 2>&1; then
  RUST_TOOLCHAIN_BIN="$(dirname "$(rustup which rustc --toolchain 1.91.0)")"
  PATH="${RUST_TOOLCHAIN_BIN}:${PATH}" wasm-pack build --target web --out-dir pkg --release
else
  wasm-pack build --target web --out-dir pkg --release
fi

if command -v wasm-opt >/dev/null 2>&1; then
  echo "==> Running Binaryen wasm-opt (-Oz)..."
  wasm-opt -Oz \
    --enable-bulk-memory \
    --enable-sign-ext \
    --enable-mutable-globals \
    pkg/maataa_runtime_bg.wasm \
    -o pkg/maataa_runtime_bg.wasm
else
  echo "==> [WARN] wasm-opt not found in PATH. Skipping secondary optimization."
  echo "==> Run 'brew install binaryen' to enable maximum WASM compression."
fi

echo "==> Production WebAssembly Payload Size:"
ls -lh pkg/maataa_runtime_bg.wasm
