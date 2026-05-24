# NurlWeb — LLM-First Web Framework for NURL

NurlWeb is a layered web framework for [NURL](https://github.com/nurl-lang/nurl).  
**Micro layer** (`app.nu`, ~180 LOC): wiring reduction, routes, middleware, serve.  
**Rich layer** (`ctx.nu`, ~150 LOC): unified request context, extraction, response shortcuts.
**v1.2 modules:** session, upload, template, cors, SessionStore, Layout/Include, CLI scaffolding.

Design: LLM-optimized. One import. Copy-pasteable examples. Zero forking of NURL stdlib.

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

Or with the rich Ctx layer:

```nurl
$ `nurlweb/nurlweb.nu`
$ `stdlib/ext/http_full.nu`

@ main → i {
    : App app ( app_new `127.0.0.1` 3000 )

    ( app_get app `/users/:id`
        \ HttpRequest req Params params → HttpResponse {
            : Ctx ctx ( ctx_new req params )
            : ?String id ( ctx_param ctx `id` )
            ?? id {
                T sid → { ^ ( ctx_json ctx 200 sid ) }
                F    → { ^ ( ctx_not_found ctx `missing id\n` ) }
            }
        })

    ( app_serve app )
}
```

### CLI Scaffolding

```bash
# Clone nurlweb and use the CLI
git clone https://github.com/clawbolt/nurlweb
./nurlweb/bin/nurlweb new my-api
cd my-api && sh build.sh && ./app
```

---

## API Reference

### App Lifecycle (`app.nu`)

| Function | Signature | Description |
|---|---|---|
| `app_new` | `s host i port → App` | Create app bound to host:port |
| `app_with_workers` | `App a i n → App` | Set async fiber worker count |
| `app_with_dos` | `App a i max_conns i max_per_ip → App` | DoS protection (individual fields, max_conns=0 to disable) |
| `app_free` | `App a → v` | Free router and handler data |

### Routes (`app.nu`)

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

### Middleware (`app.nu`)

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

### Serve (`app.nu`)

| Function | Signature | Description |
|---|---|---|
| `app_serve` | `App a → !v NetErr` | Blocking server (single-threaded). SIGINT/SIGTERM graceful shutdown. |
| `app_serve_async` | `App a → !v NetErr` | Fiber-based server. Use `app_with_workers` to set worker count. |

### Ctx — Request Context (`ctx.nu`)

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

| Function | Signature |
|---|---|
| `ctx_query` | `Ctx c s name → ?String` |
| `ctx_header` | `Ctx c s name → ?String` |

#### Body

| Function | Signature | Description |
|---|---|---|
| `ctx_body_raw` | `Ctx c → s` | Raw body (empty if no body) |
| `ctx_body_json` | `Ctx c → !Json ParseErr` | Parse JSON body |

#### Response Helpers

All take `Ctx` as first arg for uniform API surface (LLM-friendly).

| Function | Signature | Status |
|---|---|---|
| `ctx_text` | `Ctx c i status s body → HttpResponse` | Custom status + body |
| `ctx_json` | `Ctx c i status s body → HttpResponse` | JSON (sets Content-Type) |
| `ctx_html` | `Ctx c i status s body → HttpResponse` | HTML |
| `ctx_ok` | `Ctx c s body → HttpResponse` | 200 |
| `ctx_created` | `Ctx c s body → HttpResponse` | 201 |
| `ctx_accepted` | `Ctx c s body → HttpResponse` | 202 |
| `ctx_no_content` | `Ctx c → HttpResponse` | 204 |
| `ctx_bad_request` | `Ctx c s msg → HttpResponse` | 400 |
| `ctx_unauthorized` | `Ctx c s msg → HttpResponse` | 401 |
| `ctx_forbidden` | `Ctx c s msg → HttpResponse` | 403 |
| `ctx_not_found` | `Ctx c s msg → HttpResponse` | 404 |
| `ctx_conflict` | `Ctx c s msg → HttpResponse` | 409 |
| `ctx_error` | `Ctx c s msg → HttpResponse` | 500 |
| `ctx_redirect` | `Ctx c i status s location → HttpResponse` | Redirect (sets Location header) |

---

## Session Management (`session.nu`)

Two-layer session support: cookie helpers (stateless) + server-side SessionStore.

### Cookie Layer

| Function | Signature | Description |
|---|---|---|
| `session_get` | `Ctx ctx s name → ?String` | Read cookie value |
| `session_set` | `Ctx ctx HttpResponse r s name s value → v` | Set cookie (HttpOnly, Secure, SameSite=Lax, Path=/) |
| `session_del` | `Ctx ctx HttpResponse r s name → v` | Delete cookie (max-age=0) |

### SessionStore Layer (Memory)

| Function | Signature | Description |
|---|---|---|
| `session_store_new` | `→ SessionStore` | Create empty in-memory store |
| `session_store_get` | `SessionStore store s key → ?String` | Read value by key |
| `session_store_set` | `SessionStore store s key s value → v` | Upsert key/value pair |
| `session_store_del` | `SessionStore store s key → v` | Remove key (no-op if missing) |
| `session_store_free` | `SessionStore store → v` | Free all entries |

```nurl
$ `nurlweb/session.nu`

: SessionStore store ( session_store_new )
( session_store_set store `user_id` `42` )
: ?String uid ( session_store_get store `user_id` )
?? uid {
    T id → {
        // Authenticated — load user data
        ( string_free id )
    }
    F _ → {}
}
( session_store_free store )
```

### Usage (Cookie + Store combined)

```nurl
$ `nurlweb/session.nu`

( app_get app `/login`
    \ HttpRequest req Params params → HttpResponse {
        : Ctx ctx ( ctx_new req params )
        : HttpResponse r ( response_text 302 `` )
        ( response_set_header r `Location` `/dashboard` )
        ( session_set ctx r `sid` `session-token-abc123` )
        ^ r
    })

// In app startup, create a shared store:
: SessionStore store ( session_store_new )
// Pass store to handlers via closure capture
```

**Cookie defaults:** Path=`/`, Secure=true, HttpOnly=true, SameSite=Lax.  
**Store interface:** get/set/del — minimal by design. Redis/Postgres backends planned for v2.  
**Max cookie value:** ~3800 bytes (browser ~4KB limit minus attribute overhead).

---

## File Upload (`upload.nu`)

Multipart file upload wrapper around stdlib `http_multipart.nu`.  
Parses `multipart/form-data` into `Vec<MultipartPart>`. Enforces Content-Length limit (default 10 MiB).

### API

| Function | Signature | Description |
|---|---|---|
| `upload_parts` | `Ctx ctx → ?( Vec MultipartPart )` | Parse with default 10 MiB limit |
| `upload_parts_with_limit` | `Ctx ctx i max_bytes → ?( Vec MultipartPart )` | Parse with custom size limit |
| `upload_free` | `( Vec MultipartPart ) parts → v` | Free all multipart parts |

### Usage

```nurl
$ `nurlweb/upload.nu`

( app_post app `/upload`
    \ HttpRequest req Params params → HttpResponse {
        : Ctx ctx ( ctx_new req params )
        : ?( Vec MultipartPart ) parts_opt ( upload_parts ctx )
        ?? parts_opt {
            T parts → {
                : i idx ( multipart_find_first parts `avatar` )
                ? >= idx 0 {
                    // File uploaded — process it
                } {}
                ( upload_free parts )
                ^ ( ctx_ok ctx `uploaded\n` )
            }
            F _ → { ^ ( ctx_bad_request ctx `no upload or too large\n` ) }
        }
    })
```

Use stdlib `multipart_find_first` (returns index) and `vec_get [MultipartPart]` to access individual parts.  
Parts are OWNED — caller must free with `upload_free` after use.

---

## Template Rendering (`template.nu`)

`{{key}}` substitution + Layout (`{{% content %}}`) + Include (`{{> path }}`).  
Uses `Vec<TemplateVar>` — linear scan, optimized for < 20 vars.

### API

| Function | Signature | Description |
|---|---|---|
| `template_render` | `s template ( Vec TemplateVar ) vars → String` | Substitute `{{key}}` + resolve `{{> path }}` includes |
| `template_render_layout` | `s layout s content ( Vec TemplateVar ) vars → String` | Inject content at `{{% content %}}`, then render vars |
| `template_file` | `s path ( Vec TemplateVar ) vars → !String IoErr` | Read file, then render |
| `template_var_free` | `TemplateVar tv → v` | Free a TemplateVar |

### Basic Usage

```nurl
$ `nurlweb/template.nu`

: ( Vec TemplateVar ) vars ( vec_new [TemplateVar] )
: TemplateVar tv @ TemplateVar { ( string_new ) ( string_new ) }
( string_push_str . tv key `name` )
( string_push_str . tv value `Alice` )
( vec_push [TemplateVar] vars tv )

: String out ( template_render `<h1>Hello {{name}}!</h1>` vars )

( template_var_free tv )
( vec_free [TemplateVar] vars )
```

### Layout Usage

```nurl
: s layout `<html><head><title>{{title}}</title></head><body>{{% content %}}</body></html>`
: s content `<p>Welcome, {{user}}!</p>`
: String page ( template_render_layout layout content vars )
```

### Include Usage

```nurl
// header.tmpl: `<header>{{site_name}}</header>`
// footer.tmpl: `<footer>Copyright {{year}}</footer>`
// main.tmpl:  `{{> header.tmpl}}<main>{{body}}</main>{{> footer.tmpl}}`
: String page ( template_render `{{> header.tmpl}}<main>{{body}}</main>{{> footer.tmpl}}` vars )
```

**Max include depth:** 8 (cycles produce depth-limit pass-through).  
**Unmatched vars:** emitted as literal `{{key}}`.  
**Single brace `{{`:** emitted as literal `{{` (no crash).

---

## CORS (`cors.nu`)

Permissive CORS middleware for development. Wraps stdlib `with_cors_default`.

### API

| Function | Signature | Description |
|---|---|---|
| `app_with_cors` | `App a → v` | Enable permissive CORS on the App |

### Usage

```nurl
$ `nurlweb/cors.nu`

: App app ( app_new `127.0.0.1` 8080 )
( app_with_cors app )
// All responses now include Access-Control-Allow-Origin: *
// OPTIONS preflight returns 204 with CORS headers
```

**Headers added:** `Access-Control-Allow-Origin: *`, `Access-Control-Allow-Headers: Content-Type, Authorization`.  
**Production:** pin specific origins via custom middleware using stdlib `response_set_header`.

---

## DoS Protection (`app_with_dos`)

Server-level DoS protection via stdlib `server_new_with_dos`. Wraps TCP-level per-IP connection limiting.  
Accepts individual integer fields (not `DosLimits` struct) to avoid silently dropping fields added in future stdlib versions.

### API

| Function | Signature | Description |
|---|---|---|
| `app_with_dos` | `App a i max_conns i max_per_ip → App` | Configure DoS limits |

### Usage

```nurl
: App app ( app_new `127.0.0.1` 8080 )
: App protected ( app_with_dos app 512 8 )
( app_serve protected )
```

**Parameters:**
- `max_conns` — global connection cap (set to 0 to disable, default: 0)
- `max_per_ip` — per-IP connection cap

When a connection exceeds the DoS cap, the server closes it silently (no HTTP response).  
Per-route rate limiting is deferred to v2+ (requires `peer_addr` on `HttpRequest`).

---

## Observability

NurlWeb integrates with stdlib middleware for logging and metrics.

### Access Logging

```nurl
( app_use app \ ( @ HttpResponse HttpRequest ) h → ( @ HttpResponse HttpRequest ) {
    ^ ( with_access_log h )
})
```

Logs method, path, status code, and duration to stderr on every request.

### Custom Metrics

```nurl
( app_use app \ ( @ HttpResponse HttpRequest ) h → ( @ HttpResponse HttpRequest ) {
    ^ ( with_metrics h )
})
```

Adds `X-Request-Duration-ms` header to responses. Combine with access logging for full request lifecycle visibility.

### Composition Pattern

```nurl
// Logging outermost, CORS inside, routes innermost
( app_use app \ ( @ HttpResponse HttpRequest ) h → ( @ HttpResponse HttpRequest ) {
    ^ ( with_access_log h )
})
( app_with_cors app )
```

Middleware registration order: last registered = innermost (closest to route handler).  
Logging outermost = sees CORS headers + final status. CORS inside = runs before routes.

---

## Architecture

```
User Application
        │
   ┌────┴──────────┐
   │  NurlWeb       │  ← ~1040 LOC total (v1.2)
   │  app.nu (180)  │     Routes, middleware, serve, DoS
   │  ctx.nu (135)  │     Ctx, extraction, response shortcuts
   │  session.nu    │     Cookie + server-side SessionStore
   │  upload.nu     │     Multipart file upload
   │  template.nu   │     {{key}} + Layout + Include
   │  cors.nu       │     CORS middleware
   └────┬──────────┘
        │
   ┌────┴──────────┐
   │  NURL HTTP     │  ← stdlib, ~3,000 LOC
   │  stdlib        │     Zero forking
   └───────────────┘
```

---

## Running Tests

```bash
# Unit tests (compile-time)
./build/nurlc nurlweb/test_basic.nu
./build/nurlc nurlweb/test_ctx.nu
./build/nurlc nurlweb/test_session.nu
./build/nurlc nurlweb/test_upload.nu
./build/nurlc nurlweb/test_template.nu
./build/nurlc nurlweb/test_cors.nu

# E2E tests (requires network)
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
