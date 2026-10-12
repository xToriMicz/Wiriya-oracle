# Cloudflare Workers SDK Architecture

**Date**: 2026-03-25
**Scope**: Monorepo structure, core packages, D1 database system, and deployment pipeline
**Source**: github.com/cloudflare/workers-sdk (commit ~6f3e58a era)

---

## Executive Summary

The Cloudflare Workers SDK is a **monorepo** using pnpm, Turbo, and esbuild that provides:

1. **Wrangler** (CLI) — the main tool for developing, testing, and deploying Workers
2. **Miniflare** (local simulator) — runs Workers locally with full-featured bindings (D1, KV, R2, etc.)
3. **Create-Cloudflare (C3)** — scaffolding tool for new projects
4. **Supporting utilities** — shared types, plugins, frameworks, build tools

**Architecture pattern**: Plugin-based services managed by a runtime config system. D1 is implemented as a Durable Object backed by SQLite, accessed through local execution (Miniflare) or remote API calls (wrangler deploy).

---

## Directory Structure

```
workers-sdk/
├── packages/                     # Main monorepo packages
│   ├── wrangler/                 # CLI tool (primary entry point)
│   ├── miniflare/                # Local Workers simulator
│   ├── create-cloudflare/        # C3 scaffolding tool
│   ├── cli/                      # Shared CLI utilities (@cloudflare/cli)
│   ├── workers-shared/           # Shared utilities for Workers
│   ├── workers-utils/            # Common utilities
│   ├── workers-tsconfig/         # TypeScript config for Workers
│   ├── workers-editor-shared/    # Shared editor components
│   ├── pages-shared/             # Cloudflare Pages integration
│   ├── vite-plugin-cloudflare/   # Vite integration
│   ├── vitest-pool-workers/      # Vitest testing pool
│   ├── kv-asset-handler/         # KV static asset serving
│   ├── format-errors/            # Error formatting utilities
│   ├── lint-config-shared/       # Shared lint config
│   ├── chrome-devtools-patches/  # DevTools fork for Workers debugging
│   ├── unenv-preset/             # Environment polyfills
│   ├── quick-edit/               # In-browser editor
│   ├── quick-edit-extension/     # Browser extension for editors
│   └── [other utility packages]
├── tools/                        # Build & deployment scripts
│   ├── clean/                    # Cleanup utilities
│   ├── deployments/              # Validation & deployment helpers
│   ├── e2e/                      # End-to-end test runners
│   └── github-workflow-helpers/  # CI/CD utilities
├── .github/                      # GitHub Actions workflows
├── package.json                  # Root workspace config (pnpm)
├── turbo.json                    # Turbo cache config
├── CONTRIBUTING.md               # Development guide
└── README.md                     # Main overview
```

---

## Core Packages

### 1. Wrangler (packages/wrangler/)

**Purpose**: Command-line interface for building and deploying Cloudflare Workers

**Key directories**:

```
src/
├── index.ts                  # Main CLI entry point (2000+ lines)
├── api/                      # API client for Cloudflare services
│   ├── startDevWorker/       # Dev server APIs
│   ├── remoteBindings/       # Remote binding management
│   └── integrations/         # External service integrations
├── build/                    # Build process orchestration
├── deployment-bundle/        # Worker bundling for deployment
│   ├── esbuild-plugins/      # Custom esbuild plugins
│   ├── bindings.ts           # Binding serialization
│   ├── module-collection.ts  # Module dependency collection
│   └── create-worker-upload-form.ts  # Deployment form creation
├── deploy/                   # Deploy command & logic
│   ├── deploy.ts             # Core deploy implementation
│   └── index.ts              # Deploy CLI entry
├── dev/                      # Local development
│   ├── miniflare/            # Miniflare integration
│   ├── start-dev.ts          # Dev server bootstrap
│   └── get-local-persistence-path.ts  # Local storage paths
├── d1/                       # D1 database commands
│   ├── execute.ts            # SQL execution (local & remote)
│   ├── migrations/           # Schema versioning
│   │   ├── create.ts         # Create new migration
│   │   ├── apply.ts          # Apply migrations
│   │   └── helpers.ts        # Migration utilities
│   ├── timeTravel/           # Time-travel/restore functionality
│   ├── create.ts             # Create database
│   ├── delete.ts             # Delete database
│   ├── list.ts               # List databases
│   ├── info.ts               # Database info
│   ├── export.ts             # Export data
│   ├── utils.ts              # D1 helpers
│   └── types.ts              # D1 TypeScript types
├── kv/                       # KV store commands
├── r2/                       # R2 object storage commands
├── queues/                   # Queues service commands
├── durable-objects/          # Durable Objects commands
├── pages/                    # Cloudflare Pages integration
├── environments/             # Environment management
├── config/                   # Configuration parsing
│   ├── index.ts              # Main config loader
│   └── dot-env.ts            # .env file parsing
├── core/                     # Core CLI framework
│   └── create-command.ts     # Command builder utility
├── utils/                    # Shared utilities
├── type-generation/          # TypeScript type generation
└── __tests__/                # Test files (matching src structure)
```

**Key entry point**: `bin/wrangler.js` → `src/index.ts`
**Main command handler**: Uses `createCommand()` factory for CLI structure
**Build output**: esbuild bundles to `wrangler-dist/` for distribution

---

### 2. Miniflare (packages/miniflare/)

**Purpose**: Local simulator for Workers, powered by workerd (Cloudflare's actual Workers runtime in source form)

**Key directories**:

```
src/
├── index.ts                  # Main Miniflare class (2500+ lines)
│   ├── constructor           # Initialize runtime
│   ├── getD1Database()       # Get D1 binding
│   ├── getKVNamespace()      # Get KV binding
│   ├── getR2Bucket()         # Get R2 binding
│   └── dispose()             # Cleanup
├── runtime/                  # workerd config generation
│   ├── index.ts              # Config serialization
│   ├── config/               # Configuration schemas
│   │   └── generated/        # Auto-generated from capnproto
│   └── structured-logs.ts    # Log formatting
├── http/                     # HTTP handling
│   ├── fetch.ts              # Fetch implementation
│   ├── request.ts            # Request class
│   └── response.ts           # Response class
├── plugins/                  # Service implementations (D1, KV, R2, etc.)
│   ├── shared/               # Common plugin utilities
│   │   ├── index.ts          # Plugin base classes
│   │   ├── persistence.ts    # Persist path management
│   │   └── external-service.ts # External service proxying
│   ├── d1/                   # D1 plugin
│   │   └── index.ts          # D1 service registration
│   ├── kv/                   # KV plugin
│   │   ├── index.ts
│   │   ├── constants.ts
│   │   └── sites.ts          # Workers Sites support
│   ├── r2/                   # R2 plugin
│   ├── durable-objects/      # Durable Objects (DO) plugin
│   ├── do/                   # DO plugin (renamed from durable-objects)
│   ├── cache/                # Cache API plugin
│   ├── analytics-engine/     # Analytics Engine plugin
│   ├── queues/               # Queues plugin
│   ├── hyperdrive/           # Hyperdrive plugin
│   ├── workflows/            # Workflows plugin
│   ├── core/                 # Core service framework
│   │   ├── proxy/            # RPC proxy for remote services
│   │   ├── services.ts       # Service lifecycle
│   │   ├── modules.ts        # Module handling
│   │   └── error-handling    # Error propagation
│   └── [others]
├── workers/                  # Internal Worker scripts
│   ├── d1/                   # D1 database worker
│   │   ├── database.worker.ts # Durable Object implementation
│   │   └── dumpSql.ts        # SQL export logic
│   ├── kv/                   # KV namespace worker
│   ├── r2/                   # R2 bucket worker
│   ├── local-explorer/       # Local UI for dev inspection
│   │   ├── openapi.local.json
│   │   └── generated/        # OpenAPI-generated types
│   └── shared/               # Shared worker utilities
├── shared/                   # Shared utilities
│   ├── dev-registry.ts       # Worker registry for hot reload
│   ├── external-service.ts   # External service proxy setup
│   └── mime-types.ts
└── http/                     # HTTP server & WebSocket handling
```

**Plugin pattern**:

Each binding (D1, KV, R2) follows a plugin architecture:

```typescript
export const PLUGIN_NAME_PLUGIN: Plugin<OptionsSchema, SharedOptionsSchema> = {
  options: OptionsSchema,           // Zod schema for options
  sharedOptions: SharedOptionsSchema, // Shared persistence options
  getBindings(options) { ... },     // Worker_Binding[] for config
  getNodeBindings(options) { ... }, // Node.js proxy bindings
  async getServices(opts) { ... },  // Runtime Service[] with workers
  getPersistPath(shared, tmpPath) { ... } // Persistence location
}
```

**D1 specifically**:
- Uses **Durable Objects** internally for local storage
- Each D1 database = one DO with SQLite state
- Requests routed through HTTP to the DO via service mesh
- Supports migration versioning, time-travel restore, and export

---

### 3. Create-Cloudflare / C3 (packages/create-cloudflare/)

**Purpose**: Interactive scaffolding for new Workers projects

**Key components**:

```
src/
├── cli.ts              # Main CLI entry
├── templates.ts        # Project templates (Hono, Next.js, etc.)
├── frameworks/         # Framework-specific config
├── workers.ts          # Workers project setup
├── helpers/            # Project initialization helpers
├── deploy.ts           # Deployment helpers
├── event.ts            # Analytics event tracking
├── metrics.ts          # Metrics collection
└── validators.ts       # Input validation
```

**Workflow**: Interactive prompts → select framework → scaffold files → optional deploy

---

## Architecture Patterns

### Plugin System

Miniflare uses a **plugin registry** to manage all service bindings:

```typescript
// Registered in index.ts
const PLUGIN_ENTRIES = [
  [D1_PLUGIN_NAME, D1_PLUGIN],
  [KV_PLUGIN_NAME, KV_PLUGIN],
  [R2_PLUGIN_NAME, R2_PLUGIN],
  // ... etc
];

// At startup:
const plugins = PLUGIN_ENTRIES.map(([name, plugin]) =>
  createServices(plugin, userOptions)
);
```

Each plugin provides:
1. **Bindings** — Worker-side API (d1Database, kvNamespace, etc.)
2. **Services** — Runtime services (Durable Objects, HTTP handlers, etc.)
3. **Node bindings** — Node.js proxy for CLI access

---

### D1 Architecture

**D1 = SQLite-backed database via Durable Objects**

#### Local Execution Flow

```
wrangler d1 execute --local db.sql
    ↓
getDatabaseInfoFromConfig()
    ↓
new Miniflare({ d1Persist, d1Databases: { DATABASE: uuid } })
    ↓
mf.getD1Database("DATABASE")  [returns D1Database binding]
    ↓
db.batch(queries)  [sends to D1DatabaseObject via service mesh]
    ↓
D1DatabaseObject.query() [executes SQL on stored SQLite DB]
    ↓
Return D1Result[] with rows, metadata, duration
```

**Key files**:
- `packages/wrangler/src/d1/execute.ts` — Query execution logic
- `packages/miniflare/src/plugins/d1/index.ts` — Plugin registration
- `packages/miniflare/src/workers/d1/database.worker.ts` — Durable Object implementation (SQLite wrapper)

#### Remote Execution Flow

```
wrangler d1 execute --remote db.sql
    ↓
requireAuth() + getDatabaseByNameOrBinding()
    ↓
IF file:
  - MD5 hash for deduplication
  - POST /accounts/{id}/d1/database/{uuid}/import with action=init
  - Upload to R2 via signed URL
  - POST with action=ingest
  - Poll until complete via action=poll
ELSE:
  - POST /accounts/{id}/d1/database/{uuid}/query
    with { sql: "..." }
    ↓
Return QueryResult[] from API
```

**Key files**:
- `packages/wrangler/src/d1/execute.ts:executeRemotely()` — Remote logic
- `packages/wrangler/src/cfetch.ts` — API client

#### D1 Query Types

```typescript
// From execute.ts
export type QueryResult = {
  results: Record<string, string | number | boolean | null>[];
  success: boolean;
  meta?: {
    duration?: number;
  };
  query?: string;
};

// From database.worker.ts (D1DatabaseObject)
interface D1SuccessResponse {
  success: true;
  results: D1RowsAndColumns | Record<string, D1Value>[] | undefined;
  meta: {
    served_by: string;
    duration: number;
    changes: number;
    last_row_id: number;
    changed_db: boolean;
    size_after: number;
    rows_read: number;
    rows_written: number;
  };
}
```

#### Migrations System

```
wrangler d1 migrations create migration-name
    ↓ Creates: migrations/001_migration-name.sql

wrangler d1 migrations apply --local db
    ↓
packages/wrangler/src/d1/migrations/apply.ts
    ↓
Read migration files, execute via executeLocally()
    ↓
Track in Durable Object state (bookmark system)
```

**Key files**:
- `packages/wrangler/src/d1/migrations/` — All migration logic
- Uses `PRAGMA miniflare_d1_export()` for local data export

---

## Deployment Pipeline

### Build Phase

```
wrangler deploy
    ↓
1. loadConfig()  — Parse wrangler.toml
2. buildWorker() — esbuild with custom plugins
   ├── resolve Worker entry point
   ├── resolve dependencies
   ├── apply esbuild-plugins (D1 setup, etc.)
   └── output to dist/
3. bundleForDeployment()
   ├── Collect all modules
   ├── Generate capnproto config
   └── Create multipart form
```

**Key files**:
- `packages/wrangler/src/deployment-bundle/` — Bundling orchestration
- `packages/wrangler/src/deployment-bundle/esbuild-plugins/` — Custom esbuild plugins

### Upload Phase

```
createWorkerUploadForm()
    ↓
Serialize bindings, modules, metadata
    ↓
POST /accounts/{accountId}/workers/scripts/{scriptName}
    with multipart form (wasm, esm modules, metadata)
    ↓
Cloudflare API validates & stores
    ↓
Worker deployed to edge
```

**Key files**:
- `packages/wrangler/src/deployment-bundle/create-worker-upload-form.ts`
- `packages/wrangler/src/deploy/deploy.ts`

### Dev Server Phase

```
wrangler dev
    ↓
getConfig()
    ↓
startDev({ config, ... })  [in packages/wrangler/src/dev/start-dev.ts]
    ↓
new Miniflare({ modules: true, script, bindings, ... })
    ↓
Setup file watcher for hot reload
    ↓
Launch local HTTP server (usually :8787)
    ↓
On each request:
  ├── Hot reload if files changed
  ├── Dispatch to Miniflare runtime
  ├── Bindings resolve to local services
  └── Return response
```

**Key files**:
- `packages/wrangler/src/dev/start-dev.ts`
- `packages/wrangler/src/dev/miniflare/index.ts` — Miniflare config

---

## Key Abstractions & Concepts

### Config System

**File**: `packages/wrangler/src/config/`

```typescript
// wrangler.toml structure
{
  name = "my-worker"
  main = "src/index.ts"
  compatibility_date = "2024-01-01"

  [[d1_databases]]
  binding = "DB"
  database_name = "production"
  database_id = "<uuid>"

  [[kv_namespaces]]
  binding = "KV_STORE"
  id = "<uuid>"
}
```

Parsed by TypeScript, validated, and injected into Miniflare/build pipeline.

### Binding Resolution

**Three-level binding system**:

1. **Worker-side** (`src/index.ts`):
   ```typescript
   export default {
     async fetch(req, env) {
       const result = await env.DB.prepare("SELECT * FROM users").all();
       return new Response(JSON.stringify(result));
     }
   }
   ```

2. **Deployment-bundle level** (via `deployment-bundle/bindings.ts`):
   - Serializes binding config into capnproto format
   - Maps Wrangler names → runtime names

3. **Runtime level** (Miniflare plugins):
   - D1Plugin provides `D1Database` class
   - KVPlugin provides `KVNamespace` class
   - etc.

### Service Mesh Architecture

Miniflare uses **capnproto RPC** to route requests between services:

```
[Worker Code]
     ↓ (fetch to service)
[Service Mesh / Load Balancer]
     ↓ (routes to)
[D1DatabaseObject] (Durable Object)
     ↓
[SQLite State Storage]
```

Each binding is a **service** with an HTTP/RPC interface.

---

## D1 Implementation Details

### SQL Execution (database.worker.ts)

```typescript
export class D1DatabaseObject extends MiniflareDurableObject {
  #query(format: D1ResultsFormat, query: D1Query): D1SuccessResponse {
    const beforeTime = performance.now();
    const beforeSize = this.state.storage.sql.databaseSize;

    const params = convertParams(query.params ?? []);
    const cursor = this.db.prepare(query.sql)(...params);
    const columns = cursor.columnNames;
    const rows = convertRows(Array.from(cursor.raw()));

    // ... row transformation ...

    return {
      success: true,
      results,
      meta: { duration, changes, size_after, rows_read, rows_written }
    };
  }

  #txn(queries: D1Query[], format): D1SuccessResponse[] {
    return this.state.storage.transactionSync(() =>
      queries.map(this.#query.bind(this, format))
    );
  }

  @POST("/query")
  @POST("/execute")
  queryExecute = async (req) => {
    let queries = D1QueriesSchema.parse(await req.json());
    if (!Array.isArray(queries)) queries = [queries];

    if (this.#isExportPragma(queries)) {
      return this.#doExportData(queries);  // Special PRAGMA handling
    }

    return Response.json(this.#txn(queries, resultsFormat), {
      headers: {
        [D1_SESSION_COMMIT_TOKEN_HTTP_HEADER]:
          await this.state.storage.getCurrentBookmark(),
      },
    });
  };
}
```

### Persistence Model

- **Local dev**: SQLite files in `.wrangler/state/v3/d1/<database-id>/`
- **Remote**: D1 services managed by Cloudflare infrastructure
- **Migration tracking**: Durable Object state stores applied migration list + bookmarks

### Special Pragmas

```sql
-- Used by local export
PRAGMA miniflare_d1_export(noSchema, noData, ...tables);
-- Returns: full SQL dump for the database
```

---

## Dependency Graph

```
wrangler (CLI)
├── miniflare (for dev & local execution)
├── @cloudflare/cli (CLI utilities)
├── @cloudflare/workers-utils (common types)
├── esbuild (bundling)
├── yargs (CLI parsing)
├── undici (HTTP fetch)
└── chalk (colors)

miniflare
├── workerd (runtime, installed as binary)
├── @cloudflare/workers-types (TypeScript types, imported from)
└── zod (validation)

create-cloudflare
├── wrangler (for deployment)
└── framework-specific deps (vite, next, etc.)
```

---

## Build System

**Root build tool**: Turbo (monorepo orchestration)

```bash
pnpm run build        # turbo build across all packages
pnpm run dev          # turbo dev (watch mode)
pnpm run test         # turbo test (vitest)
pnpm run check:type   # TypeScript type checking
pnpm run fix          # oxlint + oxfmt fixes
```

**Per-package build**:
- **wrangler**: esbuild → `wrangler-dist/` + `miniflare-dist/`
- **miniflare**: esbuild → `dist/src/` + TypeScript declarations
- **create-cloudflare**: esbuild → `dist/`

**Tools**:
- **esbuild** — Fast bundling
- **oxlint** — Rust-based linter
- **oxfmt** — Rust-based formatter
- **vitest** — Test runner

---

## Key Files Reference

### Wrangler D1

| File | Purpose |
|------|---------|
| `packages/wrangler/src/d1/execute.ts` | SQL execution (local & remote) |
| `packages/wrangler/src/d1/utils.ts` | Database lookup & config parsing |
| `packages/wrangler/src/d1/migrations/apply.ts` | Migration application |
| `packages/wrangler/src/d1/splitter.ts` | SQL query statement splitting |
| `packages/wrangler/src/d1/timeTravel/` | Time-travel / restore features |

### Miniflare D1

| File | Purpose |
|------|---------|
| `packages/miniflare/src/plugins/d1/index.ts` | Plugin registration & config |
| `packages/miniflare/src/workers/d1/database.worker.ts` | Durable Object (SQL executor) |
| `packages/miniflare/src/workers/d1/dumpSql.ts` | SQL export/dump logic |

### Core Runtime

| File | Purpose |
|------|---------|
| `packages/miniflare/src/index.ts` | Main Miniflare class & APIs |
| `packages/miniflare/src/runtime/index.ts` | workerd config serialization |
| `packages/miniflare/src/plugins/shared/index.ts` | Plugin base classes |

### Deployment

| File | Purpose |
|------|---------|
| `packages/wrangler/src/deploy/deploy.ts` | Deploy logic |
| `packages/wrangler/src/deployment-bundle/bindings.ts` | Binding serialization |
| `packages/wrangler/src/deployment-bundle/create-worker-upload-form.ts` | Multipart form creation |

---

## Configuration Schema

### D1 in wrangler.toml

```toml
[[d1_databases]]
binding = "DB"                    # Worker-side variable name
database_name = "my-db"           # User-friendly name
database_id = "..."               # UUID from Cloudflare API

[[d1_databases]]
binding = "PREVIEW_DB"
database_name = "my-db-preview"
database_id = "..."
preview_database_id = "..."       # Separate preview DB
```

### D1 Migrations Structure

```
migrations/
├── 0001_init.sql                 # SQL statements
├── 0002_add_users_table.sql
└── ...
```

Each migration tracked in Durable Object state with timestamp.

---

## Notable Design Decisions

1. **Durable Objects for local D1**: Simplifies state management, mirrors production behavior
2. **Plugin architecture**: Easy to add new bindings (D1, R2, Queues, etc.)
3. **workerd as runtime**: Uses actual Cloudflare runtime, not Node.js compat
4. **Service mesh via capnproto**: Efficient RPC between services
5. **Miniflare CLI separate from wrangler**: Independent simulator for testing
6. **Config as TypeScript**: Type-safe, extensible configuration
7. **Remote proxy pattern**: Local and remote execution paths unified via plugin interface

---

## Quick Start for Developers

### Setting up a Workers project

```bash
# Create new project
npm create cloudflare@latest my-app
cd my-app

# Create D1 database
wrangler d1 create my-db

# Create migration
wrangler d1 migrations create init

# Apply locally
wrangler d1 migrations apply --local my-db

# Test locally
wrangler dev

# Deploy
wrangler deploy
```

### Using D1 in Worker

```typescript
export default {
  async fetch(request, env) {
    const { results } = await env.DB.prepare(
      'SELECT * FROM users WHERE id = ?'
    ).bind(123).first();
    return Response.json(results);
  }
};
```

---

## References

- **Miniflare docs**: https://miniflare.dev
- **Wrangler docs**: https://developers.cloudflare.com/workers/wrangler/
- **D1 docs**: https://developers.cloudflare.com/d1/
- **Workers guide**: https://developers.cloudflare.com/workers/
- **workerd source**: https://github.com/cloudflare/workerd
