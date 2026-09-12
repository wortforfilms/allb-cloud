# Phase 6 local governed execution

Evidence date: 2026-08-29

## Delivered boundary

Every protected action now resolves through one typed Rust handler registry.
The registry reports handler identity, availability, approval requirement,
execution target, input ceiling, deadline and truthful detail. Missing or
unqualified capability is a first-class unavailable result, never an implicit
fallback.

Migration `008_execution_registry.sql` adds workspace-scoped governed objects,
execution controls and a unique handler-execution claim. This extends the
existing unique Authority request and operation claims into an exactly-once
local dispatch path.

## Execution controls

- Authority and verified session checks precede handler preparation.
- Approval-bound handlers consume an exact approval only after availability,
  limits and cancellation checks pass.
- The full request is limited to 16 KiB; operation-specific text and identifier
  ceilings are enforced before dispatch.
- Local handlers have a two-second deadline and record started, succeeded,
  failed, cancelled or timed-out state.
- Cancellation is durable and effective before dispatch or approval resume.
- The desktop database boundary serializes execution, providing a bounded local
  concurrency of one and eliminating concurrent mutation races.
- Unique request and operation claims reject duplicate side effects.
- The selected target is explicitly `software-native`. WASM remains a built
  package rather than a desktop execution target, and the physical NPU remains
  unavailable.

## Real local handlers

- Workspace metadata view.
- Brahmi tokenization, Paninian Sandhi evaluation and Sutra lookup through the
  MAATAA runtime.
- Workspace-scoped dataset metadata read.
- Approval-bound dataset manifest export. It exports no restricted payload and
  labels itself `manifest-only`.
- Approval-bound model promotion and release approval state transitions.
- Evidence-ledger summary export with event count and latest chain hash.

Agent delegation and policy lifecycle are real bounded Phase 4/5 modules, but
the generic operation contract does not yet carry their required payloads.
Their registry entries therefore remain explicitly unavailable instead of
inventing parameters. Hardware programming remains blocked pending Phase 11.

## Verification

The native suite proves complete registry coverage, unavailable hardware,
bounded dataset export, approval resume and one-time consumption, cancellation
before resume, replay protection, one operation ID, lifecycle controls,
identity/tenant isolation and evidence linkage.

## Deferred production gates

Hard interruption of long-running external processes, configurable worker
pools, WASM desktop dispatch, NPU selection, generalized agent/policy payloads,
large binary streaming and production resource monitoring remain later
contract, hardware and security work. They are not claimed by this local phase.

