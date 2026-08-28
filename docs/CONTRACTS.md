# Governed operation contract

`crates/siddham-contracts` is the canonical shared contract package. The
machine-readable catalog in `contracts/ecosystem-contract.json` drives the
generated TypeScript, Worker, desktop, Python, and JSON Schema projections.
Generated files must not be edited directly.

## Generation and drift checks

```bash
npm run contracts:generate
npm run contracts:check
npm run contracts:python-check
```

CI runs the drift check before runtime, Worker, SDK, or desktop validation. A
contract change is complete only when the Rust source, catalog, fixtures, and
all generated projections agree.

## Implemented local execution slice

The desktop submits an `OperationRequest` to trusted Rust code. The policy
engine records its `AuthorizationDecision`. Only a permit for
`runtime:execute` reaches MAATAA. MAATAA currently implements three typed
operations:

- `tokenizeBrahmi`
- `evaluateSandhi`
- `lookupSutra`

The runtime returns a typed `ExecutionResult`, including the actual execution
mode and capability identity. Authority then records immutable execution
evidence linked to the authorization event and request. Verification checks
both ledgers and their outboxes.

## Protected-action boundary

The contract also names dataset, model, agent, policy, hardware, release, and
evidence actions so every caller uses the same vocabulary. They are not
claimed as implemented handlers. Policy evaluates and records them, then
denies or requires an unavailable approval/step-up path; none can reach
execution. This preserves one enforcement pattern without inventing backend
capabilities.
