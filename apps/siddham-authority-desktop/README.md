# Siddham Authority Desktop

Standalone Tauri 2 application for identity, workspace authority, governed data and evidence-backed release decisions.

## Included

- React 19 + TypeScript desktop UI
- Modular Rust policy, command, storage and evidence boundaries
- Local SQLite WAL database
- Versioned SQLite migrations, immutable audit triggers, SHA-256 event chaining and offline sync outbox
- Offline policy simulator with Permit, Deny, RequireApproval and RequireStepUpAuthentication effects
- Responsive desktop/mobile-window layout
- Tauri bundle configuration, cross-platform CI, domain contract, reference policy bundle, tests, threat model and release gates

## Run

```bash
npm install
npm run desktop:dev
```

Create a native installer with `npm run desktop:build`. Platform prerequisites from Tauri must be installed first. macOS installers must be built on macOS, Windows installers on Windows, and Linux packages on Linux. Signing/notarisation credentials are intentionally not included.

## Structure

- `src/` — React control-plane UI and typed Tauri bridge
- `src-tauri/src/` — Rust domain, policy, storage, evidence and commands
- `src-tauri/migrations/` — immutable SQLite schema evolution
- `contracts/` — language-neutral authorization schema
- `policies/` — reference policy bundle
- `config/` — safe non-secret runtime example
- `docs/` — architecture, threat model and release gates
- `.github/workflows/` — macOS, Windows and Linux verification

## Production gaps

The included evaluator is a deterministic reference policy, not a certified Cedar runtime. Before production, add OIDC/WebAuthn, signed policy bundles, OS keychain-backed keys, database encryption, capability revocation, evidence export signatures, backup/sync conflict handling, platform code signing, updater verification and independent security review.
