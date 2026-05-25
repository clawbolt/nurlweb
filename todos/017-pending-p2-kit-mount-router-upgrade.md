# TODO: kit_mount — Upgrade to Router-Level Middleware Isolation

## What
Replace the prefix-matching wrapper approach in `kit_mount` with true per-route middleware isolation when nurlweb's router supports it.

## Why
The current `kit_mount` uses a prefix-checking middleware wrapper — it inspects the request path and conditionally applies sub-app middleware. This works but has edge cases (prefix boundaries, trailing slashes) and always runs parent middleware first, even for sub-app routes. True router-level middleware isolation would let each route group have its own complete middleware pipeline without prefix matching.

## Pros
- Clean middleware isolation per route group
- No prefix boundary edge cases
- Parent middleware doesn't run unnecessarily for sub-app routes
- Matches Rails/Rack mount semantics

## Cons
- Requires changes to nurlweb's router (currently single-pipeline)
- Breaking change to app.nu's middleware composition model
- Complex to implement correctly with NURL's closure-based handler model

## Context
Plan-eng-review (2026-05-26) issue #4. CEO review chose the prefix wrapper approach (option A) over deferring. The wrapper is the pragmatic choice for now, but it's a workaround. When nurlweb adds per-route middleware support, kit_mount should be upgraded to use it directly.

## Depends on / blocked by
- Blocked by: nurlweb router per-route middleware support (future nurlweb feature)
- Order: after nurlweb router upgrade, before kit v2
