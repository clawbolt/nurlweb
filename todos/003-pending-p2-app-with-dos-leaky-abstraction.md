---
status: complete
priority: p2
tags: [code-review, architecture]
agent: architecture-strategist
file: app.nu:57-61
---

# app_with_dos: Leaky DosLimits Abstraction

## Finding
`app_with_dos` accepts a full `DosLimits` struct but only extracts 2 of its fields (`max_concurrent_conns`, `max_conns_per_ip`). If `DosLimits` gains additional fields in future stdlib versions (e.g., `max_conns_per_route`, `rate_limit_window`), they will be **silently dropped**.

The same issue recurs in `__serve_bind` where a fresh `DosLimits` is constructed from only these two fields.

## Location
- `app.nu:57-59` — `app_with_dos` extracts only 2 fields
- `app.nu:83-86` — `__serve_bind` constructs fresh DosLimits from 2 fields

## Impact
- Future stdlib upgrades could introduce DoS features that nurlweb silently ignores
- The abstraction suggests "pass any DosLimits" but actually only respects 2 fields
- LLM agents using the API might assume full DosLimits support

## Recommendation
**Option A (preferred):** Store the full `DosLimits` in App and pass it through directly:

```nurl
: App {
    // ...
    DosLimits dos_limits
    b dos_enabled
}

@ app_with_dos App a DosLimits dl → App {
    = . a dos_limits dl
    = . a dos_enabled T
    ^ a
}
```

**Option B:** Change API to accept individual fields:
```nurl
@ app_with_dos App a i max_conns i max_per_ip → App { ... }
```

Option B is more YAGNI-compliant and avoids the leaky abstraction entirely.
