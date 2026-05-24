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
git clone https://github.com/clawbolt/nurlweb deps/nurlweb
```

Import in your `.nu` file:

```nurl
$ `deps/nurlweb/nurlweb.nu`   # full framework (App + Ctx)
$ `deps/nurlweb/app.nu`       # micro-framework only
```

## API

See [FRAMEWORK.md](FRAMEWORK.md) for full API reference.

## License

MIT OR Apache-2.0
