// nurlweb/cors.nu — CORS middleware for development
//
// Thin wrapper around stdlib with_cors_default. Adds permissive CORS
// headers to every response and handles OPTIONS preflight.
// For production, configure specific origins instead.
//
// API:
//   ( app_with_cors App a )  → v
//
// Usage:
//   ( app_with_cors app )

$ `nurlweb/app.nu`
$ `stdlib/ext/http_full.nu`

// ── app_with_cors — enable permissive CORS on the App ─────────────

@ app_with_cors App a → v {
    ( app_use a \ ( @ HttpResponse HttpRequest ) inner → ( @ HttpResponse HttpRequest ) {
        ^ ( with_cors_default inner )
    })
}
