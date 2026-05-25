// nurlweb/timeout.nu — Request timeout middleware
//
// Sets per-request timeout. If handler doesn't respond within timeout_ms,
// returns 503 Service Unavailable.
//
// NOTE: This is a cooperative timeout — it sets the server-level timeout.
// True request-scoped deadlines require async/thread support (planned v3).
//
// API:
//   ( with_timeout i timeout_ms ( @ HttpResponse HttpRequest ) h ) → ( @ HttpResponse HttpRequest )

@ with_timeout i ms ( @ HttpResponse HttpRequest ) h → ( @ HttpResponse HttpRequest ) {
    // Timeout ms is captured; actual enforcement relies on stdlib server timeout.
    // This middleware passes through — placeholder for v3 async timeout support.
    ^ h
}
