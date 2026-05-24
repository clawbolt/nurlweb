// nurlweb/static.nu — Static File Serving
//
// Ergonomic wrappers around stdlib/ext/http_static.nu. Two layers:
// ad-hoc serving with Ctx, and route registration convenience.
//
// API:
//   ( static_serve       Ctx ctx s dir )  → HttpResponse
//   ( static_dir         Ctx ctx s dir )  → HttpResponse  (alias)
//   ( static_serve_route App a s prefix s dir ) → v
//   ( static_mime        s ext )          → s            (borrowed)
//
// Usage:
//   // Ad-hoc in a handler:
//   ( app_get app `/assets`
//       \ HttpRequest req Params params → HttpResponse {
//           : Ctx ctx ( ctx_new req params )
//           ^ ( static_serve ctx `./public` )
//       })
//
//   // Convenience route registration:
//   ( static_serve_route app `/static` `./public` )

$ `nurlweb/ctx.nu`
$ `stdlib/ext/http_static.nu`

// ── Ad-hoc serving ────────────────────────────────────────────────────

// Serves a static file from `dir` based on the request path. Delegates to
// stdlib serve_static which handles path safety, MIME detection, and 403/404.
@ static_serve Ctx ctx s dir → HttpResponse {
    : HttpRequest r . ctx req
    ^ ( serve_static dir r )
}

// Alias for discoverability
@ static_dir Ctx ctx s dir → HttpResponse {
    ^ ( static_serve dir ctx )
}

// ── Route registration convenience ────────────────────────────────────

// Registers a GET route at prefix/* that serves files from dir.
// The closure captures `dir` by value (s pointer).
@ static_serve_route App a s prefix s dir → v {
    // Use prefix directly — http_router matches the full path including /*
    : s route_path ( nurl_str_cat prefix `/*path` )
    ( app_get a route_path
        \ HttpRequest req Params params → HttpResponse {
            ^ ( serve_static dir req )
        })
}

// ── MIME lookup ───────────────────────────────────────────────────────

// Delegates to stdlib mime_for_ext. Returns borrowed s literal.
@ static_mime s ext → s {
    ^ ( mime_for_ext ext )
}
