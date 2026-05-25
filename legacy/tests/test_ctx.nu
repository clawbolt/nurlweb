// nurlweb/test_ctx.nu — Compile-time unit tests for ctx.nu
//
// Verifies that Ctx types and extraction/response helpers compile.
// Run: ./build/nurlc nurlweb/test_ctx.nu
// Expected: exit 0

$ `nurlweb/app.nu`
$ `nurlweb/ctx.nu`
$ `stdlib/ext/http_full.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/option.nu`

// ── Test: ctx_new creates Ctx ─────────────────────────────────────────

@ test_ctx_new HttpRequest req Params params → Ctx {
    ^ ( ctx_new req params )
}

// ── Test: ctx_param extraction ────────────────────────────────────────

@ test_ctx_param Ctx ctx → ?String {
    ^ ( ctx_param ctx `id` )
}

// ── Test: ctx_body_raw ────────────────────────────────────────────────

// ── Test: ctx_param_i integer extraction ──────────────────────────

@ test_ctx_param_i Ctx ctx → ?i {
    ^ ( ctx_param_i ctx `id` )
}

@ test_ctx_body_raw Ctx ctx → s {
    ^ ( ctx_body_raw ctx )
}

// ── Test: ctx_body_json ───────────────────────────────────────────────

@ test_ctx_body_json Ctx ctx → !Json ParseErr {
    ^ ( ctx_body_json ctx )
}

// ── Test: response helpers ────────────────────────────────────────────

@ test_ctx_ok Ctx ctx → HttpResponse     { ^ ( ctx_ok `hello\n` ) }
@ test_ctx_created Ctx ctx → HttpResponse { ^ ( ctx_text 201 `created\n` ) }
@ test_ctx_no_content Ctx ctx → HttpResponse { ^ ( ctx_text 204 `` ) }
@ test_ctx_bad_request Ctx ctx → HttpResponse { ^ ( ctx_text 400 `bad\n` ) }
@ test_ctx_not_found Ctx ctx → HttpResponse { ^ ( ctx_not_found `gone\n` ) }
@ test_ctx_error Ctx ctx → HttpResponse { ^ ( ctx_error `oops\n` ) }
@ test_ctx_json Ctx ctx → HttpResponse { ^ ( ctx_json 200 `{"x":1}\n` ) }
@ test_ctx_html Ctx ctx → HttpResponse { ^ ( ctx_html 200 `<h1>hi</h1>\n` ) }
@ test_ctx_redirect Ctx ctx → HttpResponse { ^ ( ctx_redirect 302 `/login` ) }

// ── Test: full handler with Ctx ───────────────────────────────────────

@ test_full_handler HttpRequest req Params params → HttpResponse {
    : Ctx ctx ( ctx_new req params )
    : ?String name ( ctx_param ctx `name` )
    ?? name {
        T n → {
            ^ ( ctx_json 200 n )
        }
        F → { ^ ( ctx_not_found `missing name\n` ) }
    }
}

// ── Test: full handler with JSON body ─────────────────────────────────

@ test_json_handler HttpRequest req Params params → HttpResponse {
    : Ctx ctx ( ctx_new req params )
    : !Json ParseErr jr ( ctx_body_json ctx )
    ?? jr {
        T _ → { ^ ( ctx_ok `json ok\n` ) }
        F _ → { ^ ( ctx_text 400 `bad json\n` ) }
    }
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
