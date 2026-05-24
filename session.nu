// nurlweb/session.nu — Cookie-based session management
//
// Ergonomic wrapper around stdlib http_auth.nu cookie primitives.
// Stateless: all data lives in the cookie — no server-side store.
// Production defaults: HttpOnly, Secure, SameSite=Lax, Path=/.
// Cookie size limit: browsers enforce ~4KB total per domain. The value
// passed to session_set should stay under ~3800 bytes to leave headroom
// for cookie attributes (Path, Secure, HttpOnly, SameSite).
//
// MAX_COOKIE_VALUE = 3800
//
// API:
//   ( session_get Ctx ctx s name )                       → ?String
//   ( session_set Ctx ctx HttpResponse r s name s value ) → v
//   ( session_del Ctx ctx HttpResponse r s name )         → v
//
// Usage:
//   : ?String sid ( session_get ctx `session_id` )
//   ( session_set ctx res `session_id` `abc123` )
//   ( session_del ctx res `session_id` )

$ `nurlweb/ctx.nu`
$ `stdlib/ext/http_auth.nu`
$ `stdlib/core/string.nu`

// ── session_get — read a cookie value ────────────────────────────────

@ session_get Ctx ctx s name → ?String {
    ^ ( request_cookie . ctx req name )
}

// ── session_set — set a cookie with sensible defaults ────────────────

@ session_set Ctx ctx HttpResponse r s name s value → v {
    : CookieOpts opts ( cookie_opts_default )
    = . opts path `/`
    = . opts secure T
    = . opts http_only T
    = . opts same_site @ SameSite { SameSiteLax }
    ( response_set_cookie r name value opts )
}

// ── session_del — delete a cookie (max-age=0) ────────────────────────

@ session_del Ctx ctx HttpResponse r s name → v {
    : CookieOpts opts ( cookie_opts_default )
    = . opts path `/`
    = . opts max_age 0
    = . opts secure T
    = . opts http_only T
    = . opts same_site @ SameSite { SameSiteLax }
    ( response_set_cookie r name `` opts )
}
