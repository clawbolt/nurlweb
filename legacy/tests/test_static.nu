// nurlweb/test_static.nu — Compile-time unit tests for static.nu
//
// Run: ./build/nurlc nurlweb/test_static.nu
// Expected: exit 0

$ `nurlweb/static.nu`

// ── Test: static_serve return type ────────────────────────────────────

@ test_static_serve Ctx ctx → HttpResponse {
    ^ ( static_serve ctx `./public` )
}

// ── Test: static_dir alias ────────────────────────────────────────────

@ test_static_dir Ctx ctx → HttpResponse {
    ^ ( static_dir ctx `./public` )
}

// ── Test: static_serve_route compiles ─────────────────────────────────

@ test_static_serve_route → v {
    : App a ( app_new `127.0.0.1` 9005 )
    ( static_serve_route a `/assets` `./public` )
    ( app_free a )
}

// ── Test: static_mime lookup ──────────────────────────────────────────

@ test_static_mime → s {
    ^ ( static_mime `html` )
}

@ test_static_mime_css → s {
    ^ ( static_mime `css` )
}

@ test_static_mime_unknown → s {
    ^ ( static_mime `xyzzy` )
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
