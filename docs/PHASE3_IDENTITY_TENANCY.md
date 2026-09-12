# Phase 3 local identity and tenancy

Evidence date: 2026-08-29

## Delivered boundary

The Siddham Authority desktop now owns the identity context used for governed
execution. A request may name an action and resource, but it cannot select its
effective principal, device, workspace membership or assurance. The Rust
boundary resolves those fields from a fresh eight-hour local session before
policy evaluation and before evidence is written.

SQLite migration `005_identity_tenancy.sql` adds organizations, principals,
devices, workspaces, memberships, sessions and federation-provider
configuration. All active-status, expiry, recovery-generation and membership
conditions must match in one backend query. A failed identity check creates no
authorization evidence and reaches no MAATAA handler.

## Proved fail-closed cases

- Direct workspace-ID substitution is rejected before policy evaluation.
- Request-supplied principal and assurance values do not become authoritative.
- Expired and explicitly revoked sessions are rejected.
- Device revocation increments its recovery generation and invalidates every
  active session for that device.
- Suspended or revoked principals, devices, memberships, workspaces and
  organizations cannot authenticate through the verification query.
- Federation reports an empty configuration until a real provider record
  exists; no external sign-in or lifecycle claim is made.

## Local bootstrap scope

The current enrollment is a desktop-local development bootstrap for one human
principal, one device and one workspace membership. A new opaque session token
is created at application startup and held by the Rust runtime. This proves the
non-bypassable application boundary and tenancy model; it is not production
credential enrollment, hardware-backed device attestation or enterprise SSO.

## Deferred production gates

- OS keychain or hardware-backed private keys and phishing-resistant login.
- Authorized recovery ceremony and replacement-device enrollment.
- Real OIDC/SAML metadata verification, login and deprovisioning evidence.
- Tenant-scoped encryption keys, export/deletion workflows and recovery drills.
- Hosted CI reproduction and security review.

These remain Phase 9/12 production gates and must not be inferred from the
local Phase 3 security prototype.

