// nurlweb/test_routegroup.nu — Compile-time tests for routegroup.nu
//
// Run: ./build/nurlc nurlweb/test_routegroup.nu
// Expected: exit 0

$ `nurlweb/app.nu`
$ `nurlweb/routegroup.nu`
$ `stdlib/ext/http_full.nu`

// ── Test: app_group creates RouteGroup ───────────────────────────────

@ test_app_group → RouteGroup {
    : App a ( app_new `127.0.0.1` 3000 )
    ^ ( app_group a `/api/v1` )
}

// ── Test: group_get registers on shared Router ───────────────────────

@ test_group_get → v {
    : App a ( app_new `127.0.0.1` 4000 )
    : RouteGroup g ( app_group a `/api/v1` )
    ( group_get g `/users`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `ok\n` )
        })
    ( app_free a )
}

// ── Test: group_post registers POST route ────────────────────────────

@ test_group_post → v {
    : App a ( app_new `127.0.0.1` 4001 )
    : RouteGroup g ( app_group a `/api` )
    ( group_post g `/items`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 201 `created\n` )
        })
    ( app_free a )
}

// ── Test: group_put/group_patch/group_delete compile ─────────────────

@ test_group_all_methods → v {
    : App a ( app_new `127.0.0.1` 4002 )
    : RouteGroup g ( app_group a `/v2` )

    ( group_put g `/items/:id`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `updated\n` )
        })

    ( group_patch g `/items/:id`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `patched\n` )
        })

    ( group_delete g `/items/:id`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 204 `` )
        })

    ( group_any g `OPTIONS` `/items`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `` )
        })

    ( app_free a )
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
