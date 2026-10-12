# workers-sdk Learning Index

## Source
- **Origin**: ./origin/
- **GitHub**: https://github.com/cloudflare/workers-sdk

## Explorations

### 2026-03-25 1036 (default - 3 agents)
- [2026-03-25/1036_ARCHITECTURE](2026-03-25/1036_ARCHITECTURE.md)
- [2026-03-25/1036_CODE-SNIPPETS](2026-03-25/1036_CODE-SNIPPETS.md)
- [2026-03-25/1036_QUICK-REFERENCE](2026-03-25/1036_QUICK-REFERENCE.md)

**Key insights**:
- Workers SDK is a monorepo: wrangler (CLI), miniflare (local dev), C3 (scaffolding)
- D1 uses SQLite locally via Durable Objects, remote via API with file upload/polling
- Deploy pipeline: config parse -> esbuild bundle -> multipart upload to Cloudflare API
