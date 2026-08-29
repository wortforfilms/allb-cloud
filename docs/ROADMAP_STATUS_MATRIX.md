# MAATAA × Siddham roadmap status matrix

Evidence date: 2026-08-29

## Status vocabulary

| State | Meaning |
| --- | --- |
| Complete hosted | Implemented and reproduced by the explicitly linked hosted CI evidence |
| Complete local | Implemented and verified for the explicitly named local scope |
| Partial | Some real implementation exists, but the phase exit gate is open |
| Present, unqualified | Source or design exists without required operational/certification evidence |
| Planned | No complete production-capable implementation is evidenced |
| Blocked by dependency | Work must not be represented as available until an earlier gate passes |
| No-go | Release or commercial claim is prohibited |

No percentage is assigned: phase scope is not uniform, and a percentage would
imply precision not supported by the repository evidence.

## Programme phase matrix

| Phase | Work package | State | Evidence now | Open exit-gate work | Priority/dependency |
| --- | --- | --- | --- | --- | --- |
| 0 | Canonical repository | Complete local | ADR 0001 establishes `allb.xyz` and its authority map | Revisit only through a superseding ADR | Closed |
| 0 | Source classification | Complete local | Inventory classifies source, generated, demo, reference, vendor and disposable content | Maintain inventory as layout changes | Closed |
| 0 | Coherent baseline history | Complete local | Intended changes split into coherent commits with branch policy and annotated tag | Hosted review/push remains external | Closed |
| 0 | Toolchain record | Complete local | Rust/Node pins and observed Python/WASM/FPGA tools recorded | Pin auxiliary tools during Phase 1 | Closed |
| 0 | Repository assurance | Complete local | Hygiene, secret-pattern, licence metadata, vulnerability and large-file scans recorded | Automate deeper supply-chain reports in Phase 1 | Closed |
| 0 | Operational baseline | Complete local | ADR, validation report, risk register and staging record preserved; absent external path documented | Review risks at every milestone | Closed |
| 1 | Root build commands | Complete local | Canonical install/clean/build/test/verify/package scripts and Make aliases | Preserve compatibility as modules are added | Closed locally |
| 1 | Deterministic generation | Complete local | Contract generator and drift check | Expand to all Phase 2 domains | P1 |
| 1 | Native/WASM/TypeScript/Python tests | Complete local | Canonical sequence rebuilds WASM before 20 TypeScript/Worker tests plus Rust and Python suites | Preserve clean-checkout evidence | Closed locally |
| 1 | Desktop matrix | Complete hosted | Linux/macOS/Windows Tauri checks passed in hosted run `33237684396` | Preserve the matrix as desktop dependencies evolve | Closed |
| 1 | RTL verification gates | Complete hosted | DMA and integrated top simulations plus compile gate passed on hosted Linux | Preserve regressions and expand hardware qualification in Phase 11 | Closed for Phase 1 |
| 1 | Supply-chain output | Complete hosted | Hosted lockfile audits, licence scan, CycloneDX SBOM, verified checksums, release manifest and retained artifact | Define longer-term retention/signing in later release phases | Closed for Phase 1 |
| 1 | Resource preflight | Complete local | 6 GiB preflight plus positive and forced-low-disk tests | Tune threshold only with measured evidence | Closed locally |
| 2 | Operation/runtime contract | Complete local | Canonical Rust types and schema 1.0.0 | Compatibility/deprecation policy | P1 |
| 2 | Generated language projections | Complete local | TypeScript, Worker, desktop, Python and JSON Schema | Runtime validators beyond static models | P1 |
| 2 | Contract fixtures | Partial | Valid request and unknown-action invalid fixture | Invalid fixture for every rule and golden/property tests | P1 |
| 2 | Identity/workspace/resource domains | Planned | Basic request strings only | Full authoritative models and validators | Depends on Phase 1 |
| 2 | Approval/sync/error/release domains | Planned | Some evidence/sync types exist outside unified platform | Canonical models, migration and compatibility reports | Depends on Phase 1 |
| 2 | Version behavior | Partial | Exact schema version required | SemVer policy, compatible minors and unknown-major rejection tests | P1 |
| 3 | Principal and device identity | Planned | UI-selected principal labels only | Enrollment, credentials, device keys, recovery and revocation | P0 after Phase 2 |
| 3 | Sessions and assurance | Planned | Assurance enum exists | Server/backend-derived AAL mechanisms, expiry and step-up | P0 |
| 3 | Organization/workspace tenancy | Planned | Workspace label exists | Membership, isolation, scoped keys, export and deletion | P0 |
| 3 | Enterprise federation | Planned | None evidenced | OIDC/SAML and lifecycle integration | After local identity |
| 4 | Policy decision foundation | Partial | Trusted Rust evaluation, default deny and policy digest | Formal condition model and deny-overrides | P1 |
| 4 | Runtime enforcement | Complete local | Permit precedes three local runtime handlers | Expiry, replay and one-operation-ID guarantee | P0 |
| 4 | Policy lifecycle | Planned | Static policy version | Create, simulate, activate, retire, provenance and retention | Depends on Phase 3 |
| 4 | Protected-action coverage | Partial | Catalog is typed; unavailable actions fail closed | Real handlers and positive/negative integration tests | P0–P2 by risk |
| 4 | Separation of duties | Planned | No approval engine | Independent policy/release authorization | Depends on Phase 5 |
| 5 | Approval lifecycle | Planned | Decision effects name approval/step-up | Durable pending, approved, rejected, expired and cancelled states | P0 |
| 5 | Approval integrity | Planned | No reusable approval artifact | Exact request binding, expiry, revocation and anti-reuse | P0 |
| 5 | Maker-checker/quorum | Planned | None evidenced | Eligible approvers, sequencing and quorum | After identity |
| 5 | Delegation/emergency access | Planned | Action names only | Scoped delegation, expiry, revocation and review | After identity |
| 5 | Approval UX | Planned | None operational | Inbox, history, comments, evidence and notifications | After backend |
| 6 | Three local language operations | Complete local | Tokenize Brahmi, evaluate Sandhi and lookup Sutra | Production corpus and semantic coverage programme | P1 |
| 6 | Capability/result reporting | Complete local | Software-native mode, digests and unavailable NPU | WASM/NPU selection and health diagnostics | P1 |
| 6 | Handler registry | Planned | Direct match-based dispatch | Registry, metadata and typed validation | P0 |
| 6 | Execution controls | Planned | Synchronous local invocation | Deadlines, cancellation, limits, idempotency and concurrency | P0 |
| 6 | Additional handlers | Planned | Non-runtime actions cannot execute | Dataset/evidence export, models, agents and releases | P0/P1 |
| 6 | Hardware programming | Blocked by dependency | Explicitly denied | Phase 11 qualification plus Authority/approval gates | Do last |
| 7 | Authorization/execution ledger | Complete local | Immutable linked records and verification | Start/target/sync/policy/release event coverage | P1 |
| 7 | Transaction and tamper behavior | Complete local | Rollback and forged execution tests | Property testing, checkpoints and retention | P1 |
| 7 | Cryptographic evidence | Planned | Hashing exists | Signatures, protected keys, rotation and secure timestamps | Depends on Phase 12 |
| 7 | Signed synchronization | Partial prototype | Outbox/Z0 concepts exist | Idempotent batches, retry, limits and recovery | P0 after identity |
| 7 | Remote acknowledgement | Planned | No receipt claim | Acknowledged/rejected states and verification | P0 |
| 7 | Evidence export/verifier | Planned | Internal verification only | JSON/PDF package, CLI, keys and auditor portal | P0 |
| 8 | Desktop governed-operation screen | Complete local | Local request, result, capabilities and evidence surface | Broader journeys and recovery states | P1 |
| 8 | Operational application shell | Partial prototype | Landing and Authority desktop exist | Navigation, workspace, identity, target, sync and diagnostics | P1 |
| 8 | Operational modules | Planned | Most modules absent/reference-only | Implement or visibly disable every named module | P1/P2 |
| 8 | Truthful UX states | Partial | Local boundaries documented | Remove remaining fixtures; source/stale/error labeling | P0 |
| 8 | Accessibility/E2E | Planned | No complete audit evidence | WCAG 2.2 AA and primary journey tests | Before beta |
| 9 | Edge API prototype | Partial | Worker endpoints and explicit environment selection | Versioned API, auth, errors, IDs, quotas and OpenAPI | P1 |
| 9 | Multi-tenancy | Planned | None evidenced | Tenant-aware storage and cross-tenant tests | Depends on Phase 3 |
| 9 | Operations and recovery | Planned | Dry-run/build evidence only | Environments, monitoring, backup, restore and rollback | Before beta |
| 9 | Enterprise administration | Planned | None evidenced | SSO/SCIM, licensing, retention, support controls and audit | Later |
| 10 | TypeScript/Python clients | Partial | Client surfaces exist | Signed packages, clean installation and version support | P1 |
| 10 | Rust/WASM/browser SDK | Partial | Runtime crates/WASM exist | Stable external SDK packaging and compatibility | P1 |
| 10 | CLI/verifier/simulator | Planned | Build scripts only | Productized CLI, offline verifier and local simulator | P1 |
| 10 | Developer documentation | Partial | Repository docs and three operations | Quick starts, API reference, tutorials and migrations | Before design partner |
| 11 | RTL implementation | Present, unqualified | NPU RTL, HAL and testbenches exist | Assertions, random tests, CDC, coverage and synthesis | Parallel hardware track |
| 11 | Cross-target equivalence | Planned | No board evidence | Native/WASM/RTL/FPGA reference-vector comparison | P0 hardware |
| 11 | FPGA board qualification | Planned | No supported-board result | Constraints, timing, resources, performance, power and recovery | P0 hardware |
| 11 | Hardware security | Planned | Hardware programming denied | Signed bitstreams, device identity, rollback and debug policy | After board proof |
| 12 | Threat model and trust boundaries | Partial | Repository truth boundaries documented | Formal system threat model and control mapping | P0 before beta |
| 12 | Key/data protection | Planned | No production key assurance | Keychain, DB protection, rotation, revocation and redaction | P0 |
| 12 | Application/API hardening | Planned | Basic typed IPC exists | Tauri/CSP/input limits/DoS/SAST/DAST/pen test | P0 |
| 12 | Supply-chain security | Planned | Lockfiles only | SBOM, attestations, signed releases and vulnerability policy | P0 |
| 12 | Privacy/recovery assurance | Planned | None certified | Retention/privacy docs and recovery drill | Before production candidate |
| 13 | Commercial catalogue | Partial | Proposed catalogue and quote-now boundary documented | Validated product requirements and approvals | P2 |
| 13 | Entitlements/licensing | Planned | No enforcement | Issuance, offline licence, expiry, grace and SKU tests | Before paid beta |
| 13 | Metering/billing | Planned | Proposed prices only | Usage, quotas, invoices, GST and reconciliation | Before paid service |
| 13 | Legal framework | Planned | No executed product terms evidenced | Terms, DPA, pilot/OEM/data/RTL licences and IP review | P0 before sales |
| 14 | Release policy/manifests | Planned | CI and contract version exist | Version/support policy, manifest, freeze and evidence | After security closure |
| 14 | Signed distribution | Planned | No signed installer/package evidence | Windows/macOS/Linux, SDK and container signing | P0 release |
| 14 | Migration/rollback | Planned | No release-upgrade evidence | Upgrade, downgrade, rollback, data and legacy evidence tests | P0 release |
| 14 | Operational runbooks | Planned | Staging notes only | DR, incident, deployment, operator/admin and support books | P0 release |
| 14 | Certification and approval | No-go | Production boundary explicit | All acceptance gates and named human approval | Final gate |
| 15 | Internal/design-partner pilots | Planned | No customer acceptance evidence in this baseline | Scoped deployment, training, monitoring and exit review | After M4 |
| 15 | Research/enterprise/FPGA pilots | Planned | None evidenced | Independent acceptance and published pilot evidence | Sequential |
| 15 | General availability | No-go | Critical gates remain open | Three successful pilots and no critical operational issue | Final decision |

## Milestone status

| Milestone | Target state | Current state | Gate status |
| --- | --- | --- | --- |
| M0 — authoritative baseline | Local engineering baseline | Achieved locally | `baseline-2026-08-29`; hosted clean-clone evidence moves to M1 |
| M1 — reproducible CI | Controlled development | Achieved | Hosted run `33237684396` passed the Linux stack and Ubuntu/macOS/Windows desktop matrix and retained release evidence |
| M2 — shared contracts | Integration foundation | Partial | Operation/runtime slice exists; full domain platform remains open |
| M3 — identity and Authority | Security prototype | Not achieved | Verified identity, tenancy, policy lifecycle and approvals absent |
| M4 — governed execution | Controlled product alpha | Partial precursor | Three local operations work; generalized safe execution absent |
| M5 — evidence synchronization | Verifiable alpha | Not achieved | Local ledger exists; independent signatures/acknowledgement absent |
| M6 — operational UI | Enterprise beta | Not achieved | Full operational modules/accessibility absent |
| M7 — Edge and SDK platform | Design-partner release | Not achieved | Multi-tenant operability and signed SDK distribution absent |
| M8 — security closure | Production candidate | No-go | Security acceptance not performed |
| M9 — FPGA qualification | Hardware evaluation release | No-go | No board qualification/equivalence evidence |
| M10 — release certification | Software production release | No-go | Signed artifacts, recovery, legal and release approval absent |
| M11 — pilot completion | GA decision | No-go | Required pilots and acceptance evidence absent |

## Critical production-gate matrix

| Gate | Status | Evidence required to close |
| --- | --- | --- |
| Clean committed revision | Closed locally | Coherent baseline commits and clean worktree |
| Clean-checkout CI | Closed | Hosted run `33237684396` passed the supported clean-checkout matrix |
| Real identity assurance | Open | Backend-derived identity/device/session assurance |
| Protected-action completeness | Partial | Each action implemented or explicitly unavailable with integration tests |
| Approval lifecycle | Open | Durable request-bound approval with expiry/revocation/separation of duties |
| Non-bypassable authorization | Partial local | Registry-wide enforcement, replay/expiry and bypass tests |
| Independent evidence verification | Open | Signed export, keys and offline verifier |
| Signed acknowledged synchronization | Open | Remote receipt/rejection evidence and idempotency |
| Truthful operational UX | Partial | Complete control/state/metric audit and E2E proof |
| Backup/restore/upgrade/rollback | Open | Passing exercises and immutable reports |
| Security closure | Open | No unresolved critical/high finding |
| Signed packages/installers | Open | Reproducible signed distribution evidence |
| Legal/SKU alignment | Open | Approved terms and tested entitlements |
| Separate software/hardware claims | Partial | Software release evidence plus independent board qualification |
| Physical NPU proof | Open | Board-generated equivalence, timing, power and performance evidence |
| Human release approval | Open | Named approval linked to immutable release evidence |

Overall programme status: **NO-GO for production and GA**. The completed
local vertical slice remains suitable for engineering demonstrations and
carefully scoped pilots only.
