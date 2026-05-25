// nurlweb/test_auth.nu — Compile-time unit tests for auth.nu
//
// Run: ./build/nurlc nurlweb/test_auth.nu
// Expected: exit 0

$ `nurlweb/auth.nu`

// ── Test: auth_basic return type ──────────────────────────────────────

@ test_auth_basic Ctx ctx → ?BasicAuth {
    ^ ( auth_basic ctx )
}

// ── Test: auth_bearer return type ─────────────────────────────────────

@ test_auth_bearer Ctx ctx → ?String {
    ^ ( auth_bearer ctx )
}

// ── Test: auth_cookie return type ─────────────────────────────────────

@ test_auth_cookie Ctx ctx → ?String {
    ^ ( auth_cookie ctx `session` )
}

// ── Test: auth_require_basic return type ──────────────────────────────

@ test_auth_require_basic Ctx ctx → !BasicAuth HttpResponse {
    ^ ( auth_require_basic ctx )
}

// ── Test: auth_require_bearer return type ─────────────────────────────

@ test_auth_require_bearer Ctx ctx → !String HttpResponse {
    ^ ( auth_require_bearer ctx )
}

// ── Test: auth_require_basic in handler pattern ───────────────────────

@ test_auth_handler HttpRequest req Params params → HttpResponse {
    : Ctx ctx ( ctx_new req params )
    : !BasicAuth HttpResponse ar ( auth_require_basic ctx )
    ?? ar {
        T ba → {
            : s user ( string_data . ba user )
            : HttpResponse r ( response_text 200 user )
            ( basic_auth_free ba )
            ^ r
        }
        F resp → { ^ resp }
    }
}

// ── Test: auth_require_bearer in handler pattern ──────────────────────

@ test_auth_bearer_handler HttpRequest req Params params → HttpResponse {
    : Ctx ctx ( ctx_new req params )
    : !String HttpResponse tr ( auth_require_bearer ctx )
    ?? tr {
        T token → {
            : HttpResponse r ( response_text 200 token )
            ( string_free token )
            ^ r
        }
        F resp → { ^ resp }
    }
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
