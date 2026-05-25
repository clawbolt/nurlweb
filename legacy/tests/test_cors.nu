// nurlweb/test_cors.nu — Compile-time unit tests for cors.nu
//
// Verifies that app_with_cors compiles and integrates with App.
// Run: ./build/nurlc nurlweb/test_cors.nu
// Expected: exit 0

$ `nurlweb/app.nu`
$ `nurlweb/cors.nu`
$ `stdlib/ext/http_full.nu`

// ── Test: app_with_cors compiles ──────────────────────────────────

@ test_cors_default → v {
    : App a ( app_new `127.0.0.1` 8080 )

    ( app_get a `/`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `ok\n` )
        })

    ( app_with_cors a )
    ( app_free a )
}

// ── Test: cors + route handler returns expected headers shape ─────

@ test_cors_preflight → HttpResponse {
    // Simulate the shape: with_cors_default adds headers + handles OPTIONS
    : App a ( app_new `127.0.0.1` 8080 )

    ( app_get a `/api`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `data\n` )
        })

    ( app_with_cors a )
    ( app_free a )

    // Can't run the server in a compile test, but verifying that
    // the middleware composition compiles is the key invariant.
    ^ ( response_text 200 `ok\n` )
}

// ── Main ──────────────────────────────────────────────────────────

@ main → i { ^ 0 }
