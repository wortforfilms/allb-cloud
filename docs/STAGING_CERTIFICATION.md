# Staging certification

Certification date: 2026-08-28

Environment: `staging`

Worker: `maataa-sovereign-worker-staging`

URL: `https://maataa-sovereign-worker-staging.forfilmcoin.workers.dev`

Version ID: `67fc38ef-304a-43b8-8050-291b88c20031`

Source commit: `f4f942e`

## Deployment evidence

- Wrangler dry-run completed before deployment.
- Upload size: 659.07 KiB; gzip size: 203.54 KiB.
- Reported Worker startup time: 6 ms.
- The only runtime binding is `ENVIRONMENT="staging"`.
- The production custom domain and production Worker were not changed.

## Live endpoint evidence

| Check | Expected | Observed |
|---|---:|---:|
| `GET /health` | Staging identity, HTTP 200 | Passed |
| `POST /api/z0/sandhi` | `nara` + `indra` → `narendra`, HTTP 200 | Passed |
| `GET /api/z0/sutra/1.1.1` | Source-backed Sutra record, HTTP 200 | Passed |
| `POST /api/z0/tokenize-brahmi` | Four Brahmi tokens, HTTP 200 | Passed |
| Missing Sutra `9.9.999` | Explicit HTTP 404 | Passed |
| Malformed Sandhi JSON | Explicit HTTP 400 | Passed |

## Boundaries

- This certifies the isolated staging language API only.
- It does not certify production, mailbox delivery, physical FPGA execution,
  unused experimental Worker modules, or an external uptime objective.
- Version history currently contains only this version. A prior-version rollback
  is therefore unavailable until a later version is deployed; do not claim a
  tested rollback path yet.
