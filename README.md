# NurlWeb

LLM-first web framework for [NURL](https://github.com/nurl-lang/nurl).

**Micro layer** — ~180 LOC, 6 function names. Wiring reduction: 6 lines → 2.  
**Rich layer** — ~135 LOC. Unified Ctx: typed extraction, response shortcuts.

## Quick Start

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

# E2E smoke tests (requires network)
NURL_NET_TESTS=1 bash nurlweb/test_e2e.sh
```

## License

MIT OR Apache-2.0
