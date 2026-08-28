# Infrastructure authority

The Cloudflare Worker is configured and deployed through the repository-root
`wrangler.jsonc`. This directory intentionally contains no Terraform resources.

Current boundaries:

- `wrangler.jsonc` is the source of truth for Worker names, routes, environments,
  build commands, non-secret variables, and observability.
- `.github/workflows/ci.yml` is the source of truth for verification and the
  approval-bound staging deployment job.
- Cloudflare credentials remain GitHub environment secrets or local Wrangler
  credentials; they must never be committed.
- Production deployment is not automatic. Staging uses the isolated
  `maataa-sovereign-worker-staging` environment before any production action.

If Terraform is introduced later, it must manage real resources with imported
state and documented ownership. Empty placeholder resources are not accepted.
