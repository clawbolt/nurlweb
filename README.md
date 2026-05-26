# NurlWeb

LLM-first web framework core for [NURL](https://github.com/nurl-lang/nurl).

NurlWeb is intentionally small: four core modules for app wiring, routes, middleware composition, response shortcuts, and route groups. Higher-level conventions live in the companion [`nurlweb-kit`](https://github.com/clawbolt/nurlweb-kit) repository.

## Layers

| Layer | Repository | Scope |
|---|---|---|
| Core | `nurlweb` | `App`, route registration, middleware pipeline, serving, response helpers, route groups |
| Convention | `nurlweb-kit` | `Ctx`, config, lifecycle, logging, middleware, ORM, templates, validation, CLI scaffolding |
| Runtime | `nurl-lang/stdlib` | HTTP server, router, JSON, async runtime, signals, networking |

## Quick Start

Clone NurlWeb into your project as `nurlweb/`, then link the NURL standard library once:

```bash
git clone https://github.com/clawbolt/nurlweb nurlweb
sh nurlweb/setup.sh /path/to/nurl-lang
```

Create `main.nu`:

```nurl
$ `nurlweb/app.nu`
$ `stdlib/ext/http_full.nu`

@ main → i {
    : App app ( app_new `127.0.0.1` 3000 )

    ( app_get app `/`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `hello from nurlweb!\n` )
        })

    : !v NetErr rr ( app_serve app )
    ?? rr {
        T _ → { ^ 0 }
        F _ → { ^ 1 }
    }
}
```

Compile and link:

```bash
NURLC=/path/to/nurl-lang/build/nurlc
RUNTIME=/path/to/nurl-lang/stdlib/runtime.o

"$NURLC" main.nu > app.ll
clang -O2 app.ll "$RUNTIME" -lm -lpthread \
  $(pkg-config --libs libcurl 2>/dev/null || echo "-lcurl") \
  $(pkg-config --libs openssl 2>/dev/null || echo "-lssl -lcrypto") \
  $(pkg-config --libs sqlite3 2>/dev/null || echo "-lsqlite3") \
  $(pkg-config --libs zlib 2>/dev/null || echo "-lz") \
  $(pkg-config --libs libzstd 2>/dev/null || echo "-lzstd") \
  -o app
./app
```

## Modules

| Module | Description |
|---|---|
| `app.nu` | `App` lifecycle, HTTP route registration, middleware composition, blocking and async serving |
| `respond.nu` | Standalone `respond_text`, `respond_json`, `respond_html`, `respond_status`, `respond_redirect` helpers |
| `routegroup.nu` | Prefix-based route grouping on a shared app router |
| `nurlweb.nu` | Single import aggregator for the core modules |

## Core API

```nurl
$ `nurlweb/nurlweb.nu`
```

### App

| Function | Description |
|---|---|
| `app_new host port` | Create an app bound to `host:port` |
| `app_get/post/put/patch/delete` | Register route handlers with `HttpRequest Params -> HttpResponse` |
| `app_any method route handler` | Register a custom HTTP method |
| `app_use middleware` | Add stdlib-compatible HTTP middleware |
| `app_with_workers n` | Configure async worker count |
| `app_with_dos max_conns max_per_ip` | Enable server-level DoS limits |
| `app_serve` | Run the blocking HTTP server |
| `app_serve_async` | Run the fiber-based async HTTP server |
| `app_free` | Free app-owned router state |

### Responses

```nurl
( respond_text 200 `ok\n` )
( respond_json 201 `{"id":1}\n` )
( respond_html 200 `<h1>Hello</h1>` )
( respond_status 204 )
( respond_redirect 302 `/login` )
```

### Route Groups

```nurl
: RouteGroup api ( app_group app `/api` )

( group_get api `/health`
    \ HttpRequest req Params params → HttpResponse {
        ^ ( respond_json 200 `{"ok":true}\n` )
    })
```

## Examples

| Example | Purpose |
|---|---|
| `examples/hello.nu` | Minimal server and health route |
| `examples/rest_api.nu` | In-memory REST API with JSON parsing and path params |
| `examples/error_demo.nu` | Error response patterns |
| `examples/validate_demo.nu` | Request validation demo |

## Scaffolding and Business Conventions

Use `nurlweb-kit` when you want project scaffolding or batteries-included modules:

```bash
git clone https://github.com/clawbolt/nurlweb-kit nurlweb-kit
./nurlweb-kit/bin/nurlweb-kit new my-api
```

`nurlweb-kit` includes the `Ctx` layer, middleware, ORM, config, lifecycle hooks, templates, validation, and a real Tasker business API example.

## Build and Test

From a workspace that contains `nurlweb/`, `nurlweb-kit/` if needed, and a `stdlib` symlink:

```bash
export NURLC=/path/to/nurl-lang/build/nurlc
export NURL_RUNTIME=/path/to/nurl-lang/stdlib/runtime.o

"$NURLC" nurlweb/examples/hello.nu > /tmp/nurlweb-hello.ll
clang -O2 /tmp/nurlweb-hello.ll "$NURL_RUNTIME" -lm -lpthread \
  $(pkg-config --libs libcurl 2>/dev/null || echo "-lcurl") \
  $(pkg-config --libs openssl 2>/dev/null || echo "-lssl -lcrypto") \
  $(pkg-config --libs sqlite3 2>/dev/null || echo "-lsqlite3") \
  $(pkg-config --libs zlib 2>/dev/null || echo "-lz") \
  $(pkg-config --libs libzstd 2>/dev/null || echo "-lzstd") \
  -o /tmp/nurlweb-hello
```

For network smoke tests:

```bash
NURL_NET_TESTS=1 bash nurlweb/test_e2e.sh
```

## Documentation

See [FRAMEWORK.md](FRAMEWORK.md) for the full API reference and the current split between NurlWeb core and nurlweb-kit.

## License

MIT OR Apache-2.0
