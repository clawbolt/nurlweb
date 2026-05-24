// nurlweb/auth.nu — Auth Helpers (Ctx-style)
//
// Ergonomic wrappers around stdlib/ext/http_auth.nu. Uses Ctx as the
// unifying argument for LLM-friendly consistency.
//
// API:
//   ( auth_basic          Ctx ctx )  → ?BasicAuth
//   ( auth_bearer         Ctx ctx )  → ?String
//   ( auth_require_basic  Ctx ctx )  → !BasicAuth HttpResponse
//   ( auth_require_bearer Ctx ctx )  → !String    HttpResponse
//   ( auth_cookie         Ctx ctx s name ) → ?String
//
// Usage:
//   : !BasicAuth HttpResponse ar ( auth_require_basic ctx )
//   ?? ar {
//       T ba → { ... use ba.user / ba.pass ... }
//       F resp → { ^ resp }  // 401 with WWW-Authenticate
//   }

$ `nurlweb/ctx.nu`
$ `stdlib/ext/http_auth.nu`

// ── Optional auth (returns None if no credentials) ────────────────────

// Intermediate HttpRequest extraction avoids nested field access IR quirk.

@ auth_basic Ctx ctx → ?BasicAuth {
    : HttpRequest r . ctx req
    ^ ( parse_basic_auth r )
}

@ auth_bearer Ctx ctx → ?String {
    : HttpRequest r . ctx req
    ^ ( parse_bearer_auth r )
}

@ auth_cookie Ctx ctx s name → ?String {
    : HttpRequest r . ctx req
    ^ ( request_cookie r name )
}

// ── Required auth (returns 401 HttpResponse on failure) ───────────────

@ auth_require_basic Ctx ctx → !BasicAuth HttpResponse {
    : HttpRequest r . ctx req
    : ?BasicAuth ba_opt ( parse_basic_auth r )
    ?? ba_opt {
        T ba → { ^ @ !BasicAuth HttpResponse { T ba } }
        F → {
            : HttpResponse resp ( response_text 401 `Unauthorized\n` )
            ( response_set_header resp
                `WWW-Authenticate` `Basic realm=\"nurlweb\", charset=\"UTF-8\"` )
            ^ @ !BasicAuth HttpResponse { F resp }
        }
    }
}

@ auth_require_bearer Ctx ctx → !String HttpResponse {
    : HttpRequest r . ctx req
    : ?String tok_opt ( parse_bearer_auth r )
    ?? tok_opt {
        T token → { ^ @ !String HttpResponse { T token } }
        F → {
            : HttpResponse resp ( response_text 401 `Unauthorized\n` )
            ( response_set_header resp
                `WWW-Authenticate` `Bearer realm=\"nurlweb\"` )
            ^ @ !String HttpResponse { F resp }
        }
    }
}
