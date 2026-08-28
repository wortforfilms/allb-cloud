# MAATAA and Siddham ecosystem

The production programme and evidence-gated phase status are maintained in
[`PRODUCT_ROADMAP.md`](PRODUCT_ROADMAP.md).

## Product model

MAATAA is the sovereign execution platform. Siddham is its semiconductor
product family: the Siddham NPU supplies hardware acceleration and Siddham
Authority Desktop supplies governed user access and evidence.

```text
Siddham Authority Desktop
        | typed, authorized operation
        v
MAATAA Rust or WebAssembly runtime
        | capability-selected execution
        v
Siddham NPU or declared software fallback
        | result and execution evidence
        v
Local evidence ledger and signed Edge synchronization
```

The first local vertical slice is connected end to end for Brahmi
tokenization, Paninian Sandhi, and Sutra lookup. Other protected actions,
remote execution, and physical NPU execution remain outside that slice.

## Authority map

| Path | Classification | Authority |
| --- | --- | --- |
| `src/` | Runtime | Canonical Rust and WASM implementation |
| `data/` | Runtime data | Canonical Sutra dataset |
| `hardware/rtl/` | Hardware | Canonical Siddham NPU RTL |
| `hardware/tb/` | Hardware verification | Canonical testbenches |
| `c_src/` | Native bridge | Canonical Siddham NPU HAL implementation |
| `services/edge_worker/` | Edge service | Canonical Worker API |
| `sdk/` and `python/` | Clients | Supported TypeScript and Python surfaces |
| `apps/siddham-authority-desktop/` | Product application | Canonical authority desktop implementation |
| `crates/siddham-contracts/` | Shared contract | Canonical Rust contract types |
| `contracts/` | Contract fixtures | Generator specification, schemas, and compatibility fixtures |
| `generated/` | Generated bindings | TypeScript and Python projections; never edit by hand |
| `apps/siddham-landing/` | Product surface | Canonical evidence-grounded technical landing page |
| `demos/siddham-edge/` | Controlled demonstration | Static fixture-backed UI only |
| `references/siddham/ui-pack/` | Design reference | Concept imagery and marketing reconstruction |
| `references/siddham/landing-pages.html` | Design archive | Monolithic collection of 138 concepts |
| `vendor/nextpnr/` | Upstream dependency | Pinned upstream source, not local product authority |

## Truth boundaries

- `demos/` contains deterministic fixtures, not measured runtime state.
- `references/` contains concept material, not implementation or evidence.
- A WASM or Worker build proves construction only.
- A staging deployment proves staging availability only.
- Software fallback must never be represented as Siddham NPU execution.
- Authority decisions must originate in trusted Rust code.
- A runtime operation must have a recorded permit before execution begins.
- Unimplemented protected actions remain typed but fail closed.
- Signed transmission does not by itself prove remote acknowledgment.

## Build order

1. Generate the cross-runtime contract bindings and reject drift.
2. Validate and test the native Rust runtime.
3. Build the WASM package before Worker or SDK tests that consume it.
4. Run TypeScript and Worker checks.
5. Run Siddham NPU RTL simulations.
6. Install, type-check, and test Siddham Authority Desktop.
7. Build release artifacts only after all relevant gates pass.

## Completion status matrix

| Deliverable | Owner | Completion state | Evidence and boundary |
| --- | --- | --- | --- |
| Shared contract package | `crates/siddham-contracts/` | Complete | Canonical Rust schema 1.0.0 types and fixture tests |
| TypeScript binding | `generated/typescript/` | Complete | Deterministically generated; drift checked |
| Worker binding | `services/edge_worker/src/generated/` | Complete | Worker health surface exposes the contract version |
| Desktop binding | `apps/siddham-authority-desktop/src/generated/` | Complete | UI request/result types project from the shared contract |
| Python binding | `generated/python/` | Complete | Compatibility fixture tests pass |
| Cross-contract fixtures and schema | `contracts/` | Complete | Valid and fail-closed invalid fixtures plus generated JSON Schema |
| Runtime capabilities | `src/runtime_contract.rs` | Complete locally | Brahmi, Sandhi and Sutra are available in software-native mode; physical NPU is unavailable |
| Typed execution results | `src/runtime_contract.rs` | Complete locally | Includes request identity, mode, status, input/output digests, output and duration |
| Desktop-to-MAATAA execution | `commands.rs` → `runtime_contract.rs` | Complete locally | Three real typed runtime operations are connected |
| Authority-before-execution enforcement | `policy.rs` and `commands.rs` | Complete locally | Only `Permit` reaches a handler; denied actions produce no execution |
| Linked authorization and execution evidence | `evidence.rs` and migration `004` | Complete locally | Immutable linked records, outboxes, rollback checks and tamper detection |
| Remaining protected-action pattern | Shared catalog and policy | Complete as fail-closed coverage | Dataset, model, agent, policy, hardware, release and export handlers remain unavailable |
| WASM consumer build order | Root scripts and CI | Complete | WASM rebuilt before 16 TypeScript consumer tests; generated package is not retained |
| Desktop verification | Desktop UI and Rust workspace | Complete | UI type-check/build and 10 Rust tests pass |
| CI layout and contract drift gates | `.github/workflows/ci.yml` | Complete | Root verification plus Linux, macOS and Windows desktop matrix |
| Generated dump cleanup | Repository workspace | Complete | Build, dependency, Wrangler and Python cache directories removed |
| Edge deployment | Environment-specific | Not certified | Worker implementation exists; no deployment or availability claim |
| Physical Siddham silicon | External certification boundary | Not certified | RTL presence is not physical silicon evidence |
| Production combined product | Release Authority | No-go | Identity assurance, approval workflow, key protection and production certification remain open |

## Repository rules

- Do not commit `target/`, `node_modules/`, `pkg/`, Wrangler state, simulation
  dumps, or other generated build directories.
- Keep the root workspace Rust lockfile committed; workspace members share it.
- Put deployable applications under `apps/`, controlled examples under
  `demos/`, and non-runtime source material under `references/`.
- Update this authority map whenever ownership or paths change.
