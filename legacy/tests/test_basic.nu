// nurlweb/test_basic.nu — Compile-time unit tests for app.nu
//
// Verifies that core types and functions compile correctly.
// Run: ./build/nurlc nurlweb/test_basic.nu
// Expected: exit 0 (clean compile — no IR generation needed)

$ `nurlweb/app.nu`
$ `stdlib/ext/http_full.nu`

// ── Test: app_new creates App with correct fields ─────────────────────

@ test_app_new → App {
    ^ ( app_new `127.0.0.1` 8080 )
}

// ── Test: app_with_workers sets worker_count ──────────────────────────

@ test_app_workers_count → i {
    : App a ( app_new `0.0.0.0` 3000 )
    : App b ( app_with_workers a 4 )
    ^ . b worker_count
}

// ── Test: app_with_dos sets per-IP DoS limits (individual fields) ─────

@ test_app_dos → i {
    : App a ( app_new `0.0.0.0` 4000 )
    : App b ( app_with_dos a 512 8 )
    : i mc . b dos_max_conns
    ^ mc
}

// ── Test: route registration compiles ─────────────────────────────────

@ test_routes → v {
    : App a ( app_new `127.0.0.1` 9000 )

    // GET route
    ( app_get a `/`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `ok\n` )
        })

    // POST route
    ( app_post a `/data`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 201 `created\n` )
        })

    // Route with path param
    ( app_get a `/items/:id`
        \ HttpRequest req Params params → HttpResponse {
            : ?String id ( params_get params `id` )
            ?? id {
                T sid → { ^ ( response_text 200 sid ) }
                F    → { ^ ( response_text 404 `not found\n` ) }
            }
        })

    // any method
    ( app_any a `PATCH` `/patch`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `patched\n` )
        })

    ( app_free a )
}

// ── Test: middleware composition (progressive) ────────────────────────

@ test_middleware → v {
    : App a ( app_new `127.0.0.1` 9001 )

    ( app_get a `/`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `base\n` )
        })

    // Register middleware — uses same combinator shape as http_middleware.nu
    ( app_use a
        \ ( @ HttpResponse HttpRequest ) h → ( @ HttpResponse HttpRequest ) {
            ^ ( with_access_log h )
        })

    ( app_use a
        \ ( @ HttpResponse HttpRequest ) h → ( @ HttpResponse HttpRequest ) {
            ^ ( with_cors_default h )
        })

    ( app_free a )
}

// ── Test: app_free cleans up ──────────────────────────────────────────

@ test_free → v {
    : App a ( app_new `127.0.0.1` 10000 )
    ( app_get a `/`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `x\n` )
        })
    ( app_free a )
}

// ── Main (trivial — tests are compile-time only) ──────────────────────

@ main → i { ^ 0 }
