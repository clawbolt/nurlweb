// nurlweb/respond.nu — Standalone Response Shortcuts
//
// Response helpers that don't require Ctx as first argument — for use
// in middleware and utility functions where Ctx isn't available.
// Same implementation as ctx.nu helpers minus the unused Ctx arg.
//
// API:
//   ( respond_text     i status s body )     → HttpResponse
//   ( respond_json     i status s body )     → HttpResponse
//   ( respond_html     i status s body )     → HttpResponse
//   ( respond_status   i status )            → HttpResponse
//   ( respond_redirect i status s location ) → HttpResponse

$ `stdlib/ext/http_full.nu`

// ── Text responses ────────────────────────────────────────────────────

@ respond_text i status s body → HttpResponse {
    ^ ( response_text status body )
}

@ respond_json i status s body → HttpResponse {
    : HttpResponse r ( response_text status body )
    ( response_set_header r `Content-Type` `application/json; charset=utf-8` )
    ^ r
}

@ respond_html i status s body → HttpResponse {
    : HttpResponse r ( response_text status body )
    ( response_set_header r `Content-Type` `text/html; charset=utf-8` )
    ^ r
}

// ── Status-only ───────────────────────────────────────────────────────

@ respond_status i status → HttpResponse {
    ^ ( response_text status `` )
}

// ── Redirect ──────────────────────────────────────────────────────────

@ respond_redirect i status s location → HttpResponse {
    : HttpResponse r ( response_text status `` )
    ( response_set_header r `Location` location )
    ^ r
}
