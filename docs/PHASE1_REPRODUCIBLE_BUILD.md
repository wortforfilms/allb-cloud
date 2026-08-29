# Phase 1 reproducible build and CI

Evidence date: 2026-08-29

## Canonical interface

| Intent | Command |
| --- | --- |
| Install locked dependencies | `npm run install:all` |
| Remove reproducible outputs | `npm run clean` |
| Validate the full source tree | `npm run verify` |
| Build WASM and native consumers | `npm run build` |
| Package release evidence | `npm run artifacts:package` |

`make all`, `make verify`, `make package`, and `make clean` are convenience
aliases. Consumer tests never rely on a stale WASM payload: `make test` and CI
both build WASM first.

## Reproducibility boundary

Node 24 and Rust 1.91.0 are repository-pinned. CI additionally pins Python
3.12, wasm-pack 0.13.1 and cargo-audit 0.22.2, installs Binaryen, Icarus
Verilog and Yosys, and uses both npm and Cargo lockfiles. The build has no
undeclared production secret or network dependency after locked dependencies
and security databases are installed.

The Linux stack job covers hygiene, structured-file/schema validation,
generated-contract drift, licence metadata, npm and Rust advisory audits,
Rust formatting/lint/tests, WASM, TypeScript, Worker routes, Python fixtures,
RTL simulations, desktop frontend, Worker dry-run and release packaging. A
separate Linux/macOS/Windows matrix checks the Tauri desktop application.

## Release artifact contract

`npm run artifacts:package` refuses a dirty worktree unless the caller sets
`ALLOW_DIRTY=1` for non-release diagnostics. It emits ignored output under
`artifacts/`:

- `package/` — WASM, desktop web assets and generated contract projections;
- `sbom.cdx.json` — deterministic CycloneDX 1.6 dependency inventory;
- `release-manifest.json` — source revision/date, contract version and file
  digests, with `productionCertified: false`;
- `SHA256SUMS` — package, manifest and SBOM checksums, re-read and verified by
  the packaging command.

These files are build evidence, not source and not a production certification.

## Resource and failure behavior

The build fails before expensive compilation when fewer than 6 GiB are free.
Vitest proves both the normal and forced-low-disk paths. `npm run clean`
removes only enumerated reproducible outputs, including Rust targets, WASM,
desktop dependencies/builds, simulations, caches and packaged artifacts.

## Hosted completion evidence

GitHub Actions run
[`33237684396`](https://github.com/thelinep/allb/actions/runs/33237684396)
passed the full Linux verification stack and the Ubuntu, macOS and Windows
Tauri desktop matrix from commit `cc72a64a79cf0581f169bebbe47af6cd011cabaf`.
The run also produced the checksummed Phase 1 artifact bundle.

Staging deployment remains manual, environment-gated and explicitly outside
Phase 1 certification. Release manifests continue to state
`productionCertified: false`.
