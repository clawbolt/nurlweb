// examples/validate_demo.nu — Schema validation demo
//
// Shows validate.nu in a real route handler: define a schema, validate
// the incoming JSON body, return 200 or 422 with structured error.
//
// Build & run (from nurl repo root):
//   ./nurl.sh nurlweb/examples/validate_demo.nu
//
// Test:
//   curl -X POST http://127.0.0.1:3910/users \
//     -H 'Content-Type: application/json' \
//     -d '{"name":"alice","age":30}'
//   curl -X POST http://127.0.0.1:3910/users \
//     -H 'Content-Type: application/json' \
//     -d '{"name":"bob"}'

$ `nurlweb/app.nu`
$ `nurlweb/ctx.nu`
$ `nurlweb/validate.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/core/string.nu`

@ main → i {
    : App app ( app_new `127.0.0.1` 3910 )

    : Schema user_schema ( schema_new )
    ( schema_field user_schema `name` FIELD_TYPE_STRING REQUIRED )
    ( schema_field user_schema `age`  FIELD_TYPE_NUMBER REQUIRED )

    ( app_post app `/users`
        \ HttpRequest req Params params → HttpResponse {
            : Ctx ctx ( ctx_new req params )
            : !Json ValidateErr vr ( validate_json ctx user_schema )
            ?? vr {
                T j → {
                    : s json_str ( json_stringify j )
                    ^ ( ctx_json ctx 200 json_str )
                }
                F e → {
                    // Build structured error as JSON body
                    : s err_body ( nurl_str_cat3
                        `{"error":"` . e code `","field":"` )
                    : s err_body2 ( nurl_str_cat err_body . e field )
                    : s err_body3 ( nurl_str_cat err_body2 `"}\n` )
                    ^ ( ctx_json ctx 422 err_body3 )
                }
            }
        })

    ( nurl_print `validate demo on http://127.0.0.1:3910/\n` )
    ( nurl_print `  POST /users  {"name":"alice","age":30}\n` )

    : !v NetErr rr ( app_serve app )
    ( schema_free user_schema )
    ( app_free app )
    ?? rr {
        T _ → { ^ 0 }
        F _ → { ^ 1 }
    }
}
