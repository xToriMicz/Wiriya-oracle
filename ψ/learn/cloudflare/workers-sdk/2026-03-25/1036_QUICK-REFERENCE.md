# Cloudflare Workers SDK — Quick Reference Guide

**Last updated**: 2026-03-25
**SDK Version**: Main branch from cloudflare/workers-sdk
**Status**: Complete reference for deployment and D1 database management

---

## Table of Contents

1. [What is Workers SDK](#what-is-workers-sdk)
2. [Installation](#installation)
3. [Key Wrangler Commands](#key-wrangler-commands)
4. [wrangler.toml Configuration](#wranglertoml-configuration)
5. [D1 Database Management](#d1-database-management)
6. [Workers API](#workers-api)
7. [Local Development](#local-development)
8. [Deploy Pipeline](#deploy-pipeline)
9. [Common Patterns](#common-patterns)
10. [Troubleshooting](#troubleshooting)

---

## What is Workers SDK

**Cloudflare Workers SDK** is the official toolset for building, testing, and deploying serverless applications on Cloudflare's global network.

### Core Components

| Component | Purpose |
|-----------|---------|
| **wrangler** | CLI tool for building, testing, and deploying Workers |
| **miniflare** | Local simulator powered by workerd (open-source Workers runtime) |
| **create-cloudflare (C3)** | Scaffolding tool for new projects |
| **workerd** | Open-source runtime that powers Cloudflare Workers |

### Key Features

- **Instant global deployment** — code deployed to 300+ data centers
- **Zero cold starts** — CPU access is managed, not metered by uptime
- **Full storage bindings** — D1 (SQLite), KV (key-value), R2 (S3-compatible), Durable Objects
- **Local development** — miniflare provides accurate local simulation
- **TypeScript support** — first-class TypeScript, automatic type generation

---

## Installation

### Prerequisites

- **Node.js**: Current, Active, or Maintenance versions
- **OS**: macOS 13.5+, Windows 11, or Linux (glib 2.35+)

### Quick Start

```bash
# Create a new project
npm create cloudflare@latest my-worker
cd my-worker

# Install wrangler globally (optional)
npm install -g wrangler

# Or use locally
npm install -D wrangler
```

### Verify Installation

```bash
wrangler --version
# Output: wrangler 3.x.x
```

---

## Key Wrangler Commands

### Development & Deployment

| Command | Purpose | Example |
|---------|---------|---------|
| `wrangler init` | Initialize a new Worker project | `wrangler init my-worker -y` |
| `wrangler dev` | Start local dev server (port 8787) | `wrangler dev --port 3000` |
| `wrangler deploy` | Deploy to Cloudflare production | `wrangler deploy` |
| `wrangler deployments list` | Show deployment history | `wrangler deployments list` |
| `wrangler delete` | Delete a deployed Worker | `wrangler delete my-worker` |

### D1 Database Commands

```bash
# Create a new database
wrangler d1 create my-database

# List all databases
wrangler d1 list

# Execute SQL
wrangler d1 execute my-database --command "SELECT * FROM users"

# Execute from file
wrangler d1 execute my-database --file schema.sql

# Local execution (uses local persistence)
wrangler d1 execute my-database --command "SELECT * FROM users" --local

# Remote execution (against production database)
wrangler d1 execute my-database --command "SELECT * FROM users" --remote

# Create migration
wrangler d1 migrations create my-database add_users_table

# Apply migrations
wrangler d1 migrations apply my-database
wrangler d1 migrations apply my-database --remote  # production

# Restore from backup
wrangler d1 restore my-database

# Get database info
wrangler d1 info my-database
```

### KV (Key-Value Storage)

```bash
# Create namespace
wrangler kv:namespace create my-kv-store

# Create preview namespace
wrangler kv:namespace create my-kv-store --preview

# List namespaces
wrangler kv:namespace list

# Put a key
wrangler kv:key put --namespace-id <ID> my-key "my value"

# Get a key
wrangler kv:key get --namespace-id <ID> my-key

# Delete a key
wrangler kv:key delete --namespace-id <ID> my-key

# Delete entire namespace
wrangler kv:namespace delete my-kv-store
```

### R2 (Object Storage)

```bash
# Create bucket
wrangler r2 bucket create my-bucket

# List buckets
wrangler r2 bucket list

# Upload file
wrangler r2 object upload my-bucket file.txt --file ./file.txt

# Download file
wrangler r2 object download my-bucket file.txt

# Delete object
wrangler r2 object delete my-bucket file.txt

# Delete bucket
wrangler r2 bucket delete my-bucket
```

### Secrets Management

```bash
# Create/update secret
wrangler secret put MY_API_KEY
# Enter value at prompt

# Bulk create from JSON
wrangler secret put MY_SECRETS < secrets.json

# List secrets (shows names only)
wrangler secret list

# Delete secret
wrangler secret delete MY_API_KEY

# Create secret in preview environment
wrangler secret put MY_API_KEY --env preview
```

### Monitoring & Logging

```bash
# Tail real-time logs
wrangler tail

# Tail with filters
wrangler tail --format json
wrangler tail --status ok  # success only
wrangler tail --status error  # errors only
wrangler tail --search "keyword"

# View deployment status
wrangler deployments view <deployment-id>

# List recent deployments
wrangler deployments list
```

---

## wrangler.toml Configuration

### Minimal Configuration

```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2026-01-01"  # Set to last Friday
```

### Complete Configuration Example

```toml
# Project metadata
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2026-01-01"
compatibility_flags = ["streams_enable_constructors"]
workers_dev = true  # Enable workers.dev subdomain

# Account & deployment
account_id = "0000000000000000000000000000000000"
zone_id = "0000000000000000000000000000000000"  # For route binding

# Routes (only if custom domain)
routes = [
  { pattern = "example.com/api/*", zone_name = "example.com" }
]

# D1 Database Binding
[[d1_databases]]
binding = "DB"  # Variable name in env
database_name = "my-database"
database_id = "12345678-1234-1234-1234-123456789012"

# D1 Binding - Preview (testing)
[[d1_databases]]
binding = "DB_PREVIEW"
database_name = "my-database-preview"
database_id = "87654321-4321-4321-4321-210987654321"
preview = true

# KV Namespace Binding
[[kv_namespaces]]
binding = "MY_KV"
id = "abcdef1234567890"

# Preview KV Namespace
[[kv_namespaces]]
binding = "MY_KV_PREVIEW"
preview_id = "0987654321fedcba"

# R2 Bucket Binding
[[r2_buckets]]
binding = "MY_BUCKET"
bucket_name = "my-s3-bucket"

# Durable Objects
[[durable_objects.bindings]]
name = "COUNTER"
class_name = "Counter"
script_name = "counter-worker"

# Service Binding (call another Worker)
[[services]]
binding = "MY_SERVICE"
service = "other-worker"
environment = "production"

# Environment Variables (non-secret)
[env.production]
vars = { ENVIRONMENT = "production", API_URL = "https://api.example.com" }

[env.staging]
vars = { ENVIRONMENT = "staging", API_URL = "https://staging-api.example.com" }

# Scheduled Events (Crons)
[triggers]
crons = ["0 */6 * * *"]  # Every 6 hours

# AI Model Binding (e.g., for text-generation)
[ai]
binding = "AI"

# Assets/Static Files
[assets]
directory = "public/"
binding = "ASSETS"

# Observability
[observability]
enabled = true

# Build configuration
[build]
command = "npm run build"
cwd = "./"
watch_paths = ["src/**/*.ts"]

# Custom module rules
[[rules]]
type = "Data"
globs = ["**/*.png"]

[[rules]]
type = "CompiledWasm"
globs = ["**/*.wasm"]
```

### Key Configuration Fields

| Field | Type | Purpose |
|-------|------|---------|
| `name` | string | Worker name (must be lowercase, alphanumeric + hyphens) |
| `main` | string | Entry point file (JS/TS) |
| `compatibility_date` | YYYY-MM-DD | Sets runtime behavior (use latest Friday) |
| `account_id` | string | Your Cloudflare account ID (from dashboard) |
| `workers_dev` | bool | Enable `<name>.<account>.workers.dev` subdomain |
| `routes` | array | Custom domain routes with zone binding |
| `env.*` | object | Environment-specific overrides |

### Environment Variables vs Secrets

```toml
# Non-secret variables (visible in config) — Use for dev/staging URLs, etc.
[env.production]
vars = { API_URL = "https://api.example.com" }

# Secrets (stored in Cloudflare) — Use for API keys, tokens, passwords
# Created with: wrangler secret put API_KEY
# Then access in code: env.API_KEY
```

---

## D1 Database Management

### Creating & Binding Databases

```bash
# 1. Create database (returns database_id)
wrangler d1 create my-database

# 2. Update wrangler.toml
[[d1_databases]]
binding = "DB"
database_name = "my-database"
database_id = "00000000-0000-0000-0000-000000000000"

# 3. Use in Worker code
export default {
  async fetch(request, env) {
    const result = await env.DB.prepare("SELECT * FROM users").all();
    return new Response(JSON.stringify(result.results));
  }
};
```

### Migrations

D1 tracks migrations in `./migrations/` directory.

```bash
# Create new migration file
wrangler d1 migrations create my-database create_users_table
# Creates: migrations/<timestamp>_create_users_table.sql

# Apply migrations locally (wrangler dev)
wrangler d1 migrations apply my-database --local

# Apply migrations to production
wrangler d1 migrations apply my-database --remote

# Migrations auto-run on deploy to production
```

### Migration Example

```sql
-- migrations/001_init.sql
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS posts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_posts_user_id ON posts(user_id);
```

### Querying Databases

```typescript
// SELECT with params
const user = await env.DB.prepare(
  "SELECT * FROM users WHERE id = ?"
).bind(userId).first();

// INSERT
const result = await env.DB.prepare(
  "INSERT INTO users (email, name) VALUES (?, ?)"
).bind(email, name).run();

// UPDATE
await env.DB.prepare(
  "UPDATE users SET name = ? WHERE id = ?"
).bind(newName, userId).run();

// DELETE
await env.DB.prepare(
  "DELETE FROM users WHERE id = ?"
).bind(userId).run();

// Batch operations
const stmt = env.DB.prepare("INSERT INTO users (email, name) VALUES (?, ?)");
const batch = users.map(u => stmt.bind(u.email, u.name));
const results = await env.DB.batch(batch);
```

### Local vs Remote

| Aspect | Local | Remote |
|--------|-------|--------|
| **Location** | `./.mf/d1/` | Cloudflare servers |
| **Command flag** | `--local` | `--remote` |
| **Speed** | Instant | Network latency |
| **Use case** | Development & testing | Production queries |
| **Persistence** | Survives wrangler dev | Always persisted |

```bash
# Local development
wrangler dev  # Uses local DB automatically

# Test against production DB
wrangler d1 execute my-database --command "SELECT COUNT(*) as count FROM users" --remote

# Restore production DB to local
wrangler d1 backup restore my-database --local
```

### Backup & Restore

```bash
# Create backup
wrangler d1 backup create my-database

# List backups
wrangler d1 backup list my-database

# Restore from backup
wrangler d1 backup restore my-database --backup-id <id>

# Restore to local dev
wrangler d1 backup restore my-database --local
```

---

## Workers API

### Basic Fetch Handler

```typescript
export interface Env {
  DB: D1Database;
  MY_KV: KVNamespace;
  MY_BUCKET: R2Bucket;
  API_KEY: string;  // Secret
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    try {
      const url = new URL(request.url);

      // Route requests
      if (url.pathname === "/api/users") {
        if (request.method === "GET") {
          return handleGetUsers(request, env);
        } else if (request.method === "POST") {
          return handleCreateUser(request, env);
        }
      }

      return new Response("Not Found", { status: 404 });
    } catch (error) {
      return new Response(`Error: ${error}`, { status: 500 });
    }
  }
};

async function handleGetUsers(request: Request, env: Env): Promise<Response> {
  const result = await env.DB.prepare("SELECT * FROM users").all();
  return new Response(JSON.stringify(result.results), {
    headers: { "Content-Type": "application/json" }
  });
}

async function handleCreateUser(request: Request, env: Env): Promise<Response> {
  const { email, name } = await request.json();
  const result = await env.DB.prepare(
    "INSERT INTO users (email, name) VALUES (?, ?)"
  ).bind(email, name).run();

  return new Response(JSON.stringify(result), { status: 201 });
}
```

### Key ExecutionContext Methods

```typescript
ctx.waitUntil(promise)
// Tells Cloudflare to keep the Worker alive until the promise settles
// Use for background tasks, logging, analytics
ctx.waitUntil(
  env.DB.prepare("INSERT INTO logs (message) VALUES (?)").bind(logMessage).run()
);

ctx.passThroughOnException()
// Pass request to origin if Worker throws an error
// Useful for failsafe scenarios
```

### Scheduled Events (Crons)

```typescript
export interface Env {
  DB: D1Database;
}

export default {
  async scheduled(controller: ScheduledController, env: Env): Promise<void> {
    // This runs on the cron schedule from wrangler.toml
    const result = await env.DB.prepare(
      "INSERT INTO jobs (status, ran_at) VALUES (?, CURRENT_TIMESTAMP)"
    ).bind("completed").run();

    console.log(`Job executed: ${JSON.stringify(result)}`);
  }
};
```

### Module Exports Format

Workers support different handler formats:

```typescript
// Default export (modern)
export default {
  fetch(request: Request, env: Env, ctx: ExecutionContext) {
    return new Response("Hello");
  },
  scheduled(controller: ScheduledController, env: Env) {
    console.log("Cron triggered");
  }
};

// Named exports (advanced)
export async function onRequest(context: PagesFunction) {
  return new Response("Hello from Pages Function");
}

// Module worker (rare)
export default class {
  fetch(request: Request) {
    return new Response("Hello");
  }
}
```

---

## Local Development

### Starting Development Server

```bash
# Basic development
wrangler dev

# Custom host/port
wrangler dev --host 0.0.0.0 --port 3000

# Disable live reload
wrangler dev --no-reload

# Specify config file
wrangler dev --config wrangler.staging.toml

# Inspect with browser DevTools
wrangler dev  # Then navigate to localhost:8787
# DevTools will open automatically (if interactive)
```

### Miniflare Configuration

Miniflare (the simulator) is controlled via `wrangler.toml`:

```toml
# Persistence location for KV, D1, etc.
[env.local]
vars = { ENVIRONMENT = "local" }
# By default, data persists in .mf/ directory
```

### Local vs Remote Bindings

| Binding Type | Local Dev (wrangler dev) | Remote (--remote) |
|--------------|--------------------------|-------------------|
| **D1** | Uses local SQLite file | Queries Cloudflare DB |
| **KV** | In-memory by default | Uses actual KV store |
| **R2** | Simulated locally | Uses actual R2 bucket |
| **Env vars** | From wrangler.toml | From deployed config |
| **Secrets** | Must be set locally | Uses remote secrets |

### Setting Local Secrets for Dev

```bash
# Create .dev.vars file (never commit!)
echo "API_KEY=local-test-key" > .dev.vars
echo "DATABASE_URL=http://localhost:5432" >> .dev.vars
```

Then access in code:
```typescript
const apiKey = env.API_KEY;  // Loaded from .dev.vars in local dev
```

### Testing in Local Dev

```bash
# Start dev server
wrangler dev

# In another terminal, test your API
curl http://localhost:8787/api/users
curl -X POST http://localhost:8787/api/users \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","name":"Test User"}'

# Trigger scheduled event manually
curl "http://localhost:8787/cdn-cgi/handler/scheduled"
```

### Debugging

```typescript
// Standard console methods work in local dev
console.log("Info:", data);
console.error("Error:", error);

// Use debugger (in VS Code)
// 1. Add breakpoint in code
// 2. Run: wrangler dev --inspector-port 9229
// 3. Attach VS Code debugger
```

---

## Deploy Pipeline

### How `wrangler deploy` Works

```
1. Read wrangler.toml configuration
   ↓
2. Validate configuration
   ↓
3. Bundle Worker code (with esbuild by default)
   ↓
4. Process bindings:
   - Create FormData with script + bindings
   - Validate secrets exist or prompt to set
   ↓
5. Upload to Cloudflare API
   - POST /accounts/{account_id}/workers/scripts/{name}
   ↓
6. Apply configuration:
   - D1 bindings with database_id
   - KV namespace IDs
   - Environment variables
   - Routes if custom domain
   ↓
7. Run migrations (for D1)
   ↓
8. Create deployment record
   ↓
9. Activate deployment (make it live)
```

### Pre-Deployment Checklist

```bash
# 1. Verify configuration
wrangler deploy --dry-run

# 2. Check for missing secrets
wrangler secret list

# 3. Run local tests
npm run test

# 4. Verify dev works locally
wrangler dev  # Test manually

# 5. Check for uncommitted changes (best practice)
git status

# 6. Deploy to staging first (if applicable)
wrangler deploy --env staging

# 7. Deploy to production
wrangler deploy
```

### Common Deploy Issues

**Script size too large**
```bash
# Split into multiple Workers
# Or use External Libraries carefully
# Check bundle size:
wrangler deploy --dry-run 2>&1 | grep "size"
```

**Secrets not found**
```bash
# Make sure secrets are created in your account
wrangler secret list

# If missing, create them:
wrangler secret put API_KEY
```

**Database not accessible**
```bash
# Verify database_id is correct in wrangler.toml
# Verify D1 is created:
wrangler d1 list

# Check binding name matches in code:
const result = await env.DB.prepare(...)  // Must match [[d1_databases]] binding
```

### Rollback & Version Management

```bash
# View deployment history
wrangler deployments list

# View specific deployment
wrangler deployments view <deployment-id>

# Rollback by deploying previous code
git revert <commit-hash>
wrangler deploy

# Or redeploy specific version
wrangler deployments rollback <deployment-id>
```

---

## Common Patterns

### Routing Pattern

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const { pathname, searchParams } = url;

    // Route by pathname
    if (pathname.startsWith("/api/users")) {
      return handleUsers(request, env);
    } else if (pathname.startsWith("/api/posts")) {
      return handlePosts(request, env);
    } else if (pathname === "/health") {
      return new Response("OK");
    }

    return new Response("Not Found", { status: 404 });
  }
};
```

### Middleware Pattern

```typescript
type Handler = (request: Request, env: Env, ctx: ExecutionContext) => Promise<Response>;

function withAuth(handler: Handler): Handler {
  return async (request, env, ctx) => {
    const auth = request.headers.get("Authorization");
    if (!auth || !auth.startsWith("Bearer ")) {
      return new Response("Unauthorized", { status: 401 });
    }
    return handler(request, env, ctx);
  };
}

function withJSON(handler: Handler): Handler {
  return async (request, env, ctx) => {
    try {
      const response = await handler(request, env, ctx);
      if (response.headers.get("Content-Type") === null) {
        response.headers.set("Content-Type", "application/json");
      }
      return response;
    } catch (error) {
      return new Response(
        JSON.stringify({ error: String(error) }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  };
}

const handler = withAuth(withJSON(async (request, env, ctx) => {
  const result = await env.DB.prepare("SELECT * FROM users").all();
  return new Response(JSON.stringify(result.results));
}));

export default { fetch: handler };
```

### CORS Pattern

```typescript
function addCorsHeaders(response: Response, origin: string): Response {
  const newResponse = new Response(response.body, response);
  newResponse.headers.set("Access-Control-Allow-Origin", origin);
  newResponse.headers.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  newResponse.headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  newResponse.headers.set("Access-Control-Max-Age", "86400");
  return newResponse;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const origin = request.headers.get("Origin") || "*";

    // Handle preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": origin,
          "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization",
        },
      });
    }

    const response = await handleRequest(request, env, ctx);
    return addCorsHeaders(response, origin);
  }
};
```

### Error Handling Pattern

```typescript
class APIError extends Error {
  constructor(
    public status: number,
    message: string,
    public code: string
  ) {
    super(message);
  }
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    try {
      const url = new URL(request.url);

      if (url.pathname === "/api/users") {
        const user = await env.DB.prepare("SELECT * FROM users WHERE id = ?")
          .bind(url.searchParams.get("id"))
          .first();

        if (!user) {
          throw new APIError(404, "User not found", "USER_NOT_FOUND");
        }

        return new Response(JSON.stringify(user), {
          headers: { "Content-Type": "application/json" }
        });
      }

      throw new APIError(404, "Not Found", "NOT_FOUND");
    } catch (error) {
      if (error instanceof APIError) {
        return new Response(
          JSON.stringify({ error: error.message, code: error.code }),
          { status: error.status, headers: { "Content-Type": "application/json" } }
        );
      }

      console.error("Unexpected error:", error);
      return new Response(
        JSON.stringify({ error: "Internal Server Error", code: "INTERNAL_ERROR" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  }
};
```

### Database Connection Pooling

```typescript
// Cloudflare automatically handles connection pooling
// Just use env.DB.prepare() normally
// D1 manages up to 100 concurrent connections per Worker

// For batch operations, use batch():
const batch = [
  env.DB.prepare("INSERT INTO logs VALUES (?)").bind("log1"),
  env.DB.prepare("INSERT INTO logs VALUES (?)").bind("log2"),
  env.DB.prepare("INSERT INTO logs VALUES (?)").bind("log3"),
];

const results = await env.DB.batch(batch);
console.log(results);  // Array of results
```

### Background Job Pattern

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/api/process") {
      const jobId = url.searchParams.get("id");

      // Queue background task - Worker will stay alive
      ctx.waitUntil(
        (async () => {
          try {
            // Simulate long-running task
            await new Promise(resolve => setTimeout(resolve, 5000));

            // Update job status in DB
            await env.DB.prepare(
              "UPDATE jobs SET status = ? WHERE id = ?"
            ).bind("completed", jobId).run();

            // Log completion
            console.log(`Job ${jobId} completed`);
          } catch (error) {
            console.error(`Job ${jobId} failed:`, error);
            await env.DB.prepare(
              "UPDATE jobs SET status = ?, error = ? WHERE id = ?"
            ).bind("failed", String(error), jobId).run();
          }
        })()
      );

      return new Response(JSON.stringify({ jobId, status: "queued" }), {
        headers: { "Content-Type": "application/json" }
      });
    }

    return new Response("Not Found", { status: 404 });
  }
};
```

---

## Troubleshooting

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| **"Script size exceeds limit"** | Code + dependencies too large | Remove unused dependencies, use dynamic imports, consider modular Workers |
| **"Database not found"** | Wrong database_id or typo | Check `wrangler d1 list`, verify database_id in wrangler.toml |
| **"Secret not found"** | Secret not created in Cloudflare | Run `wrangler secret put SECRET_NAME`, list with `wrangler secret list` |
| **"Binding is undefined"** | Binding name mismatch in code vs config | Ensure env.DB matches `binding = "DB"` in wrangler.toml |
| **Local dev doesn't match production** | Different configuration or dependencies | Run `wrangler deploy --dry-run`, test with `wrangler dev --remote` |
| **Migrations not running** | Migrations directory missing or invalid SQL | Ensure migrations in `./migrations/` with numbered timestamps |
| **D1 queries slow in production** | N+1 queries or missing indexes | Use batch(), batch queries together, add indexes on foreign keys |

### Debug Commands

```bash
# Check wrangler version
wrangler --version

# Validate configuration syntax
npx wrangler deploy --dry-run

# Check authentication
wrangler whoami

# Test local dev with verbose output
wrangler dev --debug

# Verify all bindings are accessible
# In wrangler dev console:
// console.log(Object.keys(env))

# Check D1 status
wrangler d1 info my-database

# View real-time logs from production
wrangler tail

# Check recent deployments
wrangler deployments list
```

### Performance Optimization

```typescript
// ✅ Good: Batch multiple operations
const results = await env.DB.batch([
  env.DB.prepare("INSERT INTO logs VALUES (?)").bind("log1"),
  env.DB.prepare("INSERT INTO logs VALUES (?)").bind("log2"),
]);

// ✅ Good: Prepare once, bind multiple times
const stmt = env.DB.prepare("SELECT * FROM users WHERE id = ?");
const user1 = await stmt.bind(1).first();
const user2 = await stmt.bind(2).first();

// ❌ Avoid: N+1 queries in loops
for (const userId of userIds) {
  const user = await env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(userId).first();
  // This makes N queries!
}

// ✅ Better: Fetch all at once
const users = await env.DB.prepare(
  "SELECT * FROM users WHERE id IN (" + userIds.map(() => "?").join(",") + ")"
).bind(...userIds).all();

// ✅ Good: Use indexes for filtering
// In migration:
CREATE INDEX idx_users_email ON users(email);

// ✅ Good: Cache frequently accessed data in KV
const cachedUser = await env.MY_KV.get(`user:${userId}`);
if (cachedUser) {
  return JSON.parse(cachedUser);
}
const user = await env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(userId).first();
await env.MY_KV.put(`user:${userId}`, JSON.stringify(user), { expirationTtl: 3600 });
```

### Logging & Monitoring

```bash
# View logs in real-time
wrangler tail

# Filter logs by status
wrangler tail --status ok
wrangler tail --status error

# Search logs
wrangler tail --search "error"

# Export logs as JSON
wrangler tail --format json
```

```typescript
// Structured logging pattern
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const requestId = crypto.randomUUID();
    const startTime = Date.now();

    console.log(JSON.stringify({
      level: "INFO",
      requestId,
      method: request.method,
      url: request.url,
      timestamp: new Date().toISOString()
    }));

    try {
      const response = await handleRequest(request, env, ctx);
      const duration = Date.now() - startTime;

      console.log(JSON.stringify({
        level: "INFO",
        requestId,
        status: response.status,
        duration,
        timestamp: new Date().toISOString()
      }));

      return response;
    } catch (error) {
      const duration = Date.now() - startTime;

      console.error(JSON.stringify({
        level: "ERROR",
        requestId,
        error: String(error),
        duration,
        timestamp: new Date().toISOString()
      }));

      return new Response(
        JSON.stringify({ error: "Internal Server Error", requestId }),
        { status: 500 }
      );
    }
  }
};
```

---

## Resources & Next Steps

### Official Documentation
- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Wrangler CLI Reference](https://developers.cloudflare.com/workers/wrangler/)
- [D1 Documentation](https://developers.cloudflare.com/d1/)
- [Miniflare GitHub](https://github.com/cloudflare/workers-sdk/tree/main/packages/miniflare)

### Key Files in Source
- `/packages/wrangler/` — CLI tool
- `/packages/miniflare/` — Local simulator
- `/packages/create-cloudflare/` — Project generator
- `/packages/wrangler/templates/` — Example handlers

### Development Workflow

1. **Initialize**: `npm create cloudflare@latest`
2. **Develop**: `wrangler dev` → test locally
3. **Setup bindings**: `wrangler d1 create`, `wrangler kv namespace create`
4. **Write migrations**: Create `.sql` files in `./migrations/`
5. **Configure**: Update `wrangler.toml` with binding IDs
6. **Deploy**: `wrangler deploy`
7. **Monitor**: `wrangler tail`

### Best Practices

- **Never commit secrets** — Use `wrangler secret put`
- **Test locally first** — `wrangler dev` before deploy
- **Keep compatibility_date recent** — Use last Friday's date for latest features
- **Use migrations for schema changes** — Never ALTER in code
- **Batch D1 operations** — Use `env.DB.batch()` for multiple queries
- **Cache in KV** — Reduce D1 load with KV caching
- **Monitor logs** — Use `wrangler tail` to watch production
- **Version your API** — Use routes like `/api/v1/users`, `/api/v2/users`
- **Document bindings** — Add comments in `wrangler.toml` explaining each binding

---

**Last updated by Oracle Wiriya**: 2026-03-25
**Scope**: Complete reference for Cloudflare Workers SDK
**Audience**: Fullstack developers deploying to Cloudflare Workers
