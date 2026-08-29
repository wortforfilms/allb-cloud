# Toolchain baseline

Recorded 2026-08-29 on macOS arm64.

| Tool | Baseline | Enforcement |
| --- | --- | --- |
| Rust | 1.91.0 | `rust-toolchain.toml` |
| Cargo | 1.91.0 | Rust toolchain |
| Rust target | `wasm32-unknown-unknown` | Rust toolchain |
| Node.js | 24 | `.nvmrc` and CI |
| npm | Lockfile-compatible npm 11+ | `package-lock.json` |
| pnpm | 11.24.0 observed; not canonical | No pnpm workspace is used |
| Python | 3.12.1 observed | CI pins Python 3.12 |
| wasm-pack | 0.13.1 | CI installs the exact locked helper version |
| cargo-audit | 0.22.2 | CI installs the exact locked helper version |
| Binaryen/wasm-opt | Homebrew installation observed | CI installs Binaryen |
| Icarus Verilog | 13.0 stable | RTL simulation prerequisite |
| Yosys | 0.68+post | Synthesis/lint prerequisite |
| CMake | 4.4.3 observed | Native HAL prerequisite |

The checked-in Rust and Node declarations are the reproducible baseline. CI
pins versioned language tools and installs platform packages by supported
runner image; the current apt package revisions are runner-image inputs and
are recorded by hosted job logs rather than misrepresented as lockfile pins.
