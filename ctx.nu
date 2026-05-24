// nurlweb/ctx.nu — Rich request context
//
// Provides a unified Ctx (request context) for type-safe param/query/header/
// body extraction and one-line response shortcuts. Layered ON TOP of app.nu —
// import ctx.nu when you want the rich Egg.js-level API.
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


// ── Query extraction ─────────────────────────────────────────────────
//
// In NURL's HTTP stack, query parameters are stored in headers alongside
// regular headers — both ctx_query and ctx_header delegate to header_get.
// This is correct per the stdlib contract; a dedicated query parser may
// be added when http_router.nu grows query-string support.

@ ctx_query Ctx c s name → ?String {
    ^ ( header_get . c req name )
}

// ── Header extraction ────────────────────────────────────────────────

@ ctx_header Ctx c s name → ?String {
    ^ ( header_get . c req name )
}

// ── Body extraction ──────────────────────────────────────────────────

@ ctx_body_raw Ctx c → s {
    // Use intermediate HttpRequest binding to avoid nested field access
    // IR quirk: `. c req body` inside closures needs intermediate extraction
    : HttpRequest r . c req
    : i n ( vec_len [u] . r body )
    ? > n 0 {
        : *u data ( vec_data [u] . r body )
        ^ ( string_data ( string_from_bytes data n ) )
    } { ^ `` }
}

// Delegates to ctx_body_raw for body extraction; parses the result as JSON.
@ ctx_body_json Ctx c → !Json ParseErr {
    : s raw ( ctx_body_raw c )
    ? != 0 ( nurl_str_len raw ) {
        ^ ( json_parse raw )
    } {
        ^ @ !Json ParseErr { F @ ParseErr { Empty } }
    }
}

// ── Response helpers ──────────────────────────────────────────────────

// All helpers take Ctx as first arg for uniform LLM-friendly API surface.
// Ctx is unused by response helpers — serves as namespace prefix.

@ ctx_text Ctx c i status s body → HttpResponse {
    ^ ( response_text status body )
}

@ ctx_json Ctx c i status s body → HttpResponse {
    : HttpResponse r ( response_text status body )
    ( response_set_header r `Content-Type` `application/json` )
    ^ r
}

@ ctx_html Ctx c i status s body → HttpResponse {
    : HttpResponse r ( response_text status body )
    ( response_set_header r `Content-Type` `text/html; charset=utf-8` )
    ^ r
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
    : HttpResponse r ( response_text status `` )
    ( response_set_header r `Location` location )
    ^ r
}
