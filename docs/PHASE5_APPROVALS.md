# Phase 5 local approvals and delegation

Evidence date: 2026-08-29

## Delivered boundary

Approval-required Authority decisions now create durable, workspace-scoped
pending records bound to the exact claimed request ID and request hash. Votes,
consumption and lifecycle events are immutable. Approval never substitutes for
identity, policy or handler availability.

Migration `007_approvals.sql` adds approval requests, independent votes,
one-time consumption, scoped delegation, emergency access and append-only
lifecycle provenance.

## Lifecycle and integrity

- Pending requests expire after their bounded validity window.
- Eligible reviewers may approve or reject; rejection is terminal.
- The maker cannot vote on their own request.
- Each approver may vote once and quorum counts distinct eligible principals.
- The maker may cancel only a pending request.
- Consumption requires the exact approval ID, request ID and request hash.
- A consumed approval cannot be reused for the same or another operation.
- Approved-but-expired, rejected, cancelled and mismatched artifacts fail
  closed.

## Delegation and emergency access

Delegation requires two active members, is scoped to one workspace and action,
has a maximum 24-hour lifetime, and can be revoked by its grantor. It does not
copy the grantor's general authority.

Emergency access requires a substantive justification, is short-lived, cannot
be self-reviewed, and can be rejected or independently approved and revoked.
Every transition is retained for review. Emergency approval does not bypass a
missing handler or hardware qualification gate.

## Operational surface

The desktop bridge exposes the workspace approval inbox, authenticated decision
submission and maker cancellation. The main surface reports the number of
durable pending approvals. Reviewer history, comments and evidence exist in the
backend; the expanded workflow screen and external notifications remain Phase
8 product UX work.

## Verification

The native suite proves maker-checker separation, distinct-principal quorum,
terminal rejection, expiry, cancellation rules, exact binding, anti-reuse,
scoped/revoked delegation, independently reviewed/revoked emergency access and
automatic pending-inbox creation from an Authority decision.

## Deferred production gates

Production authentication, external notification delivery, organization-scale
approver administration, cryptographic signatures and independent evidence
export remain later Phase 7/8/9/12 gates. No hosted or production approval claim
is made.

