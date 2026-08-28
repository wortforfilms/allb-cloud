# Architecture

The desktop application is local-first and separates five trust boundaries.

1. React/TypeScript presents state and sends typed commands; it never grants authority.
2. Rust validates the full authorization request and returns an explicit effect.
3. SQLite stores immutable evidence and an offline sync outbox.
4. OS keychain integration (production adapter) holds device and signing keys; secrets never belong in web storage.
5. A remote authority service may reconcile signed evidence, but cannot silently rewrite the local chain.

Core request: `principal + action + resource + workspace + assurance/context`.
Core effects: Permit, Deny, RequireApproval, RequireStepUpAuthentication and Abstain.

The current policy evaluator is a deterministic reference implementation. It is deliberately labelled non-certified until a reviewed Cedar schema, signed bundles and conformance tests replace it.
