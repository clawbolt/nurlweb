// examples/error_demo.nu — Structured error handling demo
//
// Shows error.nu in practice: handlers return error_* responses,
// app_catch middleware intercepts and renders clean JSON errors.
//
// Build & run (from nurl repo root):
//   ./nurl.sh nurlweb/examples/error_demo.nu
//
// Test:
//   curl http://127.0.0.1:3911/items/42
//   curl http://127.0.0.1:3911/items/0

$ `nurlweb/app.nu`
$ `nurlweb/ctx.nu`
$ `nurlweb/error.nu`

@ main → i {
    : App app ( app_new `127.0.0.1` 3911 )

    ( app_get app `/items/:id`
        \ HttpRequest req Params params → HttpResponse {
            : Ctx ctx ( ctx_new req params )
            : ?String id_opt ( ctx_param ctx `id` )
            ?? id_opt {
                T id → {
                    : i id_num ( nurl_str_to_int id )
                    ? == id_num 0 {
                        ^ ( error_not_found `item_missing` `Item not found` )
                    } {
                        ^ ( response_text 200 id )
                    }
                }
                F → {
                    ^ ( error_validation `bad_id` `Missing id param` )
                }
            }
        })

    // Register error catch middleware LAST (outermost)
    ( app_catch app
        \ HttpResponse orig AppError ae → HttpResponse {
            ^ ( error_render_json orig ae )
        })

    ( nurl_print `error demo on http://127.0.0.1:3911/\n` )
    ( nurl_print `  GET /items/42 → 200\n` )
    ( nurl_print `  GET /items/0  → 404 JSON error\n` )

    : !v NetErr rr ( app_serve app )
    ( app_free app )
    ?? rr {
        T _ → { ^ 0 }
        F _ → { ^ 1 }
    }
}
