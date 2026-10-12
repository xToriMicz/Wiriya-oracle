# Cloudflare Workers SDK — Code Snippets & Patterns
**Study Date**: 2026-03-25
**Source**: `/Users/angkana/ghq/github.com/cloudflare/workers-sdk/`

---

## 1. Worker Entry Point — Basic Structure

### Pattern: Module Syntax with Fetch Handler

**File**: `packages/miniflare/src/workers/core/entry.worker.ts`

The most common Worker pattern uses the module syntax with an exported handler object containing `fetch()`, `scheduled()`, and `email()` methods.

```typescript
export default <ExportedHandler<Env>>{
  async fetch(request, env, ctx) {
    const startTime = Date.now();

    try {
      // Parse incoming request
      const url = new URL(request.url);

      // Get target service based on URL/routing
      const service = getTargetService(request, url, env);
      if (service === undefined) {
        return new Response("No entrypoint worker found", { status: 404 });
      }

      // Call service and handle response
      let response = await service.fetch(request);

      // Post-processing: prettify errors, inject live reload, etc.
      response = await maybePrettifyError(request, response, env);
      response = maybeInjectLiveReload(response, env, ctx);
      response = ensureAcceptableEncoding(clientAcceptEncoding, response);

      if (env[CoreBindings.LOG_REQUESTS]) {
        response = maybeLogRequest(request, response, env, ctx, startTime);
      }

      return response;
    } catch (e: any) {
      return new Response(e?.stack ?? String(e), { status: 500 });
    }
  },
};
```

**Key Points**:
- Export object with `async fetch(request, env, ctx)` handler
- `request`: Incoming HTTP Request
- `env`: Environment variables, bindings (KV, D1, R2, Durable Objects)
- `ctx`: ExecutionContext (for `waitUntil()`, `passThroughOnException()`)
- Always wrap in try-catch for error handling
- Use `Response` class for HTTP responses

---

### Pattern: Type Safety with Environment Interface

**File**: `packages/miniflare/src/workers/core/entry.worker.ts` (lines 20-39)

Define an `Env` interface for type-safe access to bindings:

```typescript
type Env = {
  [CoreBindings.SERVICE_LOOPBACK]: Fetcher;
  [CoreBindings.SERVICE_USER_FALLBACK]: Fetcher;
  [CoreBindings.SERVICE_LOCAL_EXPLORER]: Fetcher;
  [CoreBindings.TEXT_CUSTOM_SERVICE]: string;
  [CoreBindings.TEXT_UPSTREAM_URL]?: string;
  [CoreBindings.JSON_CF_BLOB]: IncomingRequestCfProperties;
  [CoreBindings.JSON_ROUTES]: WorkerRoute[];
  [CoreBindings.JSON_LOG_LEVEL]: LogLevel;
  // ... more bindings
};
```

This pattern allows TypeScript to enforce type safety when accessing `env.BINDING_NAME`.

---

## 2. D1 Database Usage — Query Patterns

### Pattern: Prepared Statements & Transactions

**File**: `packages/miniflare/src/workers/d1/database.worker.ts` (lines 121-205)

D1 queries use prepared statements and support batch transactions:

```typescript
// Single query execution
const query = (format: D1ResultsFormat, query: D1Query): D1SuccessResponse => {
  const beforeTime = performance.now();
  const beforeSize = this.state.storage.sql.databaseSize;

  // Prepare statement with parameters (safe from SQL injection)
  const params = convertParams(query.params ?? []);
  const cursor = this.db.prepare(query.sql)(...params);

  // Get column names and raw rows
  const columns = cursor.columnNames;
  const rows = convertRows(Array.from(cursor.raw()));

  // Format results based on requested format
  let results = undefined;
  if (format === "ROWS_AND_COLUMNS") {
    results = { columns, rows };
  } else {
    results = rowsToObjects(columns, rows);  // [{col: val}, ...]
  }

  // Track metrics
  const afterTime = performance.now();
  const duration = afterTime - beforeTime;
  const changes = afterChanges.totalChanges - beforeChanges.totalChanges;

  return {
    success: true,
    results,
    meta: {
      served_by: "miniflare.db",
      duration,
      changes,
      last_row_id: afterChanges.lastRowId,
      changed_db: changed,
      size_after: afterSize,
      rows_read: cursor.rowsRead,
      rows_written: cursor.rowsWritten,
    },
  };
};
```

### Pattern: Transaction Batch Operations

```typescript
#txn(queries: D1Query[], format: D1ResultsFormat): D1SuccessResponse[] {
  // Filter out comment-only queries
  queries = queries.filter(
    (query) => query.sql.replace(/^\s+--.*/gm, "").trim().length > 0
  );

  if (queries.length === 0) {
    throw new D1Error(new Error("No SQL statements detected."));
  }

  try {
    // Execute multiple queries in a transaction
    return this.state.storage.transactionSync(() =>
      queries.map(this.#query.bind(this, format))
    );
  } catch (e) {
    throw new D1Error(e);
  }
}
```

### Pattern: Using D1 in a Worker

**File**: `packages/fixtures/worker-with-resources/src/index.ts` (lines 43-50)

```typescript
// In your worker
async fetch(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);

  if (url.pathname === "/d1") {
    // Execute SQL
    await env.DB.exec(`
      DROP TABLE IF EXISTS users;
      CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
      INSERT INTO users (id, name) VALUES (1, 'Alice'), (2, 'Bob');
    `);
    return new Response("OK");
  }
}
```

### Pattern: Query Response Format

D1 responses follow this schema:

```typescript
interface D1SuccessResponse {
  success: true;
  results: D1RowsAndColumns | Record<string, D1Value>[] | undefined;
  meta: {
    served_by: string;           // "miniflare.db"
    duration: number;            // milliseconds
    changes: number;             // rows affected
    last_row_id: number;         // for INSERT
    changed_db: boolean;         // was DB modified
    size_after: number;          // DB size after query
    rows_read: number;           // optimization metrics
    rows_written: number;        // optimization metrics
  };
}

interface D1FailureResponse {
  success: false;
  error: string;
}
```

---

## 3. KV Storage — Read/Write Patterns

### Pattern: Basic Get/Put/Delete

**File**: `packages/miniflare/src/workers/kv/namespace.worker.ts` (lines 125-289)

```typescript
export class KVNamespaceObject extends MiniflareDurableObject {
  #storage?: KeyValueStorage;
  get storage() {
    // Lazy-initialize storage
    return (this.#storage ??= new KeyValueStorage(this));
  }

  // GET operation
  @GET("/:key")
  @POST("/bulk/get")
  get: RouteHandler<KVParams> = async (req, params, url) => {
    // Single key get
    const key = decodeKey(params, url.searchParams);
    validateGetOptions(key, { cacheTtl });

    const entry = await this.storage.get(key);
    if (entry === null) throw new HttpError(404, "Not Found");

    // Build response with metadata
    const headers = new Headers();
    if (entry.expiration !== undefined) {
      headers.set("cf-cache-expires", millisToSeconds(entry.expiration).toString());
    }
    if (entry.metadata !== undefined) {
      headers.set("cf-kv-metadata", JSON.stringify(entry.metadata));
    }

    return new Response(entry.value, { headers });
  };

  // PUT operation with expiration
  @PUT("/:key")
  put: RouteHandler<KVParams> = async (req, params, url) => {
    const key = decodeKey(params, url.searchParams);
    const rawExpiration = url.searchParams.get("expiration");
    const rawExpirationTtl = url.searchParams.get("expiration_ttl");
    const rawMetadata = req.headers.get("cf-kv-metadata");

    // Validate options
    const { expiration, metadata } = validatePutOptions(key, {
      now: millisToSeconds(this.timers.now()),
      rawExpiration,
      rawExpirationTtl,
      rawMetadata,
    });

    // Get value size
    let value = req.body;
    const contentLength = parseInt(req.headers.get("Content-Length")!);
    let valueLengthHint: number | undefined;

    if (!Number.isNaN(contentLength)) {
      valueLengthHint = contentLength;
    } else if (value === null) {
      valueLengthHint = 0;
    }

    // Validate max value size (25 MB or test limit)
    const maxValueSize = this.beingTested
      ? KVLimits.MAX_VALUE_SIZE_TEST_BYTES
      : KVLimits.MAX_VALUE_SIZE_BYTES;

    if (valueLengthHint !== undefined && valueLengthHint > maxValueSize) {
      throw new HttpError(
        413,
        `Value length of ${valueLengthHint} exceeds limit of ${maxValueSize}.`
      );
    }

    // Put into storage with metadata
    await this.storage.put({
      key,
      value,
      expiration: maybeApply(secondsToMillis, expiration),
      metadata,
      signal: maxLengthStream?.signal,
    });

    return new Response();
  };

  // DELETE operation
  @DELETE("/:key")
  delete: RouteHandler<KVParams> = async (req, params, url) => {
    const key = decodeKey(params, url.searchParams);
    validateKey(key);

    await this.storage.delete(key);
    return new Response();
  };

  // LIST operation
  @GET("/")
  list: RouteHandler = async (req, params, url) => {
    const options = decodeListOptions(url);
    validateListOptions(options);

    const res = await this.storage.list(options);
    const keys = res.keys.map<KVNamespaceListKey<unknown>>((key) => ({
      name: key.key,
      expiration: maybeApply(millisToSeconds, key.expiration),
      metadata: maybeApply(JSON.stringify, key.metadata),
    }));

    let result: KVNamespaceListResult<unknown>;
    if (res.cursor === undefined) {
      result = { keys, list_complete: true, cacheStatus: null };
    } else {
      result = {
        keys,
        list_complete: false,
        cursor: res.cursor,
        cacheStatus: null,
      };
    }

    return Response.json(result);
  };
}
```

### Pattern: Stream-Based Value Size Validation

```typescript
class MaxLengthStream extends TransformStream<Uint8Array, Uint8Array> {
  readonly signal: AbortSignal;
  readonly length: Promise<number>;

  constructor(maxLength: number) {
    const abortController = new AbortController();
    const lengthPromise = new DeferredPromise<number>();

    let length = 0;
    super({
      transform(chunk, controller) {
        length += chunk.byteLength;
        // If we exceeded max, don't enqueue but don't error immediately
        if (length <= maxLength) {
          controller.enqueue(chunk);
        } else if (!abortController.signal.aborted) {
          abortController.abort();
        }
      },
      flush() {
        // Resolve with final length (may exceed max)
        lengthPromise.resolve(length);
      },
    });

    this.signal = abortController.signal;
    this.length = lengthPromise;
  }
}
```

### Pattern: Bulk Get Operation

```typescript
@POST("/bulk/get")
get: RouteHandler<KVParams> = async (req, params, url) => {
  if (req.method === "POST" && req.body != null) {
    const decodedBody = await readBodyAsText(req.body);
    const parsedBody = JSON.parse(decodedBody);
    const keys: string[] = parsedBody.keys;
    const type = parsedBody?.type;  // "text" or "json"

    // Validate
    if (keys.length > MAX_BULK_GET_KEYS) {  // e.g., 10,000
      throw new HttpError(400, `Max ${MAX_BULK_GET_KEYS} keys per request`);
    }

    // Fetch all keys
    const obj: { [key: string]: any } = {};
    let totalBytes = 0;

    for (const key of keys) {
      validateGetOptions(key, { cacheTtl: parsedBody?.cacheTtl });
      const entry = await this.storage.get(key);
      const [value, size] = await processKeyValue(
        entry,
        parsedBody?.type,
        parsedBody?.withMetadata
      );
      totalBytes += size;
      obj[key] = value;
    }

    // Check total size limit
    const maxValueSize = this.beingTested
      ? KVLimits.MAX_VALUE_SIZE_TEST_BYTES
      : KVLimits.MAX_BULK_SIZE_BYTES;

    if (totalBytes > maxValueSize) {
      throw new HttpError(413, `Total size exceeds limit`);
    }

    return new Response(JSON.stringify(obj));
  }
};
```

---

## 4. R2 Object Storage — Upload/Download Patterns

### Pattern: R2 Object Metadata & Encoding

**File**: `packages/miniflare/src/workers/r2/r2Object.worker.ts`

```typescript
export class InternalR2Object {
  readonly key: string;
  readonly version: string;
  readonly size: number;
  readonly etag: string;
  readonly uploaded: number;
  readonly httpMetadata: R2HttpFields;
  readonly customMetadata: Record<string, string>;
  readonly range?: R2Range;
  readonly checksums: R2StringChecksums;

  constructor(row: Omit<ObjectRow, "blob_id">, range?: R2Range) {
    this.key = row.key;
    this.version = row.version;
    this.size = row.size;
    this.etag = row.etag;
    this.uploaded = row.uploaded;
    this.httpMetadata = JSON.parse(row.http_metadata);
    this.customMetadata = JSON.parse(row.custom_metadata);
    this.range = range;

    // MD5 checksum stored in etag for non-multipart
    const checksums: R2StringChecksums = JSON.parse(row.checksums);
    if (this.etag.length === 32 && HEX_REGEXP.test(this.etag)) {
      checksums.md5 = row.etag;
    }
    this.checksums = checksums;
  }

  // Encode for return to Workers runtime
  #rawProperties(): R2HeadResponse {
    return {
      name: this.key,
      version: this.version,
      size: this.size,
      etag: this.etag,
      uploaded: this.uploaded,
      httpFields: this.httpMetadata,
      customFields: Object.entries(this.customMetadata).map(([k, v]) => ({
        k,
        v,
      })),
      range: this.range,
      checksums: {
        0: this.checksums.md5,
        1: this.checksums.sha1,
        2: this.checksums.sha256,
        3: this.checksums.sha384,
        4: this.checksums.sha512,
      },
    };
  }

  encode(): EncodedMetadata {
    const json = JSON.stringify(this.#rawProperties());
    const blob = new Blob([json]);
    return {
      metadataSize: blob.size,
      value: blob.stream(),
      size: blob.size
    };
  }
}

export class InternalR2ObjectBody extends InternalR2Object {
  constructor(
    metadata: Omit<ObjectRow, "blob_id">,
    readonly body: ReadableStream<Uint8Array>,
    range?: R2Range
  ) {
    super(metadata, range);
  }

  // Encode metadata + body for streaming response
  encode(): EncodedMetadata {
    const { metadataSize, value: metadata } = super.encode();
    const size = this.range?.length ?? this.size;
    const identity = new FixedLengthStream(size + metadataSize);

    // Pipeline: metadata → body
    void metadata
      .pipeTo(identity.writable, { preventClose: true })
      .then(() => this.body.pipeTo(identity.writable));

    return {
      metadataSize: metadataSize,
      value: identity.readable,
      size,
    };
  }
}
```

### Pattern: R2 Usage in Worker

**File**: `packages/fixtures/worker-with-resources/src/index.ts` (lines 29-40)

```typescript
async fetch(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);

  switch (url.pathname) {
    case "/r2/seed": {
      await Promise.all(
        R2_SEED_DATA.map(({ key, content, contentType, customMetadata }) =>
          env.BUCKET.put(key, content, {
            httpMetadata: { contentType },
            customMetadata,
          })
        )
      );
      return new Response(`Seeded ${R2_SEED_DATA.length} R2 objects`);
    }
  }
}

interface R2SeedItem {
  key: string;
  content: string | ArrayBuffer;
  contentType: string;
  customMetadata?: Record<string, string>;
}

const R2_SEED_DATA: R2SeedItem[] = [
  {
    key: "readme.txt",
    content: "Welcome to R2!",
    contentType: "text/plain",
  },
  {
    key: "config.json",
    content: JSON.stringify({ version: "1.0.0" }, null, 2),
    contentType: "application/json",
    customMetadata: { author: "admin", created: "2025-01-15" },
  },
  {
    key: "documents/report.txt",
    content: "Annual Report 2024\n\nMetrics here...",
    contentType: "text/plain",
    customMetadata: { department: "finance", year: "2024" },
  },
];
```

### Pattern: R2 List Response

```typescript
interface InternalR2Objects {
  // Array of objects matching the list request
  objects: InternalR2Object[];
  // Indicates if there are more results
  truncated: boolean;
  // Token to resume from this point (only if truncated)
  cursor?: string;
  // Prefixes between specified prefix and delimiter
  // e.g., if delimiter="/" and you list "foo/bar/baz",
  // returns "foo" as a delimited prefix
  delimitedPrefixes: string[];
}
```

---

## 5. Wrangler CLI & Deploy — Command Structure

### Pattern: Deploy Command Entry Point

**File**: `packages/wrangler/src/deploy/deploy.ts` (lines 1-145)

The deploy command is the core of the Wrangler CLI:

```typescript
type DeployProps = {
  config: Config;
  accountId: string | undefined;
  entry: Entry;
  rules: Config["rules"];
  name: string;
  env: string | undefined;
  compatibilityDate: string | undefined;
  compatibilityFlags: string[] | undefined;
  legacyAssetPaths: LegacyAssetPaths | undefined;
  assetsOptions: AssetsOptions | undefined;
  vars: Record<string, string> | undefined;
  defines: Record<string, string> | undefined;
  alias: Record<string, string> | undefined;
  triggers: string[] | undefined;
  routes: string[] | undefined;
  domains: string[] | undefined;
  useServiceEnvironments: boolean | undefined;
  jsxFactory: string | undefined;
  jsxFragment: string | undefined;
  tsconfig: string | undefined;
  isWorkersSite: boolean;
  minify: boolean | undefined;
  outDir: string | undefined;
  outFile: string | undefined;
  dryRun: boolean | undefined;
  noBundle: boolean | undefined;
  keepVars: boolean | undefined;
  logpush: boolean | undefined;
  uploadSourceMaps: boolean | undefined;
  oldAssetTtl: number | undefined;
  projectRoot: string | undefined;
  dispatchNamespace: string | undefined;
  experimentalAutoCreate: boolean;
  metafile: string | boolean | undefined;
  containersRollout: "immediate" | "gradual" | undefined;
  strict: boolean | undefined;
  tag: string | undefined;
  message: string | undefined;
  secretsFile: string | undefined;
};

export async function deploy(props: DeployProps): Promise<void> {
  // 1. Bundle worker code
  const bundle = await bundleWorker(props);

  // 2. Get bindings (KV, D1, R2, Durable Objects)
  const bindings = await getBindings(props);

  // 3. Provision bindings if needed
  await provisionBindings(bindings);

  // 4. Create upload form with metadata
  const form = await createWorkerUploadForm(bundle, bindings);

  // 5. Handle assets (Workers Sites)
  if (props.isWorkersSite) {
    const manifest = await buildAssetManifest(props);
    await syncAssets(manifest);
  }

  // 6. Handle migrations (D1)
  const migrations = await getMigrationsToUpload(props);

  // 7. Deploy to Cloudflare API
  const response = await fetchResult(
    `/accounts/${props.accountId}/workers/scripts/${props.name}`,
    {
      method: "PUT",
      body: form
    }
  );

  // 8. Verify deployment
  if (props.dryRun) {
    console.log("Dry run completed successfully");
  } else {
    console.log(`Deployed to ${props.name}`);
  }
}
```

### Pattern: Bundle Worker Code

The bundler uses esbuild internally:

```typescript
async function bundleWorker(props: DeployProps) {
  const bundle = await bundleWorker({
    name: props.name,
    entry: props.entry,
    minify: props.minify,
    noBundle: props.noBundle,
    jsxFactory: props.jsxFactory,
    tsconfig: props.tsconfig,
    rules: props.rules,
  });

  return bundle;  // { code: string, map: string }
}
```

### Pattern: CLI Main Entry

**File**: `packages/wrangler/src/cli.ts`

```typescript
/**
 * Main CLI entrypoint - only runs when script is executed directly
 */
if (typeof vitest === "undefined" && require.main === module) {
  main(hideBin(process.argv)).catch((e) => {
    // Error logging handled in yargs.fail() handler
    // Just ensure non-zero exit code
    const exitCode = (e instanceof FatalError && e.code) || 1;
    process.exit(exitCode);
  });
}

// Public API exports for programmatic use
export {
  unstable_dev,
  unstable_pages,
  DevEnv as unstable_DevEnv,
  startWorker as unstable_startWorker,
  getPlatformProxy,
  unstable_getMiniflareWorkerOptions,
};

export type {
  Unstable_DevWorker,
  Unstable_DevOptions,
  Unstable_Config,
};
```

---

## 6. Miniflare Local Development — Setup & Usage

### Pattern: Miniflare Instance Creation

**File**: `packages/miniflare/src/index.ts` (lines 1-100)

Miniflare provides local Workers runtime simulation:

```typescript
import { Miniflare } from "miniflare";

// Setup Miniflare for local dev
const miniflare = new Miniflare({
  // Basic config
  scriptPath: "src/index.ts",
  name: "my-worker",

  // Bindings
  bindings: {
    // Environment variables
    MY_VAR: "value",
  },
  kvNamespaces: ["CACHE"],
  r2Buckets: ["DATA"],

  // D1 database
  d1Databases: {
    DB: {
      filename: ":memory:",  // or path to .db file
    },
  },

  // Durable Objects
  durableObjects: {
    DO: "MyDurableObject",
  },

  // Development options
  local: true,
  verbose: true,
  logLevel: "debug",
  persist: ".wrangler/state",  // Persist between runs

  // Compatibility
  compatibilityDate: "2024-01-01",
});

// Make a request
const response = await miniflare.dispatchFetch("http://localhost/api");
const text = await response.text();

// Cleanup
await miniflare.dispose();
```

### Pattern: Core Entry Worker Structure

**File**: `packages/miniflare/src/workers/core/entry.worker.ts`

The entry worker handles routing, error formatting, and live reload injection:

```typescript
// Process incoming request
function getUserRequest(
  request: Request<unknown, IncomingRequestCfProperties>,
  env: Env,
  clientIp: string | undefined
) {
  // 1. Extract original URL from header (if proxied)
  const originalUrl = request.headers.get(CoreHeaders.ORIGINAL_URL);
  let url = new URL(originalUrl ?? request.url);

  // 2. Handle upstream override
  const upstreamUrl = env[CoreBindings.TEXT_UPSTREAM_URL];
  if (upstreamUrl !== undefined) {
    let path = url.pathname + url.search;
    if (path.startsWith("/")) path = `./${path.substring(1)}`;
    url = new URL(path, upstreamUrl);
  }

  // 3. Recreate request with modified URL
  request = new Request(url, request);

  // 4. Set Accept-Encoding (always br, gzip in Workers)
  request.headers.set("Accept-Encoding", "br, gzip");

  // 5. Set client IP
  if (clientIp && !request.headers.get("CF-Connecting-IP")) {
    const ip = extractIp(clientIp);
    if (ip) {
      request.headers.set("CF-Connecting-IP", ip);
    }
  }

  return request;
}

// Route request to appropriate service
function getTargetService(request: Request, url: URL, env: Env) {
  let service: Fetcher | undefined = env[CoreBindings.SERVICE_USER_FALLBACK];

  const override = request.headers.get(CoreHeaders.ROUTE_OVERRIDE);
  request.headers.delete(CoreHeaders.ROUTE_OVERRIDE);

  const route = override ?? matchRoutes(env[CoreBindings.JSON_ROUTES], url);
  if (route !== null) {
    service = env[`${CoreBindings.SERVICE_USER_ROUTE_PREFIX}${route}`];
  }

  return service;
}
```

---

## 7. Error Handling — Patterns & Types

### Pattern: Custom Error Classes

**File**: `packages/miniflare/src/shared/error.ts`

Miniflare uses custom error classes to distinguish user errors from system errors:

```typescript
export const USER_ERROR_CODES = new Set([
  "ERR_ADDRESS_IN_USE",
  "ERR_DISPOSED",
  "ERR_MODULE_PARSE",
  "ERR_VALIDATION",
  "ERR_DUPLICATE_NAME",
  "ERR_DIFFERENT_STORAGE_BACKEND",
  "ERR_NO_WORKERS",
  // ... 10+ more
] as const);

export const SYSTEM_ERROR_CODES = new Set([
  "ERR_RUNTIME_FAILURE",
  "ERR_CYCLIC",
  "ERR_PLUGIN_LOADING_FAILED",
] as const);

export class MiniflareError<Code extends string = string> extends Error {
  constructor(
    readonly code: Code,
    message?: string,
    readonly cause?: Error
  ) {
    super(message);
    // Restore prototype chain for instanceof checks
    Object.setPrototypeOf(this, new.target.prototype);
    this.name = `${new.target.name} [${code}]`;
  }

  isUserError() {
    return USER_ERROR_CODES.has(this.code as any);
  }

  isSystemError() {
    return SYSTEM_ERROR_CODES.has(this.code as any);
  }
}

export class MiniflareCoreError extends MiniflareError<MiniflareCoreErrorCode> {}
```

### Pattern: D1 Error Handling

**File**: `packages/miniflare/src/workers/d1/database.worker.ts` (lines 72-88)

```typescript
export class D1Error extends HttpError {
  constructor(readonly cause: unknown) {
    super(500);
  }

  toResponse(): Response {
    // Extract error message from various error types
    const error =
      typeof this.cause === "object" &&
      this.cause !== null &&
      "message" in this.cause &&
      typeof this.cause.message === "string"
        ? this.cause.message
        : String(this.cause);

    const response: D1FailureResponse = { success: false, error };
    return Response.json(response);
  }
}

// Usage in transaction handler
#txn(queries: D1Query[], format: D1ResultsFormat): D1SuccessResponse[] {
  queries = queries.filter(q => q.sql.replace(/^\s+--.*/gm, "").trim().length > 0);

  if (queries.length === 0) {
    const error = new Error("No SQL statements detected.");
    throw new D1Error(error);
  }

  try {
    return this.state.storage.transactionSync(() =>
      queries.map(this.#query.bind(this, format))
    );
  } catch (e) {
    throw new D1Error(e);
  }
}
```

### Pattern: Queues Error Handling

**File**: `packages/miniflare/src/plugins/queues/errors.ts`

```typescript
export type QueuesErrorCode =
  | "ERR_MULTIPLE_CONSUMERS"    // Multiple consumers for one queue
  | "ERR_DEAD_LETTER_QUEUE_CYCLE";  // Dead letter queue points to self

export class QueuesError extends MiniflareError<QueuesErrorCode> {}
```

### Pattern: Error Handling in Worker

**File**: `packages/fixtures/secrets-store/src/index.ts`

```typescript
export default {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext
  ): Promise<Response> {
    try {
      const value = await env.SECRET.get();
      return new Response(value);
    } catch (e) {
      // Extract error message safely
      return new Response(
        e instanceof Error ? e.message : "Something went wrong",
        { status: 404 }
      );
    }
  },
};
```

---

## 8. TypeScript Types — Key Definitions

### Pattern: Handler Types

```typescript
// The main export for a Worker
export interface ExportedHandler<Env = unknown> {
  fetch?: (request: Request, env: Env, ctx: ExecutionContext) => Response | Promise<Response>;
  scheduled?: (event: ScheduledEvent, env: Env, ctx: ExecutionContext) => void | Promise<void>;
  email?: (message: EmailMessage, env: Env, ctx: ExecutionContext) => void | Promise<void>;
  queue?: (batch: MessageBatch<unknown>, env: Env, ctx: ExecutionContext) => void | Promise<void>;
  trace?: (traces: TraceItem[], env: Env, ctx: ExecutionContext) => void | Promise<void>;
}

// Durable Object handler
export interface DurableObject {
  fetch(request: Request): Response | Promise<Response>;
  alarm?(): void | Promise<void>;
}

// Route handler (internal to Miniflare)
export type RouteHandler<Params = any> = (
  req: Request,
  params: Params,
  url: URL
) => Response | Promise<Response>;
```

### Pattern: Environment Type Safety

```typescript
interface Env {
  // Secrets (read-only strings)
  SECRET: string;

  // KV Namespace
  CACHE: KVNamespace;

  // D1 Database
  DB: D1Database;

  // R2 Bucket
  BUCKET: R2Bucket;

  // Durable Object
  DO: DurableObjectNamespace;

  // Queues
  QUEUE: Queue<Message>;

  // Service bindings (Fetcher)
  API: Fetcher;

  // Environment variables
  API_KEY: string;
  DEBUG: boolean;
}
```

### Pattern: D1 Query Types

```typescript
interface D1Query {
  sql: string;
  params?: (string | number | null | number[])[] | null;
}

type D1Value = number | string | null | number[];

interface D1RowsAndColumns {
  columns: string[];
  rows: D1Value[][];
}

type D1Results = D1RowsAndColumns | Record<string, D1Value>[] | undefined;

interface D1SuccessResponse {
  success: true;
  results: D1Results;
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

---

## 9. Request/Response Handling — Edge Cases

### Pattern: Accept-Encoding Negotiation

**File**: `packages/miniflare/src/workers/core/entry.worker.ts` (lines 301-391)

Workers always send "br, gzip" but may receive other preferences:

```typescript
// RFC 9110 compliant encoding negotiation
const acceptEncodingElement = /^(?<coding>[a-z]+|\*)(?:\s*;\s*q=(?<weight>\d+(?:.\d+)?))?$/;

interface AcceptedEncoding {
  coding: string;
  weight: number;
}

function parseAcceptEncoding(header: string): AcceptedEncoding[] {
  const encodings: AcceptedEncoding[] = [];
  for (const element of header.split(",")) {
    const match = acceptEncodingElement.exec(element.trim());
    if (match?.groups == null) continue;
    encodings.push({
      coding: match.groups.coding,
      weight: match.groups.weight === undefined ? 1 : parseFloat(match.groups.weight),
    });
  }
  // Sort by weight (highest first), preserve original order for ties
  return encodings.sort((a, b) => b.weight - a.weight);
}

function ensureAcceptableEncoding(
  clientAcceptEncoding: string | null,
  response: Response
): Response {
  if (clientAcceptEncoding === null) return response;
  const encodings = parseAcceptEncoding(clientAcceptEncoding);
  if (encodings.length === 0) return response;

  const contentEncoding = response.headers.get("Content-Encoding");
  const contentType = response.headers.get("Content-Type");

  // Check if Cloudflare FL would compress this MIME type
  if (!isCompressedByCloudflareFL(contentType)) {
    return response;
  }

  // Find acceptable encoding
  let desiredEncoding: "gzip" | "br" | undefined;
  let identityDisallowed = false;

  for (const encoding of encodings) {
    if (encoding.weight === 0) {
      // q=0 means not acceptable
      if (encoding.coding === "identity" || encoding.coding === "*") {
        identityDisallowed = true;
      }
    } else if (encoding.coding === "gzip" || encoding.coding === "br") {
      desiredEncoding = encoding.coding;
      break;
    } else if (encoding.coding === "identity") {
      break;
    }
  }

  // Return 415 if no acceptable encoding available
  if (desiredEncoding === undefined && identityDisallowed) {
    return new Response("Unsupported Media Type", {
      status: 415,
      headers: { "Accept-Encoding": "br, gzip" },
    });
  }

  // Otherwise, set or remove Content-Encoding as needed
  if (desiredEncoding === undefined) {
    if (contentEncoding === null) return response;
    response = new Response(response.body, response);
    response.headers.delete("Content-Encoding");
  } else {
    if (contentEncoding === desiredEncoding) return response;
    response = new Response(response.body, response);
    response.headers.set("Content-Encoding", desiredEncoding);
  }

  return response;
}
```

### Pattern: Request Body Streaming

**File**: `packages/miniflare/src/workers/kv/namespace.worker.ts` (lines 127-135)

Reading request body in chunks:

```typescript
let decodedBody = "";
const decoder = new TextDecoder();

// Stream reading pattern
for await (const chunk of req.body) {
  decodedBody += decoder.decode(chunk, { stream: true });
}
// Flush decoder to get remaining bytes
decodedBody += decoder.decode();

const parsedBody = JSON.parse(decodedBody);
```

---

## 10. Platform Proxy & RPC — Advanced Patterns

### Pattern: Proxy Serialization with Devalue

**File**: `packages/miniflare/src/workers/core/proxy.worker.ts` (lines 1-100)

Platform proxy uses devalue for serialization across service boundaries:

```typescript
const WORKERS_PLATFORM_IMPL: PlatformImpl<ReadableStream> = {
  Blob,
  File,
  Headers,
  Request,
  Response,

  // Handle ReadableStream serialization
  isReadableStream(value): value is ReadableStream {
    return value instanceof ReadableStream;
  },

  // Convert stream to ArrayBuffer for transport
  bufferReadableStream(stream) {
    return new Response(stream).arrayBuffer();
  },

  // Restore stream from ArrayBuffer
  unbufferReadableStream(buffer) {
    const body = new Response(buffer).body;
    assert(body !== null);
    return body;
  },
};

// Reducers convert values to serializable form
const reducers: ReducersRevivers = {
  ...structuredSerializableReducers,
  ...createHTTPReducers(WORKERS_PLATFORM_IMPL),
  Native: (value) => {
    // For C++ runtime classes, store on heap instead
    const type = getType(value);
    if (((type === "Object" || isInternal(value)) && !isPlainObject(value)) ||
        type === "Promise") {
      const address = this.nextHeapAddress++;
      this.heap.set(address, value);
      return [address, value?.constructor.name, value instanceof __MiniflareFunctionWrapper];
    }
  },
};

// Revivers restore values from serializable form
const revivers: ReducersRevivers = {
  ...structuredSerializableRevivers,
  ...createHTTPRevivers(WORKERS_PLATFORM_IMPL),
  Native: (value) => {
    assert(Array.isArray(value));
    const [address] = value;
    assert(typeof address === "number");
    const heapValue = this.heap.get(address);
    // Remove Promises immediately after use
    if (heapValue instanceof Promise) this.heap.delete(address);
    return heapValue;
  },
};
```

### Pattern: Proxy Operation Handling

```typescript
// Three main RPC operations

// GET: Access property
if (opHeader === ProxyOps.GET) {
  result = keyHeader === null ? target : target[keyHeader];
  if (result?.constructor.name === "RpcProperty") result = await result;
  if (typeof result === "function") {
    return new Response(null, {
      status: 204,
      headers: { [CoreHeaders.OP_RESULT_TYPE]: "Function" },
    });
  }
}

// CALL: Call method
else if (opHeader === ProxyOps.CALL) {
  const func = target[keyHeader];
  assert(typeof func === "function");

  // Special handling for Fetcher.fetch()
  if (isFetcherFetch(targetName, keyHeader)) {
    const originalUrl = request.headers.get(CoreHeaders.ORIGINAL_URL);
    const url = new URL(originalUrl ?? request.url);
    request = new Request(url, request);
    // Clean headers before forwarding
    request.headers.delete(CoreHeaders.OP_SECRET);
    request.headers.delete(CoreHeaders.OP);
    return func.call(target, request);
  }

  // Parse arguments
  let args: unknown;
  if (argsSizeHeader === null || argsSizeHeader === contentLengthHeader) {
    args = parseWithReadableStreams(WORKERS_PLATFORM_IMPL, { value: await request.text() }, this.revivers);
  } else {
    // Handle unbuffered stream argument
    const argsSize = parseInt(argsSizeHeader);
    const [encodedArgs, rest] = await readPrefix(request.body, argsSize);
    args = parseWithReadableStreams(WORKERS_PLATFORM_IMPL, { value: stringifiedArgs, unbufferedStream: rest }, this.revivers);
  }

  try {
    result = func.apply(target, args);
  } catch (e) {
    status = 500;
    result = e;
  }
}

// Handle async results
if (allowAsync && (result instanceof Promise || rpcAwaited)) {
  try {
    result = await result;
  } catch (e) {
    status = 500;
    result = e;
  }
  headers.append(CoreHeaders.OP_RESULT_TYPE, "Promise");
}
```

---

## Summary — Key Patterns

| Component | Pattern | File |
|-----------|---------|------|
| **Entry Point** | `export default { fetch(req, env, ctx) {...} }` | `entry.worker.ts` |
| **D1 Queries** | Prepared statements + transaction batching | `database.worker.ts` |
| **KV Operations** | Stream-based, size-limited puts with metadata | `namespace.worker.ts` |
| **R2 Objects** | Metadata + body encoding for responses | `r2Object.worker.ts` |
| **Deploy Command** | Bundle → Bindings → Upload → Deploy | `deploy.ts` |
| **Error Handling** | Custom error classes, user vs system errors | `error.ts` |
| **Type Safety** | Environment interfaces for bindings | Throughout |
| **Streaming** | Transform streams for validation, devalue for RPC | `proxy.worker.ts` |
| **Encoding** | RFC 9110 Accept-Encoding negotiation | `entry.worker.ts` |

This represents the core architectural patterns used throughout the Cloudflare Workers SDK codebase for building robust, type-safe serverless functions.
