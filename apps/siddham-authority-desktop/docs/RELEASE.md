# Native release gates

1. `npm ci && npm run check`
2. Install stable Rust and run `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`.
3. Build on each target operating system; do not cross-claim installers.
4. Generate and review SBOM and dependency advisories.
5. Inject signing/notarisation credentials only through protected CI secrets.
6. Verify updater signatures and perform clean-machine install/uninstall tests.
7. Record hashes, test reports, approvals and signer identity in the release evidence pack.

No build is “production approved” until the human Release Authority signs the complete evidence pack.
