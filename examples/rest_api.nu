// examples/rest_api.nu — Full REST API demo (nurlweb v0.4 slim core)
//
// Demonstrates: app_new, app_get/post/put/delete, respond_*,
//   params_get, json_parse, json_obj_get, json_str_data
//
// Build & run (from nurl repo root):
//   ./nurlc nurlweb/examples/rest_api.nu > /tmp/rest.ll
//   clang -O2 /tmp/rest.ll stdlib/runtime.o -lm -lpthread \
//     -lcurl -lssl -lcrypto -lsqlite3 -lz \
//     -L/opt/homebrew/opt/openssl@3/lib -o /tmp/rest
//   /tmp/rest
//
// Test:
//   curl http://127.0.0.1:3920/items
//   curl -X POST http://127.0.0.1:3920/items -d '{"name":"foo"}'
//   curl -X PUT http://127.0.0.1:3920/items/0 -d '{"name":"bar"}'
//   curl -X DELETE http://127.0.0.1:3920/items/0

$ `nurlweb/app.nu`
$ `stdlib/ext/http_full.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/core/vec.nu`
$ `stdlib/core/string.nu`

// ── In-memory item store ─────────────────────────────────────────────

: Item {
    i id
    String name
}

@ item_new i id s name → Item {
    : String nm ( string_new )
    ( string_push_str nm name )
    ^ @ Item { id nm }
}

@ item_free Item it → v {
    ( string_free . it name )
}

// ── Helpers ──────────────────────────────────────────────────────────

// Parse body bytes → JSON. Returns !Json ParseErr.
@ parse_body_json HttpRequest req → !Json ParseErr {
    : i n ( vec_len [u] . req body )
    ? > n 0 {
        : *u data ( vec_data [u] . req body )
        : String bs ( string_from_bytes data n )
        : s raw ( string_data bs )
        : !Json ParseErr jr ( json_parse raw )
        ( string_free bs )
        ^ jr
    } { ^ @ !Json ParseErr { F @ ParseErr { Empty } } }
}

// Convert string to int (returns -1 on failure for simplicity).
@ str_to_int_or s raw i fallback → i {
    : i v ( nurl_str_to_int raw )
    ? != v 0 { ^ v } {
        ? == ( nurl_str_get raw 0 ) 48 { ^ 0 } { ^ fallback }
    }
}

// ── Route handlers ───────────────────────────────────────────────────

@ handle_list_items ( Vec Item ) items HttpRequest req Params params → HttpResponse {
    : String out ( string_with_cap 256 )
    ( string_push_str out `[\n` )
    : i n ( vec_len [Item] items )
    : ~ i k 0
    ~ < k n {
        : ?Item it_opt ( vec_get [Item] items k )
        ?? it_opt {
            T it → {
                ( string_push_str out `  {"id":` )
                ( string_push_int out . it id )
                ( string_push_str out `,"name":"` )
                ( string_push_str out ( string_data . it name ) )
                ( string_push_str out `"}` )
                ? < + k 1 n { ( string_push_str out `,\n` ) } { ( string_push_str out `\n` ) }
            }
            F → {}
        }
        = k + k 1
    }
    ( string_push_str out `]\n` )
    : HttpResponse r ( response_text 200 ( string_data out ) )
    ( string_free out )
    ^ r
}

@ handle_get_item ( Vec Item ) items HttpRequest req Params params → HttpResponse {
    : ?String id_opt ( params_get params `id` )
    ?? id_opt {
        T sid → {
            : i id ( str_to_int_or ( string_data sid ) -1 )
            ? < id 0 { ^ ( response_text 400 `invalid id\n` ) } {}
            : i n ( vec_len [Item] items )
            : ~ i k 0
            ~ < k n {
                : ?Item it_opt ( vec_get [Item] items k )
                ?? it_opt {
                    T it → {
                        ? == . it id id {
                            : String out ( string_with_cap 128 )
                            ( string_push_str out `{"id":` )
                            ( string_push_int out . it id )
                            ( string_push_str out `,"name":"` )
                            ( string_push_str out ( string_data . it name ) )
                            ( string_push_str out `"}\n` )
                            : HttpResponse r ( response_text 200 ( string_data out )  )
                            ( response_set_header r `Content-Type` `application/json` )
                            ( string_free out )
                            ^ r
                        } {}
                    }
                    F → {}
                }
                = k + k 1
            }
            ^ ( response_text 404 `item not found\n` )
        }
        F → { ^ ( response_text 400 `missing id\n` ) }
    }
}

@ handle_create_item ( Vec Item ) items HttpRequest req Params params → HttpResponse {
    : !Json ParseErr jr ( parse_body_json req )
    ?? jr {
        T j → {
            : ?Json name_opt ( json_obj_get j `name` )
            ?? name_opt {
                T name_json → {
                    ? ! ( json_is_str name_json ) {
                        ^ ( response_text 400 `name must be a string\n` )
                    } {}
                    : s name_str ( json_str_data name_json )
                    : i n ( vec_len [Item] items )
                    : Item it ( item_new n name_str )
                    ( vec_push [Item] items it )
                    : String out ( string_with_cap 128 )
                    ( string_push_str out `{"id":` )
                    ( string_push_int out n )
                    ( string_push_str out `,"name":"` )
                    ( string_push_str out name_str )
                    ( string_push_str out `"}\n` )
                    : HttpResponse r ( response_text 201 ( string_data out )  )
                            ( response_set_header r `Content-Type` `application/json` )
                    ( string_free out )
                    ^ r
                }
                F → { ^ ( response_text 400 `missing name field\n` ) }
            }
        }
        F _ → { ^ ( response_text 400 `invalid json body\n` ) }
    }
}

@ handle_update_item ( Vec Item ) items HttpRequest req Params params → HttpResponse {
    : ?String id_opt ( params_get params `id` )
    ?? id_opt {
        T sid → {
            : i id ( str_to_int_or ( string_data sid ) -1 )
            ? < id 0 { ^ ( response_text 400 `invalid id\n` ) } {}
            : i n ( vec_len [Item] items )
            : ~ i k 0
            ~ < k n {
                : ?Item it_opt ( vec_get [Item] items k )
                ?? it_opt {
                    T it → {
                        ? == . it id id {
                            : !Json ParseErr jr ( parse_body_json req )
                            ?? jr {
                                T j → {
                                    : ?Json name_opt ( json_obj_get j `name` )
                                    ?? name_opt {
                                        T name_json → {
                                            ? ! ( json_is_str name_json ) {
                                                ^ ( response_text 400 `name must be a string\n` )
                                            } {}
                                            : s name_str ( json_str_data name_json )
                                            ( string_free . it name )
                                            : String nm ( string_new )
                                            ( string_push_str nm name_str )
                                            = . it name nm
                                            ^ ( response_text 200 `updated\n` )
                                        }
                                        F → { ^ ( response_text 400 `missing name field\n` ) }
                                    }
                                }
                                F _ → { ^ ( response_text 400 `invalid json body\n` ) }
                            }
                        } {}
                    }
                    F → {}
                }
                = k + k 1
            }
            ^ ( response_text 404 `item not found\n` )
        }
        F → { ^ ( response_text 400 `missing id\n` ) }
    }
}

@ handle_delete_item ( Vec Item ) items HttpRequest req Params params → HttpResponse {
    : ?String id_opt ( params_get params `id` )
    ?? id_opt {
        T sid → {
            : i id ( str_to_int_or ( string_data sid ) -1 )
            ? < id 0 { ^ ( response_text 400 `invalid id\n` ) } {}
            : i n ( vec_len [Item] items )
            : ~ i k 0
            ~ < k n {
                : ?Item it_opt ( vec_get [Item] items k )
                ?? it_opt {
                    T it → {
                        ? == . it id id {
                            ( string_free . it name )
                            : String nm ( string_new )
                            ( string_push_str nm `DELETED` )
                            = . it name nm
                            ^ ( response_text 204 `` )
                        } {}
                    }
                    F → {}
                }
                = k + k 1
            }
            ^ ( response_text 404 `item not found\n` )
        }
        F → { ^ ( response_text 400 `missing id\n` ) }
    }
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i {
    : App app ( app_new `127.0.0.1` 3920 )

    : ( Vec Item ) items ( vec_new [Item] )

    ( app_get app `/items`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( handle_list_items items req params )
        })

    ( app_get app `/items/:id`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( handle_get_item items req params )
        })

    ( app_post app `/items`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( handle_create_item items req params )
        })

    ( app_put app `/items/:id`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( handle_update_item items req params )
        })

    ( app_delete app `/items/:id`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( handle_delete_item items req params )
        })

    ( nurl_print `nurlweb REST API on http://127.0.0.1:3920/items\n` )

    : !v NetErr rr ( app_serve app )
    // cleanup
    : i n ( vec_len [Item] items )
    : ~ i k 0
    ~ < k n {
        : ?Item it_opt ( vec_get [Item] items k )
        ?? it_opt {
            T it → { ( item_free it ) }
            F → {}
        }
        = k + k 1
    }
    ( vec_free [Item] items )
    ( app_free app )

    ?? rr {
        T _ → { ^ 0 }
        F _ → { ^ 1 }
    }
}
