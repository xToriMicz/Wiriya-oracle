# CI/CD Plan — Parami Landing Page

## GitHub Actions Workflow

### Trigger
- Push to `main` branch with changes in `ψ/lab/parami/**`
- Manual dispatch via `workflow_dispatch`

### Secrets Required
- `CLOUDFLARE_API_TOKEN` — Wrangler deploy token (Workers scope)
- `CLOUDFLARE_ACCOUNT_ID` — Cloudflare account ID

### Workflow Steps

```yaml
name: Deploy Parami
on:
  push:
    branches: [main]
    paths: ["ψ/lab/parami/**"]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install wrangler
        run: npm install -g wrangler

      - name: Deploy to Cloudflare
        working-directory: ψ/lab/parami/deploy
        run: wrangler deploy --env production
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

### Setup Checklist
- [ ] Create Cloudflare API token with Workers edit permission
- [ ] Add `CLOUDFLARE_API_TOKEN` to repo secrets
- [ ] Add `CLOUDFLARE_ACCOUNT_ID` to repo secrets
- [ ] Configure DNS: CNAME `parami` → `parami-landing.workers.dev` on makeloops.xyz
- [ ] Create `.github/workflows/deploy-parami.yml` from the workflow above
