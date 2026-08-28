# Branch and release policy

## Branches

- `main` is the protected integration and release-history branch.
- Work is prepared on short-lived `codex/<purpose>` or team feature branches.
- Direct force-pushes and history rewrites on `main` are prohibited.
- A change reaches `main` only after required CI and review gates pass.
- Generated bindings must be regenerated and drift-checked in the same change
  as their canonical contract.

## Commits

Baseline work is separated into ecosystem consolidation, shared contracts,
Authority integrity, governed runtime/evidence/UI, and CI/documentation where
the dependency graph permits. Commits must not include secrets, local caches,
build output or unexplained deletions.

## Releases

- Baseline tags use `baseline-YYYY-MM-DD[.N]`.
- Product versions use annotated `vMAJOR.MINOR.PATCH` tags only after the
  release gates in `PRODUCT_ROADMAP.md` pass.
- Tags are created from clean, reviewed commits and are never moved.
- Staging evidence does not authorize a production tag.
- Production requires named human Release Authority approval linked to the
  immutable release manifest and evidence package.

## Support

Release branches are created only when a supported release actually exists.
No current branch or tag implies GA, an SLA, production support or physical
hardware certification.
