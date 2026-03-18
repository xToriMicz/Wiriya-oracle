#!/usr/bin/env bash
set -euo pipefail

# deploy.sh — Deploy Parami landing page to Cloudflare Workers
# Usage: ./deploy.sh [production|staging]

ENV="${1:-production}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Deploying Parami to ${ENV}..."

# Check wrangler is installed
if ! command -v wrangler &>/dev/null; then
  echo "Error: wrangler not found. Install with: npm install -g wrangler"
  exit 1
fi

# Check authentication
if ! wrangler whoami &>/dev/null; then
  echo "Error: Not authenticated. Run: wrangler login"
  exit 1
fi

# Deploy
cd "$SCRIPT_DIR"
wrangler deploy --env "$ENV"

echo "==> Deployed to ${ENV} successfully"
echo "    https://parami.makeloops.xyz"
