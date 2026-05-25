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
$ `stdlib/ext/http_multipart.nu`
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
            : Vec String vs ( vec_new [String] )
            ( vec_push [String] vs val )
            ^ @ ?( Vec String ) { T vs }
        }
        F → { ^ @ ?( Vec String ) { F } }
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
// ── UrlEncodedPair — key/value from form-urlencoded body ──────────

: UrlEncodedPair {
    String key
    String value
}

// ── Body parsers (form, urlencoded, text) ────────────────────────────
//
// ctx_body_form: parses multipart/form-data (same path as upload_parts)
// ctx_body_urlencoded: parses application/x-www-form-urlencoded from raw body
// ctx_body_text: convenience wrapper returning String instead of raw s

@ ctx_body_form Ctx c → ?( Vec MultipartPart ) {
    ^ ( request_multipart_parts . c req )
}

@ ctx_body_urlencoded Ctx c → ?( Vec UrlEncodedPair ) {
    : s raw ( ctx_body_raw c )
    : i rlen ( nurl_str_len raw )
    ? == rlen 0 {
        ^ @ ?( Vec UrlEncodedPair ) { F }
    } {}
    : Vec UrlEncodedPair pairs ( vec_new [UrlEncodedPair] )
    : ~ i pos 0
    ~ < pos rlen {
        : i amp ( nurl_has_byte raw + pos - rlen pos 38 )
        : i seg_end ? < amp rlen amp rlen
        // Extract key=value segment
        : i seg_start pos
        : i seg_len - seg_end seg_start
        ? > seg_len 0 {
            // Find '=' separator
            : i eq ( nurl_has_byte raw + seg_start seg_len 61 )
            : i key_end ? < eq + seg_start seg_start seg_len + seg_start seg_start
            : i key_len - key_end seg_start
            : i val_start ? < key_end seg_end + key_end 1 key_end
            : i val_len - seg_end val_start
            // Decode key and value
            : String key_slice ( nurl_str_slice raw seg_start key_len )
            : String decoded_key ( __url_decode ( string_data key_slice ) )
            ( string_free key_slice )
            : s dk_data ( string_data decoded_key )
            : String dk_copy ( string_data ( nurl_str_cat dk_data `` ) )
            ( string_free decoded_key )
            : String val_slice ? > val_len 0 ( nurl_str_slice raw val_start val_len ) ( string_data ( nurl_str_cat `` `` ) )
            : String decoded_val ( __url_decode ( string_data val_slice ) )
            ( string_free val_slice )
            : s dv_data ( string_data decoded_val )
            : String dv_copy ( string_data ( nurl_str_cat dv_data `` ) )
            ( string_free decoded_val )
            // Push pair
            : UrlEncodedPair pair @ UrlEncodedPair { dk_copy dv_copy }
            ( vec_push [UrlEncodedPair] pairs pair )
        } {}
        = pos + seg_end 1
    }
    ^ @ ?( Vec UrlEncodedPair ) { T pairs }
}

@ ctx_body_text Ctx c → String {
    : s raw ( ctx_body_raw c )
    : i rlen ( nurl_str_len raw )
    ? > rlen 0 {
        ^ ( string_data ( nurl_str_cat raw `` ) )
    } {
        ^ ( string_data ( nurl_str_cat `` `` ) )
    }
}


// ── Response helpers (delegate to respond.nu) ─────────────────────────
//
// All helpers take Ctx as first arg for uniform LLM-friendly API surface.
// Ctx is unused — passed through for API consistency only.
// Canonical implementations live in respond.nu.

@ ctx_text i status s body → HttpResponse {
    ^ ( respond_text status body )
}

@ ctx_json i status s body → HttpResponse {
    ^ ( respond_json status body )
}

@ ctx_html i status s body → HttpResponse {
    ^ ( respond_html status body )
}

// ── Status shortcuts ──────────────────────────────────────────────────

// Status shortcuts — kept to the essential 3. For other codes use ctx_text directly:
//   ( ctx_text ctx 201 body )  instead of  ctx_created
//   ( ctx_text ctx 401 msg  )  instead of  ctx_unauthorized
//   ( ctx_text ctx 409 msg  )  instead of  ctx_conflict
@ ctx_ok s body → HttpResponse       { ^ ( ctx_text 200 body ) }
@ ctx_not_found s msg → HttpResponse { ^ ( ctx_text 404 msg ) }
@ ctx_error s msg → HttpResponse     { ^ ( ctx_text 500 msg ) }

// ── Redirect ──────────────────────────────────────────────────────────

@ ctx_redirect i status s location → HttpResponse {
    ^ ( respond_redirect status location )
}
