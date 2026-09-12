# Phase 2 shared contract foundation

Evidence date: 2026-08-29

`crates/siddham-contracts` is the Rust authority and
`contracts/ecosystem-contract.json` is its language-neutral generation input.
Contract version `1.1.0` adds canonical identity, workspace, resource,
approval, synchronization, error and release records to the existing governed
operation and execution contracts.

Versions `1.0.x` and `1.1.x` are accepted. Malformed versions, unsupported
minors, unknown majors and unknown fields fail closed. Shared ID and SHA-256
validators and the operation/action invariant are tested across consumers.

The deterministic generator emits TypeScript, Edge Worker, desktop, Python
and JSON Schema projections. CI checks drift before consumer tests. Eight
fixtures cover the valid operation plus every current structural/version rule.

These are interchange contracts, not evidence that later identity, approval,
remote acknowledgement or release runtimes exist. Those remain gated by
Phases 3, 5, 7 and 14.
