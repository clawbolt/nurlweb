# NurlWeb

LLM-first web framework for [NURL](https://github.com/nurl-lang/nurl).

**Micro layer** — ~180 LOC, 7 function names. Wiring reduction: 6 lines → 2.  
**Rich layer** — ~150 LOC. Unified Ctx: typed extraction, response shortcuts.  
**v1.2 modules** — session store, file upload, template layout/include, CORS, CLI scaffolding.

## Quick Start

### Scaffold a new project

```bash
git clone https://github.com/clawbolt/nurlweb
./nurlweb/bin/nurlweb new my-api
cd my-api && sh build.sh && ./app
```

### Or start from scratch

```nurl
$ `nurlweb/app.nu`
$ `stdlib/ext/http_full.nu`

@ main → i {
    : App app ( app_new `127.0.0.1` 3000 )
    ( app_get app `/`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `hello\n` )
        })
    ( app_serve app )
}
```

## Features

| Module | Functions | Description |
|--------|-----------|-------------|
| `app.nu` | app_new, app_get/post/put/patch/delete/any, app_use, app_with_workers, app_with_dos, app_serve, app_serve_async, app_free | Routing, middleware, server lifecycle, DoS protection |
| `ctx.nu` | ctx_new, ctx_param, ctx_param_i, ctx_query, ctx_header, ctx_body_raw, ctx_body_json, ctx_text/json/html, ctx_ok/created/not_found/... | Rich request context with typed extraction and response helpers |
| `session.nu` | session_get, session_set, session_del, session_store_new/get/set/del/free | Cookie + server-side SessionStore (Memory) |
| `upload.nu` | upload_parts, upload_parts_with_limit, upload_free | Multipart file upload with size limits |
| `template.nu` | template_render, template_render_layout, template_file | `{{key}}` + Layout (`{{% content %}}`) + Include (`{{> path }}`) |
| `cors.nu` | app_with_cors | Permissive CORS middleware for development |
| `validate.nu` | schema_new, schema_field, validate_json | JSON schema validation (Zod-style) |
| `error.nu` | app_error_new, app_error_middleware | Structured error handling |
| `respond.nu` | ok, created, not_found, bad_request, ... | Standalone response shortcuts |
| `auth.nu` | auth_basic, auth_bearer | Auth header extraction |
| `static.nu` | static_serve, static_serve_route | Static file serving |
| `ws.nu` | ws_upgrade | WebSocket integration |

## Install

```bash
# Clone alongside your NURL project (the framework expects the directory name `nurlweb/`)
git clone https://github.com/clawbolt/nurlweb nurlweb
```

Import in your `.nu` file:

```nurl
$ `nurlweb/nurlweb.nu`   # full framework (App + Ctx)
$ `nurlweb/app.nu`       # micro-framework only
```

## API

See [FRAMEWORK.md](FRAMEWORK.md) for full API reference.

## Build & Test

Requires the [NURL compiler](https://github.com/nurl-lang/nurl) built alongside.

```bash
# Unit tests (compile-time — no network)
../nurl/build/nurlc nurlweb/test_basic.nu
../nurl/build/nurlc nurlweb/test_ctx.nu
../nurl/build/nurlc nurlweb/test_session.nu
../nurl/build/nurlc nurlweb/test_upload.nu
../nurl/build/nurlc nurlweb/test_template.nu
../nurl/build/nurlc nurlweb/test_cors.nu

# E2E smoke tests (requires network)
NURL_NET_TESTS=1 bash nurlweb/test_e2e.sh
```

## License

MIT OR Apache-2.0
