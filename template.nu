// nurlweb/template.nu — Minimal {{key}} string template rendering
//
// Substitutes `{{key}}` placeholders with values from a Vec<TemplateVar>.
// Uses Vec<TemplateVar> (not Map) because NURL Map stores i64 only.
// Linear scan for key lookup — production templates typically have < 20 vars.
//
// API:
//   ( template_render s template ( Vec TemplateVar ) vars )  → String
//   ( template_file   s path    ( Vec TemplateVar ) vars )  → !String IoErr

$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `stdlib/std/fs.nu`

// ── TemplateVar — key/value pair for template interpolation ──────────

: TemplateVar {
    String key
    String value
}

@ template_var_free TemplateVar tv → v {
    ( string_free . tv key )
    ( string_free . tv value )
}

// ── __try_push_var — push value if key matches, return T if matched ──

@ __try_push_var ( Vec TemplateVar ) vars i key_start s template i key_len String out → b {
    : i vn ( vec_len [TemplateVar] vars )
    : ~ i vi 0
    : ~ b found F
    ~ & ! found < vi vn {
        : ?TemplateVar tv_opt ( vec_get [TemplateVar] vars vi )
        ?? tv_opt {
            T tv → {
                : s tvkey ( string_data . tv key )
                : i tvklen ( nurl_str_len tvkey )
                : b same_len == tvklen key_len
                : ~ b match T
                ? same_len {
                    : ~ i m 0
                    ~ & match < m key_len {
                        : i ta ( nurl_str_get template + key_start m )
                        : i tb ( nurl_str_get tvkey m )
                        ? != ta tb { = match F } {}
                        = m + m 1
                    }
                } {
                    = match F
                }
                ? match {
                    ( string_push_str out ( string_data . tv value ) )
                    = found T
                } {}
            }
            F → {}
        }
        = vi + vi 1
    }
    ^ found
}

// ── template_render — substitute {{key}} placeholders ────────────────

@ template_render s template ( Vec TemplateVar ) vars → String {
    : i tlen ( nurl_str_len template )
    : String out ( string_with_cap + tlen 256 )
    : ~ i pos 0

    ~ < pos tlen {
        : i c1 ( nurl_str_get template pos )
        : b left_brace == c1 123
        : b has_next < + pos 1 tlen
        ? & left_brace has_next {
            : i c2 ( nurl_str_get template + pos 1 )
            ? == c2 123 {
                // Found "{{" — scan for "}}"
                : ~ i key_start + pos 2
                : ~ i key_end -1
                : ~ i scan key_start
                ~ & < scan tlen == key_end -1 {
                    : i ca ( nurl_str_get template scan )
                    : i cb ? < + scan 1 tlen ( nurl_str_get template + scan 1 ) 0
                    : b is_close & == ca 125 == cb 125
                    ? is_close {
                        = key_end scan
                    } {
                        = scan + scan 1
                    }
                }

                : b found_close >= key_end key_start
                ? found_close {
                    : i key_len - key_end key_start
                    : b found ( __try_push_var vars key_start template key_len out )
                    ? ! found {
                        : ~ i kk - key_start 2
                        ~ < kk + key_end 2 {
                            ( string_push_char out ( nurl_str_get template kk ) )
                            = kk + kk 1
                        }
                    } {}

                    = pos + key_end 2
                } {
                    ( string_push_char out 123 )
                    ( string_push_char out 123 )
                    = pos + pos 2
                }
            } {
                ( string_push_char out c1 )
                = pos + pos 1
            }
        } {
            ( string_push_char out c1 )
            = pos + pos 1
        }
    }

    ^ out
}

// ── template_file — read file then render ────────────────────────────

@ template_file s path ( Vec TemplateVar ) vars → !String IoErr {
    : !String IoErr rr ( read_file path )
    ?? rr {
        T content → {
            : String rendered ( template_render ( string_data content ) vars )
            ( string_free content )
            ^ @ !String IoErr { T rendered }
        }
        F e → { ^ @ !String IoErr { F e } }
    }
}
