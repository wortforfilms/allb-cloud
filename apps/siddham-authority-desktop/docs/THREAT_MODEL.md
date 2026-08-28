# Threat model

Protected assets: semiconductor IP, policy bundles, identity metadata, approval records, audit evidence and device keys.

Required production controls:

- Default deny on malformed, stale or workspace-mismatched requests.
- AAL3/WebAuthn for release and authority administration.
- Non-exportable keys in Keychain, Credential Manager or Secret Service.
- Database encryption and secure backups.
- Signed policy bundles with rollback protection and expiry.
- Agent capabilities that are short-lived, resource-bound and non-delegable.
- Transactional evidence writes for high-risk mutations; failure blocks the mutation.
- Revocation lists, device quarantine and clock-skew handling.
- Dependency, SBOM, code-signing and updater-signature verification.

Out of scope for this scaffold: production identity proofing, remote attestation, legal certification and independent penetration testing.
