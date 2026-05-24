# NurlWeb — LLM-First Web Framework for NURL

NurlWeb is a layered web framework for [NURL](https://github.com/nurl-lang/nurl).  
**Micro layer** (`app.nu`, ~180 LOC): wiring reduction, routes, middleware, serve.  
**Rich layer** (`ctx.nu`, ~150 LOC): unified request context, extraction, response shortcuts.

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

---

## API Reference

### App Lifecycle (`app.nu`)

| Function | Signature | Description |
|---|---|---|
| `app_new` | `s host i port → App` | Create app bound to host:port |
| `app_with_workers` | `App a i n → App` | Set async fiber worker count |
| `app_with_dos` | `App a DosLimits dl → App` | Set DoS protection limits |
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
| `ctx_redirect` | `Ctx c i status s location → HttpResponse` | Redirect |

---

## Patterns

### State Sharing (Closure Capture)

```nurl
: Database db ( db_open `app.db` )

( app_get app `/users/:id`
    \ HttpRequest req Params params → HttpResponse {
        // db captured from outer scope
        ^ ( db_query_user db ... )
    })
```

### Route Groups (Manual Prefix)

```nurl
: s v1 `/api/v1`
( app_get app ( nurl_str_cat v1 `/users` ) handler )
( app_get app ( nurl_str_cat v1 `/tasks` ) handler )
```

### JSON Body + Response

```nurl
( app_post app `/data`
    \ HttpRequest req Params params → HttpResponse {
        : Ctx ctx ( ctx_new req params )
        : !Json ParseErr jr ( ctx_body_json ctx )
        ?? jr {
            T _ → { ^ ( ctx_ok ctx `parsed!\n` ) }
            F _ → { ^ ( ctx_bad_request ctx `{"error":"invalid json"}\n` ) }
        }
    })
```

### Path Parameter

```nurl
( app_get app `/items/:id`
    \ HttpRequest req Params params → HttpResponse {
        : Ctx ctx ( ctx_new req params )
        : ?String id ( ctx_param ctx `id` )
        ?? id {
            T sid → { ^ ( ctx_json ctx 200 sid ) }
            F    → { ^ ( ctx_not_found ctx `missing id\n` ) }
        }
    })
```

---

## Known Limitations

0. **No body size limit.** `ctx_body_raw` and `ctx_body_json` read the entire
   request body into memory without bounds checking. Callers should validate
   `Content-Length` before reading large bodies, or use streaming reads
   (available in NURL stdlib via `tcp_read_chunk`).

1. **Bare `@`-fn names don't auto-coerce to closures.** Wrap in closure literals: `\ args → R { ^ ( fn args ) }`. (NURL compiler limitation.)

2. **`ctx_param_i` deferred** — nurlc IR bug with `?i` (Option<int>) return type. Use `ctx_param` + inline `string_to_int` instead.

3. **`app_group` deferred to v1.1** — requires sub-router mounting primitives not in stdlib. Use manual prefix variables.

4. **Middleware must be closure-wrapped** — same bare `@`-fn limitation.

5. **No extractors, validators, or standalone response shortcuts in v1.** Deferred to v1.1.

---


---

## Session Management (`session.nu`)

Cookie-based session management wrapping stdlib `http_auth.nu` primitives.  
Stateless — all data lives in the cookie. Production defaults: HttpOnly, Secure, SameSite=Lax, Path=/.

### API

| Function | Signature | Description |
|---|---|---|
| `session_get` | `Ctx ctx s name → ?String` | Read a cookie value from the request |
| `session_set` | `Ctx ctx HttpResponse r s name s value → v` | Set a cookie with production defaults |
| `session_del` | `Ctx ctx HttpResponse r s name → v` | Delete a cookie (max-age=0) |

### Usage

```nurl
$ `nurlweb/session.nu`

( app_get app `/dashboard`
    \ HttpRequest req Params params → HttpResponse {
        : Ctx ctx ( ctx_new req params )
        : HttpResponse r ( response_text 200 `ok
` )
        : ?String sid ( session_get ctx `session_id` )
        ?? sid {
            T sv → { ( string_free sv ) }
            F _ → {
                // Redirect to login
                ^ ( ctx_redirect ctx 302 `/login` )
            }
        }
        ( session_set ctx r `last_visit` `2026-05-25` )
        ^ r
    })
```

### Cookie Defaults

- **Path**: `/`
- **Secure**: true
- **HttpOnly**: true
- **SameSite**: Lax

To customize cookie options, use stdlib `response_set_cookie` directly with `CookieOpts`.

---

## File Upload (`upload.nu`)

Multipart file upload wrapper around stdlib `http_multipart.nu`.  
Parses `multipart/form-data` into `Vec<MultipartPart>`.

### API

| Function | Signature | Description |
|---|---|---|
| `upload_parts` | `Ctx ctx → ?( Vec MultipartPart )` | Parse multipart body, returns owned parts |
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
                ^ ( ctx_ok ctx `uploaded
` )
            }
            F _ → { ^ ( ctx_bad_request ctx `no upload
` ) }
        }
    })
```

Use stdlib `multipart_find_first` (returns index) and `vec_get [MultipartPart]` to access individual parts.  
Parts are OWNED — caller must free with `upload_free` after use.

---

## Template Rendering (`template.nu`)

Minimal `{{key}}` string template rendering. Uses `Vec<TemplateVar>` for variable substitution — linear scan, optimized for < 20 vars typical in production.

### API

| Function | Signature | Description |
|---|---|---|
| `template_render` | `s template ( Vec TemplateVar ) vars → String` | Substitute `{{key}}` in template |
| `template_file` | `s path ( Vec TemplateVar ) vars → !String IoErr` | Read file, then render |
| `template_var_free` | `TemplateVar tv → v` | Free a TemplateVar |

### Usage

```nurl
$ `nurlweb/template.nu`

: ( Vec TemplateVar ) vars ( vec_new [TemplateVar] )
: TemplateVar tv @ TemplateVar { ( string_new ) ( string_new ) }
( string_push_str . tv key `name` )
( string_push_str . tv value `Alice` )
( vec_push [TemplateVar] vars tv )

: String out ( template_render `<h1>Hello {{name}}!</h1>` vars )
// out = "<h1>Hello Alice!</h1>"

// Cleanup
( template_var_free tv )
( vec_free [TemplateVar] vars )
```

**Placeholder syntax:** `{{key}}` — key name is case-sensitive, no whitespace trimming.  
**Unmatched keys:** kept as literal `{{key}}` in output.  
**NURL Map:** not used — NURL Map stores `i64` values only, not strings.

---

## DoS Protection (`app_with_dos`)

Server-level DoS protection via stdlib `server_new_with_dos`. Wraps TCP-level per-IP connection limiting.

### API

| Function | Signature | Description |
|---|---|---|
| `app_with_dos` | `App a DosLimits dl → App` | Configure DoS limits |

### Usage

```nurl
: App app ( app_new `127.0.0.1` 8080 )
: DosLimits dl ( dos_default_limits )
= . dl max_concurrent_conns 512
= . dl max_conns_per_ip 8
: App protected ( app_with_dos app dl )
( app_serve protected )
```

**`DosLimits` fields:**
- `max_concurrent_conns` — global connection cap (default: 1024)
- `max_conns_per_ip` — per-IP connection cap (default: 16)

When a connection exceeds the DoS cap, the server closes it silently (no HTTP response).  
Per-route rate limiting is deferred to v2+ (requires `peer_addr` on `HttpRequest`).

---

## Architecture

```
User Application
        │
   ┌────┴──────────┐
   │  NurlWeb       │  ← ~315 LOC total
   │  app.nu (180)  │     Routes, middleware, serve
   │  ctx.nu (135)  │     Ctx, extraction, response
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
