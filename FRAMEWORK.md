# NurlWeb — LLM-First Web Framework for NURL

NurlWeb is a layered web framework for [NURL](https://github.com/nurl-lang/nurl).
**Core layer** (`nurlweb/`, 4 files, ~560 LOC): wiring reduction, routes, middleware, serve.
**Convention layer** (`nurlweb-kit/`, 24 files, ~2256 LOC): Ctx, middleware, ORM, config, lifecycle, templates, CLI.

Design: LLM-optimized. One import. Copy-pasteable examples. Zero forking of NURL stdlib.

---

## Prerequisites

NurlWeb requires the NURL toolchain and standard library:

1. Clone and build [nurl-lang](https://github.com/nurl-lang/nurl)
2. Run the setup script from your project root:
   ```bash
   sh nurlweb/setup.sh /path/to/nurl-lang
   ```
   This creates a `stdlib` symlink so imports resolve correctly.
3. Verify: `nurlc examples/hello.nu` should compile without errors.

---

## Quick Start

```nurl
$ `nurlweb/app.nu`
$ `stdlib/ext/http_full.nu`

@ main → i {
    : App app ( app_new `127.0.0.1` 3000 )

    ( app_get app `/`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `hello from nurlweb!\n` )
        })

    ( app_serve app )
}
```

Or with the rich Ctx layer from nurlweb-kit:

```nurl
$ `nurlweb/nurlweb.nu`
$ `nurlweb-kit/context/ctx.nu`
$ `stdlib/ext/http_full.nu`

@ main → i {
    : App app ( app_new `127.0.0.1` 3000 )

    ( app_get app `/users/:id`
        \ HttpRequest req Params params → HttpResponse {
            : Ctx ctx ( ctx_new req params )
            : ?String id ( ctx_param ctx `id` )
            ?? id {
                T sid → { ^ ( ctx_ok sid ) }
                F    → { ^ ( ctx_not_found `missing id\n` ) }
            }
        })

    ( app_serve app )
}
```

### CLI Scaffolding

```bash
# Clone nurlweb + nurlweb-kit and use the CLI
git clone https://github.com/clawbolt/nurlweb
git clone https://github.com/clawbolt/nurlweb-kit
sh nurlweb/setup.sh /path/to/nurl-lang
./nurlweb-kit/bin/nurlweb-kit new my-api
cd my-api && sh build.sh && ./app
```

---

## API Reference

### App Lifecycle (`nurlweb/app.nu`)

| Function | Signature | Description |
|---|---|---|
| `app_new` | `s host i port → App` | Create app bound to host:port |
| `app_with_workers` | `App a i n → App` | Set async fiber worker count |
| `app_with_dos` | `App a i max_conns i max_per_ip → App` | DoS protection (individual fields, max_conns=0 to disable) |
| `app_free` | `App a → v` | Free router and handler data |

### Routes (`nurlweb/app.nu`)

All route functions delegate directly to `http_router.nu`. Handler signature: `( @ HttpResponse HttpRequest Params )`.

| Function | Description |
|---|---|
| `app_get App a s route handler → v` | GET |
| `app_post App a s route handler → v` | POST |
| `app_put App a s route handler → v` | PUT |
| `app_patch App a s route handler → v` | PATCH |
| `app_delete App a s route handler → v` | DELETE |
| `app_any App a s method s route handler → v` | Any HTTP method |

Route patterns: `/users/:id` (named capture), `/static/*path` (tail wildcard).

### Route Groups (`nurlweb/routegroup.nu`)

| Function | Signature | Description |
|---|---|---|
| `app_group` | `App a s prefix → RouteGroup` | Create a prefix-based route group |
| `group_get` | `RouteGroup g s route handler → v` | GET with prefix prepended |
| `group_post` | `RouteGroup g s route handler → v` | POST with prefix prepended |
| `group_put` | `RouteGroup g s route handler → v` | PUT with prefix prepended |
| `group_patch` | `RouteGroup g s route handler → v` | PATCH with prefix prepended |
| `group_delete` | `RouteGroup g s route handler → v` | DELETE with prefix prepended |
| `group_any` | `RouteGroup g s method s route handler → v` | Any method with prefix prepended |

### Response Shortcuts (`nurlweb/respond.nu`)

Standalone helpers that don't require Ctx. These are the canonical implementations — Ctx delegates to them.

| Function | Signature | Description |
|---|---|---|
| `respond_text` | `i status s body → HttpResponse` | Plain text response |
| `respond_json` | `i status s body → HttpResponse` | JSON (sets Content-Type) |
| `respond_html` | `i status s body → HttpResponse` | HTML (sets Content-Type) |
| `respond_status` | `i status → HttpResponse` | Status-only (empty body) |
| `respond_redirect` | `i status s location → HttpResponse` | Redirect (sets Location header) |

### Middleware (`nurlweb/app.nu`)

| Function | Signature | Description |
|---|---|---|
| `app_use` | `App a middleware → v` | Register middleware |

Progressive closure composition — last registered = innermost (closest to route handler).
Middleware shape: `( @ ( @ HttpResponse HttpRequest ) ( @ HttpResponse HttpRequest ) )` — same as every `http_middleware.nu` combinator.

```nurl
( app_use app \ ( @ HttpResponse HttpRequest ) h → ( @ HttpResponse HttpRequest ) {
    ^ ( with_access_log h )
})
```

### Serve (`nurlweb/app.nu`)

| Function | Signature | Description |
|---|---|---|
| `app_serve` | `App a → !v NetErr` | Blocking server (single-threaded). SIGINT/SIGTERM graceful shutdown. |
| `app_serve_async` | `App a → !v NetErr` | Fiber-based server. Use `app_with_workers` to set worker count. |

---

## Kit Convention Layer

The following modules live in `nurlweb-kit/` and provide higher-level conventions on top of nurlweb core.

### Ctx — Request Context (`nurlweb-kit/context/ctx.nu`)

Ctx is a borrowed view over `HttpRequest` + `Params`. Zero allocation. Construct inline at each route:

```nurl
( app_get app `/path`
    \ HttpRequest req Params params → HttpResponse {
        : Ctx ctx ( ctx_new req params )
        // ... use ctx_* helpers ...
    })
```

#### Construction

| Function | Signature |
|---|---|
| `ctx_new` | `HttpRequest req Params params → Ctx` |

#### Param Extraction

| Function | Signature | Description |
|---|---|---|
| `ctx_param` | `Ctx c s name → ?String` | Named path parameter |
| `ctx_param_i` | `Ctx c s name → ?i` | Named path param as integer |

#### Query & Headers

| Function | Signature | Description |
|---|---|---|
| `ctx_query` | `Ctx c s name → ?String` | URL-decoded query parameter |
| `ctx_query_all` | `Ctx c s name → ?( Vec String )` | Query parameter (single-element vec) |
| `ctx_header` | `Ctx c s name → ?String` | Request header |

#### Body

| Function | Signature | Description |
|---|---|---|
| `ctx_body_raw` | `Ctx c → s` | Raw body string (empty if no body) |
| `ctx_body_json` | `Ctx c → !Json ParseErr` | Parse JSON body |
| `ctx_body_form` | `Ctx c → ?( Vec MultipartPart )` | Parse multipart/form-data |
| `ctx_body_urlencoded` | `Ctx c → ?( Vec UrlEncodedPair )` | Parse application/x-www-form-urlencoded |
| `ctx_body_text` | `Ctx c → String` | Body as owned String |

#### Response Helpers

These do **not** take Ctx as a parameter — they are standalone shortcuts.

| Function | Signature | Description |
|---|---|---|
| `ctx_text` | `i status s body → HttpResponse` | Custom status + body (delegates to `respond_text`) |
| `ctx_json` | `i status s body → HttpResponse` | JSON response (delegates to `respond_json`) |
| `ctx_html` | `i status s body → HttpResponse` | HTML response (delegates to `respond_html`) |
| `ctx_ok` | `s body → HttpResponse` | 200 OK |
| `ctx_not_found` | `s msg → HttpResponse` | 404 Not Found |
| `ctx_error` | `s msg → HttpResponse` | 500 Internal Server Error |
| `ctx_redirect` | `i status s location → HttpResponse` | Redirect (delegates to `respond_redirect`) |

For other status codes, use `ctx_text` directly:
```nurl
( ctx_text 201 body )   // instead of ctx_created
( ctx_text 401 msg )    // instead of ctx_unauthorized
( ctx_text 409 msg )    // instead of ctx_conflict
```

---

### CORS (`nurlweb-kit/middleware/cors.nu`)

Permissive CORS middleware for development. Wraps stdlib `with_cors_default`.

```nurl
$ `nurlweb-kit/middleware/cors.nu`

: App app ( app_new `127.0.0.1` 8080 )
( app_with_cors app )
```

| Function | Signature | Description |
|---|---|---|
| `app_with_cors` | `App a → v` | Enable permissive CORS on the App |

**Headers added:** `Access-Control-Allow-Origin: *`, `Access-Control-Allow-Headers: Content-Type, Authorization`.
**Production:** pin specific origins via custom middleware using stdlib `response_set_header`.

---

### Compression (`nurlweb-kit/middleware/compress.nu`)

```nurl
$ `nurlweb-kit/middleware/compress.nu`

( app_with_compress app )
```

| Function | Signature | Description |
|---|---|---|
| `app_with_compress` | `App a → v` | Enable gzip compression (responses > 256 bytes, requires Accept-Encoding: gzip) |

---

### Auth (`nurlweb-kit/middleware/auth.nu`)

```nurl
$ `nurlweb-kit/middleware/auth.nu`
```

| Function | Signature | Description |
|---|---|---|
| `auth_basic` | `Ctx ctx → ?BasicAuth` | Parse Basic auth (returns None if absent) |
| `auth_bearer` | `Ctx ctx → ?String` | Parse Bearer token (returns None if absent) |
| `auth_cookie` | `Ctx ctx s name → ?String` | Read a cookie by name |
| `auth_require_basic` | `Ctx ctx → !BasicAuth HttpResponse` | Require Basic auth (returns 401 on failure) |
| `auth_require_bearer` | `Ctx ctx → !String HttpResponse` | Require Bearer token (returns 401 on failure) |

---

### JWT Auth (`nurlweb-kit/middleware/auth_jwt.nu`)

```nurl
$ `nurlweb-kit/middleware/auth_jwt.nu`
```

| Function | Signature | Description |
|---|---|---|
| `jwt_sign` | `s payload s secret → s` | Sign payload with HMAC-SHA256 |
| `jwt_verify` | `s token s secret → ?String` | Verify signature, return payload |
| `jwt_create` | `s claims s secret → s` | Sign JSON claims string |
| `jwt_claims` | `s token → s` | Extract payload without verification |

---

### CSRF Protection (`nurlweb-kit/middleware/csrf.nu`)

Double-submit cookie pattern. Compares `X-CSRF-Token` header against `csrf_token` cookie.

```nurl
$ `nurlweb-kit/middleware/csrf.nu`

// Generate a token:
: s tok ( csrf_token `your-secret` )
// Set csrf_token cookie and X-CSRF-Token header on forms

// Per-route protection:
( app_post a `/submit` ( csrf_protect handler ))
```

| Function | Signature | Description |
|---|---|---|
| `csrf_token` | `s secret → s` | Generate token from secret |
| `csrf_protect` | `( @ HttpResponse HttpRequest ) h → ( @ HttpResponse HttpRequest )` | Middleware wrapper |

Safe methods (GET, HEAD, OPTIONS, TRACE) skip validation.

---

### Error Handling (`nurlweb-kit/middleware/error.nu`)

Structured errors with sentinel header pattern. Register `app_catch` **last** (outermost).

```nurl
$ `nurlweb-kit/middleware/error.nu`

( app_catch app
    \ HttpResponse orig AppError ae → HttpResponse {
        ^ ( error_render_json orig ae )
    })
```

| Function | Signature | Description |
|---|---|---|
| `error_not_found` | `s code s msg → HttpResponse` | 404 + sentinel |
| `error_validation` | `s code s msg → HttpResponse` | 422 + sentinel |
| `error_unauthorized` | `s code s msg → HttpResponse` | 401 + sentinel |
| `error_forbidden` | `s code s msg → HttpResponse` | 403 + sentinel |
| `error_conflict` | `s code s msg → HttpResponse` | 409 + sentinel |
| `error_internal` | `s code s msg → HttpResponse` | 500 + sentinel |
| `app_catch` | `App a ( @ HttpResponse AppError ) renderer → v` | Error-catching middleware |
| `error_render_json` | `HttpResponse orig AppError ae → HttpResponse` | Default JSON renderer |

---

### Session Management (`nurlweb-kit/middleware/session.nu`)

Two-layer session support: cookie helpers + server-side SessionStore.

```nurl
$ `nurlweb-kit/middleware/session.nu`
$ `nurlweb-kit/context/ctx.nu`
```

#### Cookie Layer

| Function | Signature | Description |
|---|---|---|
| `session_get` | `Ctx ctx s name → ?String` | Read cookie value |
| `session_set` | `Ctx ctx HttpResponse r s name s value → v` | Set cookie (HttpOnly, Secure, SameSite=Lax, Path=/) |
| `session_del` | `Ctx ctx HttpResponse r s name → v` | Delete cookie (max-age=0) |

#### SessionStore Layer (Memory)

| Function | Signature | Description |
|---|---|---|
| `session_store_new` | `→ SessionStore` | Create empty in-memory store |
| `session_store_get` | `SessionStore store s key → ?String` | Read value by key |
| `session_store_set` | `SessionStore store s key s value → v` | Upsert key/value pair (copies values) |
| `session_store_del` | `SessionStore store s key → v` | Remove key (no-op if missing) |
| `session_store_free` | `SessionStore store → v` | Free all entries |

**Cookie defaults:** Path=`/`, Secure=true, HttpOnly=true, SameSite=Lax.
**Store:** in-memory, linear scan. Safe for single-fiber use. Redis/Postgres backends planned.
**Max cookie value:** ~3800 bytes.

```nurl
: SessionStore store ( session_store_new )
( session_store_set store `user_id` `42` )
: ?String uid ( session_store_get store `user_id` )
( session_store_free store )
```

---

### File Upload (`nurlweb-kit/middleware/upload.nu`)

```nurl
$ `nurlweb-kit/middleware/upload.nu`
$ `nurlweb-kit/context/ctx.nu`
```

| Function | Signature | Description |
|---|---|---|
| `upload_parts` | `Ctx ctx → ?( Vec MultipartPart )` | Parse with default 10 MiB limit |
| `upload_parts_with_limit` | `Ctx ctx i max_bytes → ?( Vec MultipartPart )` | Parse with custom size limit |
| `upload_free` | `( Vec MultipartPart ) parts → v` | Free all multipart parts |

Parts are OWNED — caller must free with `upload_free` after use.

---

### Static Files (`nurlweb-kit/middleware/static.nu`)

```nurl
$ `nurlweb-kit/middleware/static.nu`
$ `nurlweb-kit/context/ctx.nu`
```

| Function | Signature | Description |
|---|---|---|
| `static_serve` | `Ctx ctx s dir → HttpResponse` | Serve file from dir based on request path |
| `static_dir` | `Ctx ctx s dir → HttpResponse` | Alias for `static_serve` |
| `static_serve_route` | `App a s prefix s dir → v` | Register GET prefix/* for static files |
| `static_mime` | `s ext → s` | MIME type lookup (borrowed) |

---

### Logging (`nurlweb-kit/middleware/request_logger.nu`)

Structured JSON request logging middleware.

```nurl
$ `nurlweb-kit/middleware/request_logger.nu`

( app_with_logger app )
```

| Function | Signature | Description |
|---|---|---|
| `app_with_logger` | `App a → v` | Register request logging middleware |
| `ctx_request_id` | `Ctx c → ?String` | Extract X-Request-Id from request |

Logs `{"method":"...","path":"...","status":...,"bytes":...}` after each request.

---

### Structured Logger (`nurlweb-kit/logger.nu`)

```nurl
$ `nurlweb-kit/logger.nu`
```

| Function | Signature | Description |
|---|---|---|
| `kit_log_debug` | `s msg → v` | Debug-level log |
| `kit_log_info` | `s msg → v` | Info-level log |
| `kit_log_warn` | `s msg → v` | Warn-level log |
| `kit_log_error` | `s msg → v` | Error-level log |
| `kit_log_set_level` | `s level → v` | Set log level (currently compile-time) |
| `kit_log_with_fields` | `s msg ( Vec LogField ) fields → v` | Structured log with key-value fields |
| `kit_with_logger` | `App a → v` | Request logging middleware (kit_ prefixed) |

---

### WebSocket (`nurlweb-kit/middleware/ws.nu`)

Separate-port WebSocket server (HTTP and WS cannot share a port in NURL).

```nurl
$ `nurlweb-kit/middleware/ws.nu`

( app_ws `127.0.0.1` 3912
    \ WsMessage msg → !v WsErr {
        ^ @ !v WsErr { T 0 }
    })
```

| Function | Signature | Description |
|---|---|---|
| `app_ws` | `s host i port ( @ !v WsErr WsMessage ) handler → !v WsErr` | Start WebSocket server |
| `ws_serve_loop` | `TcpConn conn ( @ !v WsErr WsMessage ) handler → !v WsErr` | Per-connection message loop |
| `ws_limits_default` | `→ WsLimits` | Default WebSocket limits |

---

### Error/CSRF/Timeout (`nurlweb-kit/middleware/`)

See individual sections above for error.nu and csrf.nu.

**timeout.nu** — *Stability: placeholder*. This is a pass-through stub. True request-scoped deadlines require async/cancel support planned for NURL v3. Until then, use `server_new_with_timeout` when creating the server directly.

---

### ORM (`nurlweb-kit/orm/orm.nu`)

SQLite ORM wrapping NURL's sqlite3 C builtins directly. All queries use parameterized binding.

```nurl
$ `nurlweb-kit/orm/orm.nu`
```

| Function | Signature | Description |
|---|---|---|
| `orm_open` | `s path → ! OrmDB IoErr` | Open SQLite database |
| `orm_close` | `OrmDB db → v` | Close database |
| `orm_exec` | `OrmDB db s sql → ! i DbErr` | Execute SQL (no rows) |
| `orm_query` | `OrmDB db s sql ( Vec OrmParam ) params → ! ( Vec OrmRow ) DbErr` | Query returning rows |
| `orm_query_one` | `OrmDB db s sql ( Vec OrmParam ) params → ! OrmRow DbErr` | Query returning one row |
| `orm_insert` | `OrmDB db s table ( Vec s ) cols ( Vec OrmParam ) vals → ! i DbErr` | Insert row |
| `orm_quote_ident` | `s name → String` | Safe SQL identifier quoting |
| `orm_row_get` | `OrmRow row i idx → String` | Get column value by index |
| `orm_row_len` | `OrmRow row → i` | Column count |
| `orm_row_free` | `OrmRow row → v` | Free row |
| `orm_rows_free` | `( Vec OrmRow ) rows → v` | Free all rows |
| `param_int` | `i v → OrmParam` | Integer parameter |
| `param_text` | `s v → OrmParam` | Text parameter |
| `param_null` | `→ OrmParam` | NULL parameter |

---

### Config (`nurlweb-kit/config.nu`)

Environment-aware config merging. Loads config/_default.nu as base, overlays config/_<env>.nu.

```nurl
$ `nurlweb-kit/config.nu`
```

| Function | Signature | Description |
|---|---|---|
| `kit_config_new` | `→ Config` | Create empty config |
| `kit_config_load` | `s env → Config` | Load config for environment |
| `kit_config_get` | `Config c s key → s` | Get string value (empty if missing) |
| `kit_config_get_i` | `Config c s key → i` | Get integer value (0 if missing) |
| `kit_config_get_b` | `Config c s key → b` | Get boolean value (false if missing) |
| `kit_config_set` | `Config c s key s value s type_hint → v` | Set a config value |
| `kit_config_expect` | `Config c s key s expected_type → !v ConfigErr` | Validate key exists with expected type |
| `kit_config_merge` | `Config base Config override → Config` | Overlay override onto base |
| `kit_config_free` | `Config c → v` | Free config |

Constants: `RES_INDEX`(1), `RES_SHOW`(2), `RES_CREATE`(4), `RES_UPDATE`(8), `RES_DELETE`(16), `RES_ALL`(31).

---

### RESTful Controller (`nurlweb-kit/controller.nu`)

```nurl
$ `nurlweb-kit/controller.nu`
```

| Function | Signature | Description |
|---|---|---|
| `kit_resources` | `App a s prefix h_index h_show h_create h_update h_delete → v` | Register all 5 REST routes |
| `kit_resources_masked` | `App a s prefix i mask h_index h_show h_create h_update h_delete → v` | Selective registration via bitmask |
| `kit_resource_index` | `App a s prefix handler → v` | GET /prefix |
| `kit_resource_show` | `App a s prefix handler → v` | GET /prefix/:id |
| `kit_resource_create` | `App a s prefix handler → v` | POST /prefix |
| `kit_resource_update` | `App a s prefix handler → v` | PUT /prefix/:id |
| `kit_resource_delete` | `App a s prefix handler → v` | DELETE /prefix/:id |

```nurl
( kit_resources app `/api/users`
    user_index user_show user_create user_update user_delete )

// Read-only API:
( kit_resources_masked app `/api/posts` + RES_INDEX RES_SHOW
    post_index post_show post_create post_update post_delete )
```

---

### Lifecycle (`nurlweb-kit/lifecycle.nu`)

Fixed-slot lifecycle hooks: 2 hooks per phase. Avoids nurlc Vec-of-closures limitation.

```nurl
$ `nurlweb-kit/lifecycle.nu`
```

| Function | Signature | Description |
|---|---|---|
| `kit_lifecycle_new` | `→ Lifecycle` | Create lifecycle manager |
| `kit_lifecycle_before_start` | `Lifecycle lc ( @ !v LifecycleErr App ) fn → v` | Register before-start hook |
| `kit_lifecycle_after_start` | `Lifecycle lc ( @ !v LifecycleErr App ) fn → v` | Register after-start hook |
| `kit_lifecycle_before_stop` | `Lifecycle lc ( @ !v LifecycleErr App ) fn → v` | Register before-stop hook |
| `kit_lifecycle_run_before_start` | `Lifecycle lc App a → !v LifecycleErr` | Execute before-start hooks (failure stops startup) |
| `kit_lifecycle_run_after_start` | `Lifecycle lc App a → v` | Execute after-start hooks (failure logged, server continues) |
| `kit_lifecycle_run_before_stop` | `Lifecycle lc App a → v` | Execute before-stop hooks |

---

### Sub-App Mount (`nurlweb-kit/app_mount.nu`)

```nurl
$ `nurlweb-kit/app_mount.nu`

: App api ( kit_mount parent `/api/v1` )
( app_get api `/items` handler )  // registers /api/v1/items
```

| Function | Signature | Description |
|---|---|---|
| `kit_mount` | `App parent s prefix → App` | Create sub-app sharing parent's Router |

---

### Service Layer (`nurlweb-kit/service.nu`)

Pure-function convention for business logic. No DI, no registry — just import and call.

```nurl
$ `nurlweb-kit/service.nu`
```

| Function | Signature | Description |
|---|---|---|
| `kit_service_exists` | `→ i` | Compile-time sentinel (always returns 0) |

---

### Template Rendering (`nurlweb-kit/view/template.nu`)

`{{key}}` substitution + Layout (`{{% content %}}`) + Include (`{{> path }}`).

```nurl
$ `nurlweb-kit/view/template.nu`
```

| Function | Signature | Description |
|---|---|---|
| `template_render` | `s template ( Vec TemplateVar ) vars → String` | Substitute `{{key}}` + resolve `{{> path }}` |
| `template_render_html` | `s template ( Vec TemplateVar ) vars → String` | Same, with HTML entity escaping |
| `template_render_layout` | `s layout s content ( Vec TemplateVar ) vars → String` | Inject content at `{{% content %}}` |
| `template_file` | `s path ( Vec TemplateVar ) vars → !String IoErr` | Read file, then render |
| `template_var_free` | `TemplateVar tv → v` | Free a TemplateVar |

Max include depth: 8. Unmatched vars emitted as literal `{{key}}`.

---

### Validation (`nurlweb-kit/validation/validate.nu`)

```nurl
$ `nurlweb-kit/validation/validate.nu`
```

JSON schema-style validation against request body.

---

### DoS Protection (`nurlweb/app.nu`)

Built into App via `app_with_dos`:

```nurl
: App protected ( app_with_dos app 512 8 )
( app_serve protected )
```

- `max_conns` — global connection cap (0 = disabled, default)
- `max_per_ip` — per-IP connection cap

---

## Observability

### Access Logging (stdlib)

```nurl
( app_use app \ ( @ HttpResponse HttpRequest ) h → ( @ HttpResponse HttpRequest ) {
    ^ ( with_access_log h )
})
```

### Custom Metrics (stdlib)

```nurl
( app_use app \ ( @ HttpResponse HttpRequest ) h → ( @ HttpResponse HttpRequest ) {
    ^ ( with_metrics h )
})
```

### Composition Pattern

```nurl
// Logging outermost, CORS inside, routes innermost
( app_use app \ ( @ HttpResponse HttpRequest ) h → ( @ HttpResponse HttpRequest ) {
    ^ ( with_access_log h )
})
( app_with_cors app )
```

---

## Architecture

```
User Application
        │
   ┌────┴──────────────────────────┐
   │  nurlweb-kit (Convention)     │  ~2256 LOC
   │  context/ctx.nu               │     Request context, extraction
   │  middleware/                  │     cors, csrf, session, auth, error, ...
   │  orm/orm.nu                   │     SQLite ORM
   │  config.nu                    │     Environment-aware config
   │  controller.nu                │     RESTful routing
   │  lifecycle.nu                 │     App lifecycle hooks
   │  logger.nu                    │     Structured logging
   │  app_mount.nu                 │     Sub-app isolation
   │  view/template.nu             │     Template rendering
   │  validation/validate.nu       │     Request validation
   ├───────────────────────────────┤
   │  nurlweb (Core)               │  ~560 LOC
   │  app.nu                       │     App struct, routes, middleware, serve
   │  respond.nu                   │     Response shortcuts
   │  routegroup.nu                │     Prefix-based route groups
   │  nurlweb.nu                   │     Single-import aggregator
   └────┬──────────────────────────┘
        │
   ┌────┴──────────┐
   │  NURL HTTP     │  stdlib, ~3000 LOC
   │  stdlib        │  Zero forking
   └───────────────┘
```

---

## Running Tests

```bash
# Compile-time unit tests (kit)
./build/nurlc nurlweb-kit/tests/test_basic.nu
./build/nurlc nurlweb-kit/tests/test_session.nu
./build/nurlc nurlweb-kit/tests/test_cors.nu
# ... etc.

# E2E tests (requires network + nurlc built)
NURL_NET_TESTS=1 bash nurlweb/test_e2e.sh
```

---

## Migration from Raw HTTP

**Before (6 lines, ~295 bytes):**
```nurl
: Router r ( router_new )
( router_get r `/` handler )
: ( @ HttpResponse HttpRequest ) base ( \ HttpRequest req → HttpResponse { ^ ( router_handle r req ) } )
: ( @ HttpResponse HttpRequest ) logged ( with_access_log base )
: HttpServer srv ( server_new listener logged )
( server_run srv )
```

**After (2 lines, ~127 bytes — 57% reduction):**
```nurl
: App app ( app_new `0.0.0.0` 8080 )
( app_serve app )
```
