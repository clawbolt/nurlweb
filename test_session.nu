// nurlweb/test_session.nu — Compile-time unit tests for session.nu
//
// Verifies that session types and functions compile correctly.
// Run: ./build/nurlc nurlweb/test_session.nu
// Expected: exit 0

$ `nurlweb/ctx.nu`
$ `nurlweb/session.nu`
$ `stdlib/ext/http_full.nu`
$ `stdlib/ext/http_auth.nu`
$ `stdlib/core/string.nu`

// ── Test: session_get compiles ────────────────────────────────────────

@ test_session_get Ctx ctx → ?String {
    ^ ( session_get ctx `session_id` )
}

// ── Test: session_set compiles ────────────────────────────────────────

@ test_session_set Ctx ctx HttpResponse r → v {
    ( session_set ctx r `token` `abc123xyz` )
}

// ── Test: session_del compiles ────────────────────────────────────────

@ test_session_del Ctx ctx HttpResponse r → v {
    ( session_del ctx r `token` )
}

// ── Test: full session flow in a handler ──────────────────────────────

@ test_session_handler HttpRequest req Params params → HttpResponse {
    : Ctx ctx ( ctx_new req params )
    : HttpResponse r ( response_text 200 `ok\n` )
    : ?String session_val ( session_get ctx `sid` )
    ?? session_val {
        T sv → {
            ( string_free sv )
        }
        F _ → {}
    }
    ( session_set ctx r `sid` `new_session_val` )
    ^ r
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
