// nurlweb/validate.nu — JSON Schema Validation
//
// Schema-driven JSON body validation: declare a schema struct, get a
// parsed result or structured error. Think Zod for NURL.
//
// API:
//   ( schema_new )                                       → Schema
//   ( schema_free Schema s )                             → v
//   ( schema_field Schema s s name s type i required )    → v
//   ( validate_json Ctx ctx Schema s )                   → !Json ValidateErr
//
// Constants:
//   REQUIRED = 1, OPTIONAL = 0
//   FIELD_TYPE_STRING, FIELD_TYPE_NUMBER, FIELD_TYPE_BOOL,
//   FIELD_TYPE_OBJECT, FIELD_TYPE_ARRAY
//
// Usage:
//   : Schema s ( schema_new )
//   ( schema_field s `name` FIELD_TYPE_STRING REQUIRED )
//   ( schema_field s `age`  FIELD_TYPE_NUMBER OPTIONAL )
//   : !Json ValidateErr vr ( validate_json ctx s )

$ `nurlweb/ctx.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/core/vec.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/errors.nu`

// ── Schema type constants ─────────────────────────────────────────────

@ FIELD_TYPE_STRING → s { ^ `string` }
@ FIELD_TYPE_NUMBER → s { ^ `number` }
@ FIELD_TYPE_BOOL   → s { ^ `bool`   }
@ FIELD_TYPE_OBJECT → s { ^ `object` }
@ FIELD_TYPE_ARRAY  → s { ^ `array`  }

@ REQUIRED → i { ^ 1 }
@ OPTIONAL → i { ^ 0 }

// ── Schema struct ─────────────────────────────────────────────────────

// Parallel Vecs to avoid Vec<SchemaField> (NURL struct-in-Vec is evolving).
// All three Vecs share the same index for a given field.
: Schema {
    ( Vec String ) field_names
    ( Vec String ) field_types
    ( Vec i )      field_required
}

@ schema_new → Schema {
    ^ @ Schema {
        ( vec_new [String] )
        ( vec_new [String] )
        ( vec_new [i] )
    }
}

@ schema_free Schema s → v {
    ( vec_free_with [String] . s field_names
        \ String name → v { ( string_free name ) } )
    ( vec_free_with [String] . s field_types
        \ String t → v { ( string_free t ) } )
    ( vec_free [i] . s field_required )
}

@ schema_field Schema s s name s field_type i required → v {
    ( vec_push [String] . s field_names name )
    ( vec_push [String] . s field_types field_type )
    ( vec_push [i] . s field_required required )
}

// ── ValidateErr ───────────────────────────────────────────────────────

: ValidateErr {
    s field       // field name (empty for body-level errors)
    s code        // "missing_required", "type_mismatch", "not_object", "parse_error"
    s expected    // expected type or "valid json"
    s got         // actual type or error message
}

// ── validate_json ─────────────────────────────────────────────────────

// Parses the request body as JSON and validates each field against the
// schema. Returns the parsed Json on success, or a structured ValidateErr.
@ validate_json Ctx ctx Schema schema → !Json ValidateErr {
    : !Json ParseErr jr ( ctx_body_json ctx )
    ?? jr {
        T j → {
            // Body must be a JSON object
            ? ! ( json_is_obj j ) {
                : s actual_type ( json_type_name j )
                ^ @ !Json ValidateErr {
                    F @ ValidateErr { `` `not_object` `object` actual_type }
                }
            } {}

            // Iterate schema fields
            : i n ( vec_len [String] . schema field_names )
            : ~ i k 0
            ~ < k n {
                : ?String fn_opt ( vec_get [String] . schema field_names k )
                ?? fn_opt {
                    T field_name → {
                        : ?String ft_opt ( vec_get [String] . schema field_types k )
                        : ?i req_opt ( vec_get [i] . schema field_required k )
                        ?? ft_opt {
                            T field_type → {
                                : i required_val 0
                                ?? req_opt {
                                    T rv → { = required_val rv }
                                    F → {}
                                }

                                : s fn_raw ( string_data field_name )
                                : b has_field ( json_obj_has j fn_raw )

                                ? == has_field 0 {
                                    ? == required_val 1 {
                                        ^ @ !Json ValidateErr {
                                            F @ ValidateErr { fn_raw `missing_required` field_type `` }
                                        }
                                    } {}
                                } {
                                    // Field present — validate type
                                    : ?Json fv_opt ( json_obj_get j fn_raw )
                                    ?? fv_opt {
                                        T fv → {
                                            : b type_ok F
                                            ? != 0 ( nurl_str_eq field_type `string` )
                                                { = type_ok ( json_is_str fv ) } {}
                                            ? != 0 ( nurl_str_eq field_type `number` )
                                                { = type_ok ( json_is_num fv ) } {}
                                            ? != 0 ( nurl_str_eq field_type `bool` )
                                                { = type_ok ( json_is_bool fv ) } {}
                                            ? != 0 ( nurl_str_eq field_type `object` )
                                                { = type_ok ( json_is_obj fv ) } {}
                                            ? != 0 ( nurl_str_eq field_type `array` )
                                                { = type_ok ( json_is_arr fv ) } {}

                                            ? ! type_ok {
                                                : s got_type ( json_type_name fv )
                                                ^ @ !Json ValidateErr {
                                                    F @ ValidateErr { fn_raw `type_mismatch` field_type got_type }
                                                }
                                            } {}
                                        }
                                        F → {}
                                    }
                                }
                            }
                            F → {}
                        }
                    }
                    F → {}
                }
                = k + k 1
            }

            ^ @ !Json ValidateErr { T j }
        }
        F e → {
            : s err_msg ( parse_err_msg e )
            ^ @ !Json ValidateErr {
                F @ ValidateErr { `` `parse_error` `valid json` err_msg }
            }
        }
    }
}
