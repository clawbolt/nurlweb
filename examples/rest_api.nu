// examples/rest_api.nu — Full REST API demo (nurlweb v1.2+)
//
// Demonstrates: app_new, app_get, app_post, app_put, app_delete,
//   ctx_new, ctx_param, ctx_param_i, ctx_body_json, ctx_json,
//   ctx_not_found, ctx_bad_request, ctx_created, ctx_no_content
//
// Build & run (from nurl repo root):
//   ./build/nurlc examples/rest_api.nu && ./a.out
//
// Test (in another terminal):
//   curl http://127.0.0.1:3920/items
//   curl http://127.0.0.1:3920/items/1
//   curl -X POST http://127.0.0.1:3920/items -d '{"name":"foo"}'
//   curl -X PUT http://127.0.0.1:3920/items/1 -d '{"name":"bar"}'
//   curl -X DELETE http://127.0.0.1:3920/items/1

$ `nurlweb/ctx.nu`
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

// ── Route handlers ───────────────────────────────────────────────────

@ handle_list_items ( Vec Item ) items HttpRequest req Params params → HttpResponse {
    : Ctx ctx ( ctx_new req params )
    // Build a simple JSON array: [{"id":1,"name":"foo"},...]
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
    : HttpResponse r ( ctx_text ctx 200 ( string_data out ) )
    ( string_free out )
    ^ r
}

@ handle_get_item ( Vec Item ) items HttpRequest req Params params → HttpResponse {
    : Ctx ctx ( ctx_new req params )
    : ?i id_opt ( ctx_param_i ctx `id` )
    ?? id_opt {
        T id → {
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
                            : HttpResponse r ( ctx_json ctx 200 ( string_data out ) )
                            ( string_free out )
                            ^ r
                        } {}
                    }
                    F → {}
                }
                = k + k 1
            }
            ^ ( ctx_not_found ctx `item not found\n` )
        }
        F → { ^ ( ctx_bad_request ctx `invalid id\n` ) }
    }
}

@ handle_create_item ( Vec Item ) items HttpRequest req Params params → HttpResponse {
    : Ctx ctx ( ctx_new req params )
    : !Json ParseErr jr ( ctx_body_json ctx )
    ?? jr {
        T j → {
            : ?Json name_opt ( json_obj_get j `name` )
            ?? name_opt {
                T name_json → {
                    ? ! ( json_is_str name_json ) {
                        ^ ( ctx_bad_request ctx `name must be a string\n` )
                    } {}
                    : s name_str ( json_str_val name_json )
                    : i n ( vec_len [Item] items )
                    : Item it ( item_new n name_str )
                    ( vec_push [Item] items it )
                    : String out ( string_with_cap 128 )
                    ( string_push_str out `{"id":` )
                    ( string_push_int out n )
                    ( string_push_str out `,"name":"` )
                    ( string_push_str out name_str )
                    ( string_push_str out `"}\n` )
                    : HttpResponse r ( ctx_json ctx 201 ( string_data out ) )
                    ( string_free out )
                    ^ r
                }
                F → { ^ ( ctx_bad_request ctx `missing name field\n` ) }
            }
        }
        F _ → { ^ ( ctx_bad_request ctx `invalid json body\n` ) }
    }
}

@ handle_update_item ( Vec Item ) items HttpRequest req Params params → HttpResponse {
    : Ctx ctx ( ctx_new req params )
    : ?i id_opt ( ctx_param_i ctx `id` )
    ?? id_opt {
        T id → {
            : i n ( vec_len [Item] items )
            : ~ i k 0
            ~ < k n {
                : ?Item it_opt ( vec_get [Item] items k )
                ?? it_opt {
                    T it → {
                        ? == . it id id {
                            : !Json ParseErr jr ( ctx_body_json ctx )
                            ?? jr {
                                T j → {
                                    : ?Json name_opt ( json_obj_get j `name` )
                                    ?? name_opt {
                                        T name_json → {
                                            ? ! ( json_is_str name_json ) {
                                                ^ ( ctx_bad_request ctx `name must be a string\n` )
                                            } {}
                                            : s name_str ( json_str_val name_json )
                                            ( string_free . it name )
                                            : String nm ( string_new )
                                            ( string_push_str nm name_str )
                                            = . it name nm
                                            ^ ( ctx_ok ctx `updated\n` )
                                        }
                                        F → { ^ ( ctx_bad_request ctx `missing name field\n` ) }
                                    }
                                }
                                F _ → { ^ ( ctx_bad_request ctx `invalid json body\n` ) }
                            }
                        } {}
                    }
                    F → {}
                }
                = k + k 1
            }
            ^ ( ctx_not_found ctx `item not found\n` )
        }
        F → { ^ ( ctx_bad_request ctx `invalid id\n` ) }
    }
}

@ handle_delete_item ( Vec Item ) items HttpRequest req Params params → HttpResponse {
    : Ctx ctx ( ctx_new req params )
    : ?i id_opt ( ctx_param_i ctx `id` )
    ?? id_opt {
        T id → {
            : i n ( vec_len [Item] items )
            : ~ i k 0
            ~ < k n {
                : ?Item it_opt ( vec_get [Item] items k )
                ?? it_opt {
                    T it → {
                        ? == . it id id {
                            // items[k].name = "DELETED" — soft delete via name mutation
                            ( string_free . it name )
                            : String nm ( string_new )
                            ( string_push_str nm `DELETED` )
                            = . it name nm
                            ^ ( ctx_no_content ctx )
                        } {}
                    }
                    F → {}
                }
                = k + k 1
            }
            ^ ( ctx_not_found ctx `item not found\n` )
        }
        F → { ^ ( ctx_bad_request ctx `invalid id\n` ) }
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
