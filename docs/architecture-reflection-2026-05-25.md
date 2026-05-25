# NurlWeb Architecture Reflection — 2026-05-25

**Repo:** `nurlweb` (NURL-based web framework)  
**Reviewed:** All 12 core `.nu` modules, FRAMEWORK.md, README.md, all 12 test files, all 4 examples  
**Scope:** Full source audit — every line read, every import traced, every test pattern examined.  
**Tone:** Brutally honest reflection, not celebration.

---

## 1. Architecture Layering

### The Stated Model

```
User Application
    │
┌───┴──────────────┐
│  NurlWeb (~1040) │  app.nu → ctx.nu → module plugins
└───┬──────────────┘
    │
┌───┴──────────────┐
│  NURL stdlib     │  http_router, http_server, http_middleware, etc.
└──────────────────┘
```

### What Actually Exists

NurlWeb has **four distinct tiers**, but they aren't cleanly separated:

| Tier | Files | LOC | Role |
|------|-------|-----|------|
| **Core** | `app.nu` | 172 | Routing, middleware pipeline, serve lifecycle, DoS |
| **Rich context** | `ctx.nu` | 144 | Ctx wrapper, param/query/body extraction, response shortcuts |
| **Standalone utils** | `respond.nu` | 46 | Ctx-free response helpers (near-duplicate of ctx response layer) |
| **Feature plugins** | session, upload, template, cors, validate, error, auth, static, ws | 1,017 | Opt-in modules, each importing ctx or app |

### Layering Problems

**Problem 1: `ctx.nu` depends on `app.nu` but the relationship is confused.** `ctx.nu` imports `app.nu` via `$` — but `ctx` functions accept `Ctx` not `App`. The `app.nu` import is only for transitively exposing App to downstream users. This means Ctx cannot be used without pulling in the entire App machinery. There is no way to use Ctx as a pure extraction layer over bare `HttpRequest` + `Params` without the App/router baggage.

**Problem 2: `nurlweb.nu` is an aggregator that only pulls `ctx.nu`.** All other modules (session, upload, etc.) are commented-out suggestions in the file. To get session support, the user must add `$ \`nurlweb/session.nu\`` separately. There is no single import that pulls the full framework. Worse, `nurlweb.nu` only re-exporting `ctx.nu` creates a false impression that it's "the framework" — when it's actually missing 8 of 12 modules.

**Problem 3: The middleware pipeline is invisible.** `app_use` performs progressive closure composition (last registered = innermost), which is elegant, but there is no introspection. You cannot list registered middleware, remove middleware, or conditionally apply middleware. The `app.handler` field is a black-box composed closure. Order-dependent bugs are hard to debug.

**Problem 4: No error boundary between layers.** When a handler throws, the composed closure chain unwinds with no structured error boundary. `app_catch` in `error.nu` detects a sentinel *header*, not an exception. This means native NURL errors from stdlib (e.g., OOM, assertion failures) bypass the error middleware entirely.

**Problem 5: The Ctx layer is leaky.** `ctx_body_json` delegates to `ctx_body_raw`, which does raw byte extraction from `req.body`. The `parse_err_msg` function is used to convert `ParseErr` to a string, but this helper is imported from `stdlib/core/errors.nu` only in `validate.nu` — `ctx.nu` doesn't import it. `ctx_body_json` returns a raw `!Json ParseErr` sum type, forcing every caller to pattern-match instead of getting a unified error response through error middleware.

---

## 2. Code Duplication

### Critical Duplications

**Duplication 1: Response helpers — `ctx.nu` vs `respond.nu`**

Every response helper in `ctx.nu` has a near-identical counterpart in `respond.nu`, differing only by the leading `Ctx` parameter:

```
ctx.nu:       ctx_text(Ctx c, i status, s body) → HttpResponse
respond.nu:   respond_text(i status, s body)     → HttpResponse

ctx.nu:       ctx_json(Ctx c, i status, s body) → HttpResponse
respond.nu:   respond_json(i status, s body)     → HttpResponse
```

This is explicitly documented as "for use in middleware and utility functions where Ctx isn't available." The fix is trivial: `respond.nu` functions should be the canonical implementations, and `ctx.nu` functions should delegate to them, discarding the Ctx argument. Instead, both modules independently call `response_text` + `response_set_header`. This is ~30 lines of duplicated logic across 6 functions.

**Duplication 2: String construction boilerplate**

The `rest_api.nu` example and `session.nu` both build JSON strings manually with `string_push_str` / `string_push_int` / `string_push_char` chains. There is no `json_build` helper in the framework. Users write ~15 lines of string assembly for every JSON response body.

**Duplication 3: CORS middleware is 22 lines but should be 5.**

`cors.nu` is a thin closure wrapper around stdlib `with_cors_default`. It exists solely because `app_with_cors` provides an `App → v` interface instead of making the user call `app_use` directly. This is ergonomic but adds a file, an import, and a function for what is essentially one closure.

**Duplication 4: Cookie options repeated verbatim**

`session_set` and `session_del` in `session.nu` construct identical `CookieOpts` blocks (path `/`, secure T, http_only T, same_site Lax) — differing only in whether `max_age 0` is set. A shared helper or constant would eliminate 10 duplicated lines.

---

## 3. Naming Consistency

### Module Naming

Good: `app.nu`, `ctx.nu`, `session.nu`, `upload.nu`, `template.nu`, `cors.nu`, `validate.nu`, `error.nu`, `auth.nu`, `static.nu`, `ws.nu`, `respond.nu`. Consistent single-word lowercase names.

### Function Naming — Prefix Conventions

| Module | Prefix Pattern | Consistent? |
|--------|---------------|-------------|
| `app.nu` | `app_*` | ✅ 100% |
| `ctx.nu` | `ctx_*` | ✅ 100% |
| `session.nu` | `session_*`, `session_store_*` | ✅ 100% |
| `upload.nu` | `upload_*` | ✅ 100% |
| `template.nu` | `template_*` + internal `__*` | ✅ 100% |
| `cors.nu` | `app_with_cors` | ⚠️ Mixes `app_` prefix |
| `validate.nu` | `schema_*`, `validate_*` | ⚠️ Dual prefix |
| `error.nu` | `error_*`, `app_catch` | ⚠️ Mixes `app_` prefix |
| `respond.nu` | `respond_*` | ✅ 100% |
| `auth.nu` | `auth_*` | ✅ 100% |
| `static.nu` | `static_*` | ✅ 100% |
| `ws.nu` | `ws_*`, `app_ws` | ⚠️ Mixes `app_` prefix |

### Naming Anomalies

1. **`app_catch`** (error.nu) — uses `app_` prefix but lives in `error.nu`. Should be `error_catch` or `app_error_catch` for discoverability.

2. **`app_with_cors`** (cors.nu) — same issue. A user looking for CORS will import `cors.nu` and look for `cors_*` functions, not `app_with_cors`.

3. **`__serve_bind`** (app.nu) — uses double-underscore to signal "internal", but `__session_store_find` (session.nu) uses a different internal naming pattern (`__module_function` vs just `__function`). No consistent convention for private helpers.

4. **`static_dir` is an alias for `static_serve`** but with **swapped arguments**. `static_dir` calls `( static_serve dir ctx )` — passing the directory as the Ctx argument and Ctx as the directory. This is a **compile-time type error** that slipped through. The alias is broken.

5. **`FRAMEWORK.md` references functions that don't exist.** The README.md API table lists `app_error_new` and `app_error_middleware` which do not exist in `error.nu`. The actual functions are `__error_response`, `error_not_found`, etc., and `app_catch`.

6. **Template internal functions** use `__try_push_var`, `__scan_to_close`, `__resolve_includes` — consistent with the `__` convention. But `session.nu` uses `__session_store_find` (module-qualified `__`). Inconsistent internal naming.

---

## 4. Ctx-First Adherence

### What "Ctx-First" Means

The framework claims Ctx is the unified context: "All helpers take Ctx as first arg for uniform LLM-friendly API surface." This is `ctx.nu`'s design thesis.

### Adherence Audit

| Module | Ctx-first? | Notes |
|--------|-----------|-------|
| `ctx.nu` | ✅ | All functions take Ctx as arg 1 |
| `session.nu` | ✅ | `session_get/set/del` take Ctx as arg 1 |
| `upload.nu` | ✅ | `upload_parts` takes Ctx |
| `auth.nu` | ✅ | All auth functions take Ctx |
| `static.nu` | ✅ | `static_serve` takes Ctx |
| `validate.nu` | ✅ | `validate_json` takes Ctx |
| `template.nu` | ❌ | Takes `s template` and `(Vec TemplateVar) vars` — no Ctx |
| `error.nu` | ❌ | `app_catch` takes App, not Ctx (reasonable, it's middleware) |
| `cors.nu` | ❌ | `app_with_cors` takes App |
| `respond.nu` | ❌ | Explicitly Ctx-free (this is the point) |
| `ws.nu` | ❌ | Takes `s host i port` — no Ctx |
| `app.nu` | ❌ | Takes App — this is correct, Ctx is one layer up |

### The Real Tension

Ctx-first is a **routing-time** concept. It makes sense inside route handlers. But NurlWeb has three distinct contexts:
1. **App-level** (lifecycle, middleware, serve) — where Ctx doesn't exist yet
2. **Route-level** (handler bodies) — where Ctx is central
3. **Pre-response** (middleware, error handlers) — where Ctx may or may not exist

The framework doesn't acknowledge this distinction in its documentation. The "Ctx-first" claim is an overstatement: only 6 of 12 modules adhere to it, and only within route handlers.

---

## 5. Module LOC Counts

```
Module        LOC    Tests  Test:LOC  Comments    Complexity
───────────────────────────────────────────────────────────
template.nu   319    110    0.34x      ~40 lines   HIGH — recursive include resolution, layout parsing
session.nu    184    125    0.68x      ~25 lines   MEDIUM — linear-scan store, manual string management
app.nu        172    106    0.62x      ~30 lines   MEDIUM — DoS branching, async/sync dual path
validate.nu   168     60    0.36x      ~20 lines   MEDIUM — five-type dispatch, nested pattern matching
ctx.nu        144     82    0.57x      ~15 lines   LOW — mostly delegation wrappers
error.nu      128     93    0.73x      ~20 lines   MEDIUM — sentinel-header pattern, body extraction
ws.nu          97     56    0.58x      ~15 lines   LOW — accept-loop, simple ws wrapper
upload.nu       71     50    0.70x      ~10 lines   LOW — Content-Length guard + delegation
auth.nu         70     71    1.01x      ~8 lines    LOW — delegation to stdlib with error responses
static.nu       58     44    0.76x      ~8 lines    LOW — delegation to stdlib serve_static
respond.nu      46     38    0.83x      ~5 lines    LOW — pure delegation
cors.nu         22     46    2.09x      ~5 lines    TRIVIAL
nurlweb.nu      19      0    0.00x      ~10 lines   TRIVIAL — aggregator only
───────────────────────────────────────────────────────────
TOTAL:       1,498    881    0.59x
```

### Observations

- **template.nu is the largest module by far** (319 LOC, 21% of framework). It implements a custom string interpolation engine with include resolution, layout injection, and depth limiting — all from scratch. This is the highest-risk module.
- **cors.nu is 22 lines** — a wrapper so thin it arguably shouldn't be a separate file. The 2.09x test-to-code ratio is inflated by test boilerplate.
- **Average test coverage is good** (0.59x) but all tests are **compile-time only** — they verify type signatures, not behavior. Zero behavioral assertions exist outside E2E scripts.
- **Total framework is ~1,500 LOC** — significantly less than FRAMEWORK.md's claimed ~1,040. The docs are out of date with v1.2 growth.

---

## 6. Import Dependency Graph

```
nurlweb.nu
  └── ctx.nu
        ├── app.nu
        │     ├── stdlib/std/net.nu
        │     ├── stdlib/std/signal.nu
        │     ├── stdlib/std/async.nu
        │     ├── stdlib/ext/http_router.nu
        │     └── stdlib/ext/http_server.nu
        ├── stdlib/ext/http_full.nu
        ├── stdlib/ext/json.nu
        ├── stdlib/core/string.nu
        └── stdlib/core/option.nu

session.nu        → ctx.nu, http_auth, string, vec
upload.nu         → ctx.nu, http_multipart, string, vec
validate.nu       → ctx.nu, json, vec, string, errors
error.nu          → app.nu, http_full, string, vec
auth.nu           → ctx.nu, http_auth
static.nu         → ctx.nu, http_static
cors.nu           → app.nu, http_full
template.nu       → string, vec, fs          ← NO framework dependency!
respond.nu        → http_full                ← NO framework dependency!
ws.nu             → net, websocket, string, vec ← NO framework dependency!
```

### Dependency Analysis

**Hot nodes:** `ctx.nu` (6 dependents), `app.nu` (3 dependents + ctx). These are the chokepoints.

**Independent modules:** `template.nu`, `respond.nu`, `ws.nu` are pure stdlib consumers with zero framework dependencies. They could be published as standalone NURL libraries.

**Spider-web:** The graph is actually clean — it's a layered DAG with no cycles (except `app.nu` → `http_full` and `ctx.nu` → `app.nu` → `http_full` producing duplicate stdlib resolution, which is harmless).

**Problem:** `error.nu` imports `app.nu` directly, bypassing `ctx.nu`. This is correct (error middleware wraps App, not Ctx), but it means error handling cannot use Ctx-based helpers without an additional import. The `error_render_json` function manually calls `response_text` + `response_set_header` — duplicating what `ctx_json` already does.

**Redundant imports:** `upload.nu` imports `stdlib/core/string.nu` and `stdlib/core/vec.nu` but never uses `vec_*` or `string_*` functions directly (they're transitively needed by `http_multipart.nu`). Same pattern in `cors.nu` importing `http_full.nu` when it only uses `with_cors_default` (from `http_middleware.nu`, re-exported by `http_full.nu`).

---

## 7. What's Missing vs. Egg.js / Koa / Express / Hono

This is the critical gap analysis.

### Table: Feature Parity

| Feature | Egg.js | Koa | Express | Hono | NurlWeb |
|---------|--------|-----|---------|------|---------|
| Router | ✅ | ❌ (plugin) | ✅ | ✅ | ✅ `app_get` etc. |
| Middleware pipeline | ✅ | ✅ (core) | ✅ | ✅ | ✅ `app_use` progressive |
| Error middleware | ✅ | ✅ | ✅ | ✅ | ✅ sentinel-header `app_catch` |
| Body parsing (JSON) | ✅ (built-in) | ❌ (plugin) | ✅ | ✅ | ⚠️ `ctx_body_json` (manual) |
| Body parsing (form) | ✅ | ❌ | ✅ | ✅ | ❌ **MISSING** |
| Body parsing (text) | ✅ | ❌ | ✅ | ✅ | ⚠️ `ctx_body_raw` (raw bytes) |
| Query string parsing | ✅ | ✅ (ctx.query) | ✅ | ✅ | ⚠️ `ctx_query` = header lookup |
| Route groups/prefix | ✅ | ❌ (plugin) | ✅ | ✅ | ❌ **MISSING** |
| Param validation (built-in) | ✅ (egg-validate) | ❌ | ❌ (plugin) | ✅ (validator) | ⚠️ `validate.nu` (opt-in) |
| Static files | ✅ | ❌ (plugin) | ✅ | ✅ | ✅ `static_serve` |
| Template rendering | ✅ (plugin) | ❌ | ❌ | ❌ (JSX) | ⚠️ `template.nu` (no HTML escape!) |
| Session | ✅ (plugin) | ❌ | ❌ (plugin) | ❌ (plugin) | ⚠️ Mem-only, no Redis/DB |
| CORS | ✅ (plugin) | ❌ (plugin) | ❌ (plugin) | ✅ (built-in) | ⚠️ Permissive only |
| CSRF protection | ✅ | ❌ | ❌ (plugin) | ❌ (plugin) | ❌ **MISSING** |
| Rate limiting | ❌ (plugin) | ❌ (plugin) | ❌ (plugin) | ❌ (plugin) | ⚠️ IP-level DoS only |
| Request logging | ✅ (plugin) | ❌ (plugin) | ❌ (plugin) | ✅ (built-in) | ⚠️ Manual `with_access_log` |
| Compression (gzip) | ✅ | ❌ | ❌ (plugin) | ✅ | ❌ **MISSING** |
| ETag / caching | ❌ | ❌ | ❌ | ✅ | ❌ **MISSING** |
| Streaming response | ✅ | ❌ | ✅ | ✅ | ❌ **MISSING** |
| WebSocket | ❌ (plugin) | ❌ | ❌ | ❌ | ⚠️ Separate port only |
| Hot reload (dev) | ✅ | ❌ | ❌ (nodemon) | ✅ | ❌ **MISSING** |
| Testing utilities | ✅ | ❌ | ❌ (supertest) | ✅ | ❌ **MISSING** (compile-only) |
| CLI generator | ✅ | ❌ | ❌ | ✅ (create-hono) | ✅ `nurlweb new` |
| Type-safe (language-level) | ❌ (JS/TS) | ❌ (JS) | ❌ (JS) | ✅ (TS) | ✅ (NURL type system) |
| Async context (no DI) | ❌ | ✅ (ctx) | ❌ | ✅ (c.var) | ✅ (Ctx struct) |

### The Biggest Gaps

1. **No request body parsing beyond JSON.** There is no `ctx_body_form`, no `ctx_body_text`, no `ctx_body_urlencoded`. The user must manually extract and parse the byte body. For a framework claiming "Egg.js-level API," this is a significant gap.

2. **No query-string parsing.** `ctx_query` literally calls `header_get`. The stdlib stores query params in request headers, but there is no URL-decoding, no multi-value support, no array syntax (`?ids=1&ids=2`). This is a stdlib limitation, not a framework bug, but the framework should paper over it.

3. **No route grouping or prefix mounting.** Express has `app.use('/api', apiRouter)`. Koa has `koa-mount`. Hono has `app.route('/api').get(...)`. NurlWeb has nothing — every route must be registered on the root App with full paths.

4. **WebSocket is siloed on a separate port.** `app_ws` takes `host` and `port` as separate arguments. It cannot share the HTTP port because `HttpRequest` carries no `TcpConn`. This means production deployment needs an Nginx reverse proxy to unify ports — not documented, not scaffolded.

5. **No response compression.** Express has `compression` middleware. Hono has built-in `compress()`. NurlWeb has no gzip/brotli support.

6. **SessionStore is memory-only.** No Redis, no Postgres, no file-based backend. Production is impossible without external session storage.

7. **No streaming responses.** Every handler must return a complete `HttpResponse`. There is no `ReadableStream` equivalent, no chunked transfer encoding support.

8. **No ETag or cache-control infrastructure.** Every response is uncached unless the user manually sets headers.

---

## 8. Risk Inventory

### Weakest Module: `template.nu`

- **319 lines** of hand-written string parsing with manual character-by-character scan loops (`nurl_str_get` in tight ~-loops)
- **XSS vulnerability by design** — no HTML escaping. The module docs say "Do NOT use for HTML templates with untrusted user input" but provide no alternative for HTML templates.
- **Recursive include resolution** with depth-limited mutual recursion — `__resolve_includes` calls itself. No cycle detection beyond the depth cap. The comment says "cycles produce depth-limit pass-through" — but the function hits the depth cap and appends the raw template, which contains the unresolved `{{> path }}` directive. This silently produces broken output.
- **No test for template rendering output correctness.** `test_template.nu` is compile-time only — it never verifies that `template_render("hello {{name}}!", ...)` produces `"hello world!"`.
- **O(n·m) lookup:** `__try_push_var` does a linear scan of all vars for every `{{key}}` — O(variables × placeholders).
- **Manual memory management:** Every `String` allocation in template.nu is paired with `string_free`. One missed free path = memory leak. The `template_render_layout` function has 5 separate `string_free` calls — easy to miss one in a refactor.

### Strongest Module: `app.nu`

- Clear single-responsibility: App lifecycle, route delegation, middleware pipeline, serve.
- Progressive middleware composition is elegant and avoids middleware list maintenance.
- `__serve_bind` extracts the common bind→signal→run→stop pattern, shared by sync and async paths.
- DOS protection is correctly deferred to stdlib, with the `individual fields` approach to avoid silent struct evolution bugs.
- Clean test coverage: compile-time tests verify every function signature and the middleware composition pattern.

### What Breaks First

**If NURL's stdlib changes:**
1. `ctx_query` / `ctx_header` break if query params stop being stored in headers (currently both delegate to `header_get`).
2. `http_router.nu` handler signature changes — breaks every route handler in every example.
3. `http_multipart.nu` changes `MultipartPart` structure — breaks `upload.nu`.
4. `websocket.nu` changes `WsLimits` or `WsMessage` — breaks `ws.nu`.

**Under load:**
1. SessionStore linear scan degrades with >1000 active sessions — O(n) lookup per request.
2. Template rendering linear scan degrades with >100 variables — O(n·m) per render.
3. Single-threaded `app_serve` blocks on every request — no concurrent request handling without `app_serve_async`.

**Under attack:**
1. No CSRF protection — every form POST is vulnerable.
2. `upload_parts` Content-Length check is a soft guard — parsed before limit enforcement. Maliciously crafted multipart bodies could still exhaust memory during parsing.
3. No request timeout — slow clients can hold connections indefinitely.
4. No body size limit on JSON — `ctx_body_json` reads the full body regardless of size.

### Silent Bugs Found During Audit

1. **`static_dir` has swapped arguments.** Line 46 of `static.nu`: `( static_serve dir ctx )` should be `( static_serve ctx dir )`. This is a type error that may not be caught until runtime depending on how the NURL compiler handles the type mismatch between `Ctx` and `s`.

2. **`rest_api.nu` has a memory leak.** The `item_new` function allocates a `String` with `( string_new )` and pushes content. `item_free` frees `it.name`. But the handler closures capture `items` by value — the `Vec<Item>` is never freed if `app_serve` blocks indefinitely. The cleanup code after `app_serve` only runs on shutdown, which SIGINT may bypass.

3. **`template_render_layout` has a content duplication bug when no marker is found.** If `{{% content %}}` is absent, content is prepended, but the layout's original `{{%` region is emitted as raw characters (lines ~270-280 of template.nu). The rendered output will contain partial `{{% content %}}` garbage characters between the prepended content and the layout.

---

## 9. Recommendations

### Top 3 V1.2 Fixes (Critical — Fix Immediately)

**Fix 1: Unify `ctx.nu` and `respond.nu` response helpers.**

Make `respond.nu` the canonical implementation. Have `ctx.nu` functions delegate:
```
@ ctx_json Ctx c i status s body → HttpResponse {
    ^ ( respond_json status body )
}
```
This eliminates ~30 lines of duplicated `response_set_header` calls and ensures Content-Type headers are set consistently in one place. Bonus: `error_render_json` in `error.nu` can then call `respond_json` instead of manually setting Content-Type.

**Fix 2: Add HTML escaping to template.nu or remove the HTML claim.**

The module currently says "for plain-text string interpolation only, not HTML." This is the right stance — but the module is called "template" and the examples show HTML-like output. Two options:
- Add an `html_escape` boolean to `TemplateVar` and escape `<>&"'` when rendering HTML
- Rename the module to `interpolate.nu` and remove the layout/include features (which are HTML-oriented)

The current state is dangerous: a developer sees `template.nu`, reads about layouts, uses it for HTML, and creates an XSS vulnerability.

**Fix 3: Add query-string parsing to `ctx.nu`.**

`ctx_query` should do URL-decoding, not just `header_get`. Even if the stdlib doesn't provide a query parser, the framework should add basic `%XX` decoding and `&`-splitting. Without this, `ctx_query` is just a misleading alias for header lookup.

### Top 3 V1.3 Features (Strategic)

**Feature 1: Route grouping with prefix support.**

```nurl
: App api ( app_group app `/api` )
( app_get api `/users` handler )   // → GET /api/users
```

This is the single most-requested routing feature in every web framework. Implementation requires either storing a prefix in App or creating a `RouteGroup` struct that wraps App + prefix. The closure-capture pattern already supports capturing `prefix` by value.

**Feature 2: Real body parsing — form, urlencoded, text.**

```nurl
( ctx_body_form ctx )         → ?(Vec FormField)
( ctx_body_urlencoded ctx )   → ?(Vec QueryParam)
( ctx_body_text ctx )         → String
```

These should delegate to stdlib where available (e.g., `http_multipart.nu` for form) and provide basic parsing where not.

**Feature 3: Structured logging and request ID.**

```nurl
( app_with_logger app )      → enable structured logging
( ctx_request_id ctx )       → ?String (X-Request-Id or generated UUID4)
```

Currently, logging requires manually wiring `with_access_log` via `app_use`. A built-in logger that emits JSON to stderr with request ID, method, path, status, and duration would make debugging production issues possible without external tooling.

### Honorable Mention (Should Be V1.3 But Deferrable)

- **SessionStore Redis backend** — `session_store_new_redis(s host i port)`. Required by any production deployment.
- **Response streaming** — depends on stdlib supporting chunked responses. Blocked until NURL supports `StreamWriter`.
- **Compression** — `app_use app with_gzip`. Depends on stdlib or a basic gzip implementation.
- **CSRF** — `app_with_csrf app` middleware. Low-hanging fruit. Generate token, store in session, validate on mutation requests.

---

## Summary

| Dimension | Grade | Notes |
|-----------|-------|-------|
| Architecture clarity | B | Four-layer model is right but undocumented; dependencies are clean DAG |
| Code quality | B | Good internal consistency but duplication and manual memory management |
| Naming consistency | B+ | Strong prefix conventions with a few `app_` interlopers |
| Ctx-first adherence | B- | Only 6/12 modules; overstated in docs |
| API completeness | C+ | Missing form parsing, query decoding, route groups, compression, streaming |
| Safety | C | No HTML escape, no CSRF, no request timeout, sentinel-header error model |
| Production readiness | D | Memory-only sessions, no compression, no streaming, WIP DoS, no Redis |
| Documentation accuracy | C | Out-of-date LOC counts, ghost function names in README, no mention of gaps |

NurlWeb is a **solid v1.1 micro-framework** that does exactly what it claims for the happy path: reduce 6 lines to 2, provide clean Ctx extraction, and not fork the stdlib. It succeeds as an LLM-first framework — the naming conventions and single-responsibility modules make it easy for an LLM to generate correct code.

But it is **not yet a production web framework**. The missing body parsers, query decoders, session backends, compression, and streaming mean a real application would need significant custom middleware to fill the gaps. The good news: the architecture is clean enough that all of these are additive — nothing needs to be torn down.
