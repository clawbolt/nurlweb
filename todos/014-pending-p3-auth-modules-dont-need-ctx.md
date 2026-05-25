---
status: pending
priority: p3
tags: [code-review, architecture]
agent: code-simplicity-reviewer
---

# P3: auth.nu / session.nu / static.nu depend on ctx.nu but only use HttpRequest

## Finding
`auth_basic`, `auth_require_bearer`, `session_get`, `static_serve` all take `Ctx ctx` but immediately extract `HttpRequest r . ctx req` and use only `r`. They don't need Ctx — they need HttpRequest.

```nurl
@ auth_basic Ctx ctx → ?BasicAuth {
    : HttpRequest r . ctx req
    ^ ( parse_basic_auth r )
}
```

This creates unnecessary dependency on ctx.nu and prevents using these modules standalone.

## Recommendation
Change signature to take `HttpRequest` directly. This decouples auth/session/static from the Ctx layer and makes them usable without the full framework.
