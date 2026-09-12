# Phase 4 local Authority

Evidence date: 2026-08-29

## Delivered boundary

The Rust desktop boundary now evaluates every governed request against the
active policy stored in SQLite. Identity supplies the authoritative role and
assurance. The client cannot select either value, call the MAATAA runtime
without passing Authority, or reuse a request identifier.

Migration `006_authority_policy.sql` adds retained policy bundles, append-only
lifecycle provenance and immutable request claims. Policy documents contain
explicit allow, approval and deny sets. Evaluation applies structural checks,
operation-shape checks, explicit deny-overrides, assurance requirements,
approval requirements and finally role-based allows. Absence or corruption of
the active policy produces a default deny.

## Policy lifecycle

- Create validates a typed policy document and records a draft plus provenance.
- Simulate records the request digest and returns a decision without activating
  the draft or executing an operation.
- Activate atomically retires the previous active policy, activates one draft
  and records provenance.
- Retire records provenance and leaves execution default-denied when no active
  policy remains.
- Versions are unique; policy records and lifecycle events are retained.

## Enforcement and replay behavior

- A unique request claim is written after session verification and before
  authorization evidence or execution.
- Reuse of a request ID is rejected before a second decision or execution.
- A permitted runtime request receives exactly one operation ID.
- Only `runtime:execute` reaches the current MAATAA handler path.
- `workspace:view` can be permitted as a non-executing authorization decision.
- Approval-bound actions return `RequireApproval` but do not execute because
  Phase 5 has not produced a durable approval artifact.
- Explicitly unavailable actions return `Deny`; hardware programming remains
  blocked pending independent hardware qualification.

## Verification

The native suite covers active-policy permit, explicit deny-overrides, every
protected-action classification, draft simulation isolation, activation and
retirement provenance, no-active-policy default deny, request replay, exactly
one operation ID, identity substitution, tenancy isolation, session/device
revocation and linked evidence.

## Deferred gates

Phase 5 must add maker-checker approval, separation of duties, approval binding,
expiry and anti-reuse. Phase 6 must add the generalized handler registry and
execution limits. Those capabilities are not implied by this local Authority
prototype.

