// nurlweb/test_logger.nu — Compile-time tests for logger.nu
//
// Run: ./build/nurlc nurlweb/test_logger.nu
// Expected: exit 0

$ `nurlweb/app.nu`
$ `nurlweb/ctx.nu`
$ `nurlweb/logger.nu`
$ `stdlib/ext/http_full.nu`

// ── Test: ctx_request_id compiles ────────────────────────────────────

@ test_request_id HttpRequest req Params params → ?String {
    : Ctx ctx ( ctx_new req params )
    ^ ( ctx_request_id ctx )
}

// ── Test: app_with_logger compiles as middleware ─────────────────────

@ test_app_with_logger → v {
    : App a ( app_new `127.0.0.1` 5000 )
    ( app_get a `/`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `ok\n` )
        })
    ( app_with_logger a )
    ( app_free a )
}

// ── Test: logger + error middleware compose ──────────────────────────

@ test_logger_error_compose → v {
    : App a ( app_new `127.0.0.1` 5001 )
    ( app_get a `/`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 404 `not found\n` )
        })
    ( app_with_logger a )
    ( app_free a )
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
