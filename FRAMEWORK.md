# NurlWeb — LLM-First Web Framework for NURL

NurlWeb is a layered web framework for [NURL](https://github.com/nurl-lang/nurl).  
**Micro layer** (`app.nu`, ~180 LOC): wiring reduction, routes, middleware, serve.  
**Rich layer** (`ctx.nu`, ~135 LOC): unified request context, extraction, response shortcuts.

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
| `ctx_param_i` | Deferred — nurlc IR bug with `?i` return type |

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
