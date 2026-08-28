# MAATAA × Siddham complete product roadmap

Status date: 2026-08-29

The proposed commercial offers and their evidence-to-sale gates are maintained
in [`COMMERCIAL_CATALOGUE.md`](COMMERCIAL_CATALOGUE.md).

## Product destination

The target is a governed, evidence-producing sovereign computing platform
combining the Siddham desktop and web workspace, MAATAA Rust and WASM
execution, Paninian/Brahmi/Lipi engines, backend-owned Authority, identity and
approvals, independently verifiable evidence, signed synchronization, Edge
APIs, FPGA/NPU acceleration, SDKs, enterprise administration, commercial
licensing, and supported deployment.

The repository currently proves a local governed runtime slice. It does not
yet prove the full product described above.

## Programme baseline

| Parameter | Planning baseline |
| --- | --- |
| Delivery horizon | 15–18 months |
| Controlled pilot | Month 4 |
| Enterprise beta | Month 8 |
| Production software target | Month 12 |
| FPGA evaluation target | Month 14 |
| Production-qualified hardware/IP | Month 18+ |
| Core team | 16–22 people |
| Extended team | 25–32 people |
| Software production budget | Approximately ₹4.5–7 crore |
| Hardware qualification budget | Additional ₹2–5 crore |
| ASIC tape-out | Separate programme and budget |

Dates and budgets are planning assumptions, not commitments.

## Current phase status

The detailed work-package, milestone and production-gate matrix is maintained
in [`ROADMAP_STATUS_MATRIX.md`](ROADMAP_STATUS_MATRIX.md).

| Phase | Scope | Current evidence status | Next gate |
| --- | --- | --- | --- |
| 0 | Authoritative baseline | Complete locally | Canonical ADR, inventory, policies, scans, coherent commits and `baseline-2026-08-29` tag |
| 1 | Reproducible build and CI | Partial | Clean-clone matrix, pinned toolchains, disk guard, audits, SBOM, checksummed artifacts and release manifest |
| 2 | Canonical contracts | Partial foundation complete | Expand from operation/runtime types to all domains, validators, invalid-rule fixtures, compatibility and migration policy |
| 3 | Identity, workspace and tenancy | Not started | Verified principals, devices, sessions, assurance and tenant isolation |
| 4 | Production Authority | Partial foundation complete | Handler registry, policy lifecycle, bypass/replay protection and every protected-action integration test |
| 5 | Approvals and delegation | Not started | Durable approval lifecycle, eligible approvers, separation of duties and delegation controls |
| 6 | Governed execution | Partial local slice complete | Deadlines, cancellation, limits, idempotency, target selection and additional real handlers |
| 7 | Evidence and Z0-VESP sync | Partial local ledger | Signatures, key rotation, acknowledgement, retry, export packages and offline verifier |
| 8 | Complete product UX | Prototype/local surface | Operational modules, truthful states, accessibility and complete E2E journeys |
| 9 | Edge and enterprise administration | Prototype Worker only | Tenant-aware API, operational environments, recovery, quotas, SSO/SCIM and administration |
| 10 | SDK and DevKit | Partial clients | Published signed SDKs, CLI, verifier, simulator, docs and compatibility policy |
| 11 | FPGA qualification | RTL present; unqualified | Verification depth, board implementation, equivalence, timing, measurements and signed programming |
| 12 | Security and privacy | Not certified | Threat model, key protection, hardening, security testing, recovery and privacy controls |
| 13 | Commercial platform | Not started | Entitlements, licensing, metering, billing, legal documents and claim-safe SKUs |
| 14 | Release engineering | Not started | Signed installers/packages, migration, rollback, runbooks and human release approval |
| 15 | Pilots and launch | Not started | Controlled pilots, acceptance evidence, operational review and GA decision |

## Completed local foundation

- Canonical Rust governed-operation contract package.
- Generated TypeScript, Worker, desktop, Python and JSON Schema projections.
- Deterministic drift detection and cross-contract fixtures.
- Typed runtime capabilities and execution results.
- Authority-gated local Brahmi tokenization, Sandhi evaluation and Sutra
  lookup.
- Linked authorization and execution evidence with rollback and tamper tests.
- Typed fail-closed coverage for protected actions without real handlers.
- Root and desktop CI layout aligned with the consolidated repository.

This foundation is an integration milestone, not completion of Phases 0–7.

## Phase exit gates

### Phase 0 — authoritative baseline

A clean, committed worktree; coherent history; canonical repository decision;
reproducible baseline tag; toolchain inventory; secret, licence and large-file
scans; architecture decision; staging record; risk register; and archived
external Siddham source.

### Phase 1 — reproducible build and CI

A clean checkout reproduces checksummed artifacts on supported runners. CI
includes hygiene, schemas, drift, Rust, WASM, TypeScript, Worker, desktop,
Python, RTL, dependency/licence audit, SBOM, packaging, low-disk behavior and a
release manifest without undeclared dependencies.

### Phase 2 — canonical domain platform

Rust is authoritative for identity, workspace, resources, operations,
authorization, approvals, execution, capabilities, health, evidence, sync,
errors and release manifests. Every runtime accepts the same valid fixtures,
rejects the same invalid fixtures and rejects unknown major versions.

### Phases 3–5 — identity, Authority and approvals

Every operation carries a verified principal, device and workspace. Assurance
comes from authentication evidence. Tenant isolation is tested. Every handler
is immediately authorized, replay-resistant and unable to self-authorize.
High-risk operations enforce durable maker-checker approvals.

### Phases 6–7 — execution and evidence

The handler registry validates inputs and outputs, limits resources, supports
timeouts/cancellation/idempotency and truthfully reports software, WASM or NPU
targets. The complete evidence chain is signed, independently verifiable and
tracks queued, sent, acknowledged and rejected synchronization states.

### Phases 8–10 — product, Edge and developer ecosystem

Every visible control works or is explicitly unavailable; no fixture is shown
as operational evidence; accessibility and journeys pass. Edge is tenant-safe,
observable and recoverable. External developers can install signed SDKs and
build a governed operation without repository access.

### Phases 11–15 — hardware, security, commercial and release

Software/WASM/RTL/FPGA reference vectors agree; board timing and measurements
are reproducible; hardware programming is governed. No critical/high security
finding remains. SKUs map to tested entitlements. Signed releases pass install,
upgrade, rollback and recovery. Named authorities approve pilots and GA.

## Immediate 30-day execution plan

### Week 1 — establish the baseline

- Review and classify the dirty worktree.
- Split the ecosystem, contracts, Authority, runtime, evidence, UI, CI and
  documentation changes into coherent commits.
- Confirm `allb.xyz` as canonical; define branch policy and tag the baseline.
- Record the repository/toolchain inventory, architecture decision, staging
  snapshot, risk register and known limitations.
- Fix repository metadata and licence warnings.

### Week 2 — prove clean reproducibility

- Run the complete CI matrix from an empty clone.
- Add preflight disk-capacity checks to heavy Rust, WASM, Tauri and FPGA jobs.
- Add secret, licence, dependency and large-file checks.
- Generate an SBOM, artifact checksums and immutable validation reports.
- Test low-disk failure behavior explicitly.

### Week 3 — deepen contracts and enforcement

- Add all missing Phase 2 domains and canonical validators.
- Create invalid fixtures for each validation rule plus golden/property tests.
- Publish versioning, compatibility, deprecation and evidence-migration rules.
- Add the governed operation-handler registry and bypass/replay tests.
- Specify implementable identity-assurance mechanisms.

### Week 4 — add the first non-runtime governed workflows

- Implement dataset export through Authority.
- Implement evidence export v1 and offline verification instructions.
- Add pending, approved, rejected and expired approval states.
- Demonstrate authorization → approval where required → execution → linked
  evidence.
- Define and evidence-gate the controlled pilot package; do not describe it as
  production.

## Critical production gates

The product remains `NO-GO` until all of the following are evidenced:

- Clean committed revision and clean-checkout CI.
- Real identity assurance rather than selected labels.
- Every protected action implemented or explicitly unavailable.
- Complete approval lifecycle and non-bypassable authorization.
- Independently verifiable evidence and signed acknowledged synchronization.
- Truthful desktop state without operational fixture metrics.
- Passing backup, restore, migration, upgrade and rollback exercises.
- No unresolved critical/high security finding.
- Signed packages and installers.
- Legal licences aligned with commercial entitlements.
- Separately certified software and hardware claims.
- Board-generated evidence for physical NPU claims.
- Recorded human release approval.

## Milestone targets

| Milestone | Target | Product state |
| --- | --- | --- |
| M0 | Week 1 | Local engineering baseline |
| M1 | Week 4 | Controlled development |
| M2 | Week 6 | Integration foundation |
| M3 | Week 13 | Security prototype |
| M4 | Week 18 | Controlled product alpha |
| M5 | Week 20 | Verifiable alpha |
| M6 | Week 24 | Enterprise beta |
| M7 | Week 28 | Design-partner release |
| M8 | Week 34 | Production candidate |
| M9 | Week 36+ | Hardware evaluation release |
| M10 | Week 42 | Software production release |
| M11 | Week 52 | General-availability decision |

The release sequence is software-controlled pilot, enterprise beta,
production software, and finally FPGA-qualified products. ASIC
commercialization remains a separate post-FPGA programme.
