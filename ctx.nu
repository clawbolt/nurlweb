// nurlweb/ctx.nu — Rich request context
//
// Provides a unified Ctx (request context) for type-safe param/query/header/
// body extraction and one-line response shortcuts. Layered ON TOP of app.nu —
// import ctx.nu when you want the rich Egg.js-level API.
//
// Response helpers delegate to respond.nu (canonical implementations).
// ctx.nu adds only the Ctx-first API wrapper — zero duplicated header logic.
//
// Ctx is a pure borrowed view over HttpRequest + Params — zero heap allocation,
// no ownership, no DI pointers. ctx_new is a struct literal; no ctx_free needed.
//
// Usage (inline Ctx construction at each route — avoids nurlc IR codegen bug):
//
//   ( app_get app `/users/:id`
//       \ HttpRequest req Params params → HttpResponse {
//           : Ctx ctx ( ctx_new req params )
//           : ?String id ( ctx_param ctx `id` )
//           ?? id {
//               T sid → { ^ ( ctx_json ctx 200 ... ) }
//               F    → { ^ ( ctx_not_found ctx `missing id\n` ) }
//           }
//       })

$ `nurlweb/app.nu`
$ `nurlweb/respond.nu`
$ `stdlib/ext/http_full.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/option.nu`

// ── Ctx — borrowed view over request ──────────────────────────────────

: Ctx {
    HttpRequest req
    Params     params
}

@ ctx_new HttpRequest req Params params → Ctx { ^ @ Ctx { req params } }

// ── Param extraction ─────────────────────────────────────────────────

@ ctx_param Ctx c s name → ?String {
    ^ ( params_get . c params name )
}

@ ctx_param_i Ctx c s name → ?i {
    : ?String s_opt ( ctx_param c name )
    ?? s_opt {
        T raw → {
            : !i ParseErr ir ( string_to_int raw )
            ?? ir {
                T n → {
                    ( string_free raw )
                    ^ @ ?i { T n }
                }
                F _ → {
                    ( string_free raw )
                    ^ @ ?i { F 0 }
                }
            }
        }
        F _ → { ^ @ ?i { F 0 } }
    }
}

// ── URL percent-decoding ─────────────────────────────────────────────
//
// Manual hex decoder — walks the string byte by byte. When it sees '%',
// reads two hex digits and emits the decoded byte. Non-hex %XX sequences
// pass through as literals. Used by ctx_query to decode query parameter
// values that stdlib stores as raw headers.

@ __url_decode s in → String {
    : i in_len ( nurl_str_len in )
    : String out ( string_with_cap in_len )
    : ~ i pos 0
    ~ < pos in_len {
        : i c ( nurl_str_get in pos )
        ? & == c 37 < + pos 2 in_len {
            : i h1 ( nurl_str_get in + pos 1 )
            : i h2 ( nurl_str_get in + pos 2 )
            : i d1 ? >= h1 97 - h1 32 h1
            : i d2 ? >= h2 97 - h2 32 h2
            : i v1 ? >= d1 65 - d1 55 ? >= d1 48 - d1 48 -1
            : i v2 ? >= d2 65 - d2 55 ? >= d2 48 - d2 48 -1
            ? & >= v1 0 >= v2 0 {
                : i decoded + * v1 16 v2
                ( string_push_char out decoded )
                = pos + pos 3
            } {
                ( string_push_char out 37 )
                = pos + pos 1
            }
        } {
            ( string_push_char out c )
            = pos + pos 1
        }
    }
    ^ out
}

// ── Query extraction ─────────────────────────────────────────────────
//
// In NURL's HTTP stack, query parameters are stored in headers alongside
// regular headers — ctx_query delegates to header_get then URL-decodes
// the result (stdlib stores raw %XX-encoded values).
//
// ctx_query_all returns a single-element Option wrapping the decoded
// value — true multi-value support is stdlib-blocked until header_get_all
// exists in the NURL stdlib surface.

@ ctx_query Ctx c s name → ?String {
    : ?String raw ( header_get . c req name )
    ?? raw {
        T val → {
            : String decoded ( __url_decode ( string_data val ) )
            ( string_free val )
            ^ @ ?String { T decoded }
        }
        F → { ^ @ ?String { F } }
    }
}

@ ctx_query_all Ctx c s name → ?( Vec String ) {
    : ?String decoded ( ctx_query c name )
    ?? decoded {
        T val → {
            : Vec<String> vs ( vec_new [String] )
            ( vec_push [String] vs val )
            ^ @ ?( Vec String ) { T vs }
        }
        F → { ^ @ ?( Vec String ) { F @ Vec String {} } }
    }
}

// ── Header extraction ────────────────────────────────────────────────

@ ctx_header Ctx c s name → ?String {
    ^ ( header_get . c req name )
}

// ── Body extraction ──────────────────────────────────────────────────

@ ctx_body_raw Ctx c → s {
    : HttpRequest r . c req
    : i n ( vec_len [u] . r body )
    ? > n 0 {
        : *u data ( vec_data [u] . r body )
        ^ ( string_data ( string_from_bytes data n ) )
    } { ^ `` }
}

@ ctx_body_json Ctx c → !Json ParseErr {
    : s raw ( ctx_body_raw c )
    ? != 0 ( nurl_str_len raw ) {
        ^ ( json_parse raw )
    } {
        ^ @ !Json ParseErr { F @ ParseErr { Empty } }
    }
}

// ── Response helpers (delegate to respond.nu) ─────────────────────────
//
// All helpers take Ctx as first arg for uniform LLM-friendly API surface.
// Ctx is unused — passed through for API consistency only.
// Canonical implementations live in respond.nu.

@ ctx_text Ctx c i status s body → HttpResponse {
    ^ ( respond_text status body )
}

@ ctx_json Ctx c i status s body → HttpResponse {
    ^ ( respond_json status body )
}

@ ctx_html Ctx c i status s body → HttpResponse {
    ^ ( respond_html status body )
}

// ── Status shortcuts ──────────────────────────────────────────────────

@ ctx_ok Ctx c s body → HttpResponse          { ^ ( ctx_text c 200 body ) }
@ ctx_created Ctx c s body → HttpResponse     { ^ ( ctx_text c 201 body ) }
@ ctx_accepted Ctx c s body → HttpResponse    { ^ ( ctx_text c 202 body ) }
@ ctx_no_content Ctx c → HttpResponse         { ^ ( ctx_text c 204 `` ) }
@ ctx_bad_request Ctx c s msg → HttpResponse  { ^ ( ctx_text c 400 msg ) }
@ ctx_unauthorized Ctx c s msg → HttpResponse { ^ ( ctx_text c 401 msg ) }
@ ctx_forbidden Ctx c s msg → HttpResponse    { ^ ( ctx_text c 403 msg ) }
@ ctx_not_found Ctx c s msg → HttpResponse    { ^ ( ctx_text c 404 msg ) }
@ ctx_conflict Ctx c s msg → HttpResponse     { ^ ( ctx_text c 409 msg ) }
@ ctx_error Ctx c s msg → HttpResponse        { ^ ( ctx_text c 500 msg ) }

// ── Redirect ──────────────────────────────────────────────────────────

@ ctx_redirect Ctx c i status s location → HttpResponse {
    ^ ( respond_redirect status location )
}
