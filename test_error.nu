// nurlweb/test_error.nu — Compile-time unit tests for error.nu
//
// Verifies that AppError types, error constructors, app_catch middleware,
// and the default JSON renderer all compile.
// Run: ./build/nurlc nurlweb/test_error.nu
// Expected: exit 0

$ `nurlweb/error.nu`
$ `stdlib/ext/http_full.nu`

// ── Test: error constructors compile ──────────────────────────────────

@ test_error_not_found → HttpResponse {
    ^ ( error_not_found `item_missing` `Item not found` )
}

@ test_error_validation → HttpResponse {
    ^ ( error_validation `bad_input` `Name is required` )
}

@ test_error_unauthorized → HttpResponse {
    ^ ( error_unauthorized `no_token` `Missing auth token` )
}

@ test_error_forbidden → HttpResponse {
    ^ ( error_forbidden `no_access` `Admin only` )
}

@ test_error_conflict → HttpResponse {
    ^ ( error_conflict `dup_key` `Already exists` )
}

@ test_error_internal → HttpResponse {
    ^ ( error_internal `db_down` `Database unavailable` )
}

// ── Test: AppError struct field access ────────────────────────────────

@ test_app_error_fields → i {
    : AppError ae @ AppError { 404 `not_found` `missing` }
    : i status . ae status
    : s code . ae code
    : s msg . ae message
    ^ status
}

// ── Test: app_catch middleware compiles ───────────────────────────────

@ test_app_catch → v {
    : App a ( app_new `127.0.0.1` 9001 )

    ( app_get a `/`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( error_not_found `gone` `Nothing here` )
        })

    ( app_catch a
        \ HttpResponse orig AppError ae → HttpResponse {
            ^ ( error_render_json orig ae )
        })

    ( app_free a )
}

// ── Test: error_render_json compiles ──────────────────────────────────

@ test_error_render_json → HttpResponse {
    : HttpResponse orig ( error_not_found `test` `test message` )
    : AppError ae @ AppError { 404 `test` `test message` }
    ^ ( error_render_json orig ae )
}

// ── Test: app_catch passes through non-error responses ────────────────

@ test_app_catch_passthrough → v {
    : App a ( app_new `127.0.0.1` 9002 )

    ( app_get a `/ok`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `all good\n` )
        })

    ( app_catch a
        \ HttpResponse orig AppError ae → HttpResponse {
            ^ ( error_render_json orig ae )
        })

    ( app_free a )
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
