// nurlweb/test_respond.nu — Compile-time unit tests for respond.nu
//
// Run: ./build/nurlc nurlweb/test_respond.nu
// Expected: exit 0

$ `nurlweb/respond.nu`

// ── Test: all respond_* functions compile ─────────────────────────────

@ test_respond_text → HttpResponse {
    ^ ( respond_text 200 `hello\n` )
}

@ test_respond_json → HttpResponse {
    ^ ( respond_json 200 `{"ok":true}\n` )
}

@ test_respond_html → HttpResponse {
    ^ ( respond_html 200 `<h1>hi</h1>\n` )
}

@ test_respond_status → HttpResponse {
    ^ ( respond_status 204 )
}

@ test_respond_redirect → HttpResponse {
    ^ ( respond_redirect 302 `/login` )
}

// ── Test: all status codes work ───────────────────────────────────────

@ test_respond_status_400 → HttpResponse { ^ ( respond_status 400 ) }
@ test_respond_status_404 → HttpResponse { ^ ( respond_status 404 ) }
@ test_respond_status_500 → HttpResponse { ^ ( respond_status 500 ) }

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
