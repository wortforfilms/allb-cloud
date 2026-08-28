# Initial risk register

| ID | Risk | Severity | Current control | Required treatment | Owner |
| --- | --- | --- | --- | --- | --- |
| R-001 | Self-declared identity or assurance is mistaken for verified AAL | Critical | UI labels and production boundary documented | Implement backend-derived identity/device/session assurance | Authority |
| R-002 | A protected handler bypasses Authority | Critical | Three local operations pass through trusted Rust; others fail closed | Handler registry, expiry, replay and bypass tests | Authority/runtime |
| R-003 | Hash chaining is mistaken for independently signed evidence | High | Local tamper tests and explicit boundary | Protected signing keys, rotation, export and offline verifier | Evidence/security |
| R-004 | Sent synchronization is mistaken for acknowledgement | High | Outbox and documentation distinguish states | Signed remote receipt/rejection and idempotent retry | Evidence/Edge |
| R-005 | RTL or simulation is marketed as physical NPU performance | Critical | NPU capability reports unavailable; catalogue is gated | Board equivalence, timing, power and performance evidence | Hardware |
| R-006 | Build jobs fail or skip validation due to storage exhaustion | High | Reproducible dumps removed | Cross-platform disk preflight and low-disk CI test | DevOps |
| R-007 | Dirty baseline cannot be reproduced | High | Consolidated layout and lockfiles | Coherent commits, clean-clone validation and immutable tag | Architecture/DevOps |
| R-008 | Generated contracts drift across languages | High | Deterministic generator and CI check | Expand fixtures/validators and compatibility report | Contracts |
| R-009 | Reference/demo content is treated as live product evidence | High | Authority map and directory separation | Automated hygiene checks and UI source labels | Product/QA |
| R-010 | Corpus provenance/completeness is overstated | High | Commercial catalogue requires disclosure | Record provenance, canonical boundary and completeness levels | Data/corpus |
| R-011 | Cross-workspace access leaks tenant data | Critical | No shared tenancy is claimed | Implement tenancy and direct-ID substitution tests | Identity/Edge |
| R-012 | Keys or secrets leak through source, logs or exports | Critical | Secrets ignored; no production key claim | Automated scans, keychain storage and redaction tests | Security |
| R-013 | Dependency licence or vulnerability blocks distribution | High | Lockfiles and root dual licence | Automated licence/vulnerability audit and SBOM | Security/legal |
| R-014 | Pricing catalogue is interpreted as current availability | High | Proposed/quote-now/planned classifications | Entitlement tests, legal approval and evidence-to-sale gate | Commercial/product |
| R-015 | Backup, upgrade or rollback corrupts evidence | High | No production persistence claim | Migration, backup, restore, rollback and legacy evidence tests | Release/evidence |

Review this register at every milestone gate. A critical risk cannot be accepted
solely by the implementation team for production release.
