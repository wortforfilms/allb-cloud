# MAATAA Sovereign Runtime

[![CI Pipeline](https://github.com/vesahe/allb.xyz/actions/workflows/ci.yml/badge.svg)](https://github.com/vesahe/allb.xyz/actions/workflows/ci.yml)

MAATAA is a Rust and WebAssembly runtime for Brahmi tokenization, bounded
Paninian Sandhi evaluation, and compile-time Ashtadhyayi Sutra lookup. The
repository also contains a Cloudflare Worker API, TypeScript and Python SDK
surfaces, Siddham NPU RTL with simulation testbenches, the governed Siddham
desktop application, controlled UI demonstrations, and visual references.

The complete layout and trust boundaries are documented in
[`docs/ECOSYSTEM.md`](docs/ECOSYSTEM.md). The shared operation data contract
and its fail-closed handler boundary are documented in
[`docs/CONTRACTS.md`](docs/CONTRACTS.md). The full programme, current phase
status, exit gates and immediate 30-day sequence are maintained in
[`docs/PRODUCT_ROADMAP.md`](docs/PRODUCT_ROADMAP.md). Proposed SKUs, quote-now
limits and evidence-to-sale gates are maintained in
[`docs/COMMERCIAL_CATALOGUE.md`](docs/COMMERCIAL_CATALOGUE.md). The complete
phase, milestone and production-gate status is tracked in
[`docs/ROADMAP_STATUS_MATRIX.md`](docs/ROADMAP_STATUS_MATRIX.md).

The authoritative baseline decision, inventory, toolchain record, branch
policy and initial risk register are maintained under `docs/`.

## Authority map

- `src/`: canonical Rust runtime and native binaries.
- `data/ashtadhyayi.json`: canonical Sutra dataset consumed by `build.rs`.
- `pkg/`: generated and ignored WASM package. Rebuild it; do not commit it.
- `services/edge_worker/src/index.ts`: canonical Worker entrypoint.
- `wrangler.jsonc`: Worker, staging, production-route, and observability config.
- `hardware/rtl/` and `hardware/tb/`: canonical RTL and testbenches.
- `sdk/`: client surfaces and examples.
- `apps/siddham-authority-desktop/`: canonical governed desktop application.
- `crates/siddham-contracts/`: canonical governed-operation Rust types.
- `contracts/`: binding specification, schema, and compatibility fixtures.
- `generated/`: generated TypeScript and Python contract projections.
- `apps/siddham-landing/`: canonical evidence-grounded technical landing surface.
- `demos/siddham-edge/`: controlled static UI demonstration with fixture data.
- `references/siddham/`: non-runtime design and marketing source material.
- `vendor/nextpnr`: pinned upstream submodule, not copied source.

Only runtime, service, SDK, hardware, and application directories are product
implementation. Content under `demos/` and `references/` is not operational
evidence and must not support deployment or production claims.

## Verified locally

```bash
cargo test --release
npm run contracts:check
npm run contracts:python-check
npm test
npx tsc --noEmit
make sim sim-top rtl-check
npm run build:wasm
npm run edge:dry-run
npm run desktop:install
npm run desktop:verify
```

The test suite covers native pipeline execution, WASM initialization, Brahmi
token agreement, Sutra lookup, supported transliteration-based Sandhi rules,
the focused AXI DMA regression, and the integrated DMA + NPU core regression.

Benchmark output is diagnostic and machine-specific. It is not a product
performance guarantee.

## Worker API

No production URL is assumed by clients or native binaries. Pass the deployed
staging or production base URL explicitly.

```bash
EDGE_BASE_URL="https://example-staging.workers.dev"

curl "$EDGE_BASE_URL/health"

curl -X POST "$EDGE_BASE_URL/api/z0/sandhi" \
  -H "Content-Type: application/json" \
  -d '{"left":"nara","right":"indra"}'

curl "$EDGE_BASE_URL/api/z0/sutra/1.1.1"

curl -X POST "$EDGE_BASE_URL/api/z0/tokenize-brahmi" \
  -H "Content-Type: application/json" \
  -d '{"text":"𑀅𑀆𑀇𑀈"}'
```

Native outbound binaries are fail-closed. Set `MAATAA_EDGE_URL` and a secret
32-byte `MAATAA_SIGNING_KEY_HEX` explicitly before running `maataa_kernel` or
`replay_test`. Never pass the signing key as a command argument or commit it.

## Deployment boundary

The GitHub workflow verifies every push and pull request. Staging deployment is
manual and approval-bound through the `deploy_staging` workflow input. The
repository does not automatically deploy production.

A successful Wrangler dry-run proves bundle construction only. A successful
staging deployment plus live endpoint checks proves staging availability only;
neither is evidence of production readiness.

The 2026-08-28 isolated staging snapshot and its exact evidence are recorded in
[`docs/STAGING_CERTIFICATION.md`](docs/STAGING_CERTIFICATION.md).
