// nurlweb/template.nu — {{key}} template rendering + Layout/Include
//
// Substitutes `{{key}}` placeholders with values from a Vec<TemplateVar>.
// Uses Vec<TemplateVar> (not Map) because NURL Map stores i64 only.
// Linear scan for key lookup — production templates typically have < 20 vars.
//
// Layout support: template_render_layout injects content into a layout
// template at the `{{% content %}}` marker, then renders vars.
//
// Include support: `{{> path/to/file }}` directives inline external
// template files before var substitution. Max include depth: 8.
//
// WARNING: template_render does NOT escape HTML entities. Do NOT use
// for HTML templates with untrusted user input — this will create XSS
// vulnerabilities. This module is for plain-text string interpolation only.
//
// API:
//   ( template_render        s template ( Vec TemplateVar ) vars )  → String
//   ( template_render_layout s layout  s content  ( Vec TemplateVar ) vars ) → String
//   ( template_file          s path    ( Vec TemplateVar ) vars )  → !String IoErr

$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `stdlib/std/fs.nu`

// ── Constants ────────────────────────────────────────────────────────

@ TEMPLATE_MAX_INCLUDE_DEPTH → i { ^ 8 }

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

// ── __scan_to_close — scan for `}}` starting at pos, returns end idx ──

@ __scan_to_close s template i start i tlen → i {
    : ~ i scan start
    : ~ i result -1
    ~ & < scan tlen == result -1 {
        : i ca ( nurl_str_get template scan )
        : i cb ? < + scan 1 tlen ( nurl_str_get template + scan 1 ) 0
        ? & == ca 125 == cb 125 {
            = result scan
        } {
            = scan + scan 1
        }
    }
    ^ result
}

// ── __resolve_includes — recursively inline {{> path }} directives ───

@ __resolve_includes String out s template i tlen i depth → v {
    ? > depth ( TEMPLATE_MAX_INCLUDE_DEPTH ) {
        ( string_push_str out template )
        ^ @ v {}
    } {}

    : ~ i pos 0
    ~ < pos tlen {
        : i c1 ( nurl_str_get template pos )
        : b has_next < + pos 1 tlen
        ? & == c1 123 has_next {
            : i c2 ( nurl_str_get template + pos 1 )
            ? == c2 123 {
                // "{{" — check for "{{>" (include) or "{{%" (layout marker)
                : i c3 ? < + pos 2 tlen ( nurl_str_get template + pos 2 ) 999
                ? == c3 62 {
                    // {{> — include directive
                    : i close_end ( __scan_to_close template + pos 3 tlen )
                    ? >= close_end + pos 3 {
                        : i path_start + pos 3
                        : i path_len - close_end path_start
                        : !String IoErr fr ( read_file ( nurl_str_slice template path_start path_len ) )
                        ?? fr {
                            T content → {
                                : s content_data ( string_data content )
                                : i content_len ( nurl_str_len content_data )
                                ( __resolve_includes out content_data content_len + depth 1 )
                                ( string_free content )
                            }
                            F _ → {
                                // File not found — emit the directive as-is
                                ( string_push_str out `{{> ` )
                                : ~ i p path_start
                                ~ < p close_end {
                                    ( string_push_char out ( nurl_str_get template p ) )
                                    = p + p 1
                                }
                                ( string_push_str out `}}` )
                            }
                        }
                    } {
                        ( string_push_char out 123 )
                        ( string_push_char out 123 )
                    }
                    = pos + close_end 2
                } {
                    // Regular {{key}} — pass through (resolved later by template_render)
                    : i close_end ( __scan_to_close template + pos 2 tlen )
                    ? >= close_end + pos 2 {
                        : ~ i p - pos 2
                        ~ < p + close_end 2 {
                            ( string_push_char out ( nurl_str_get template p ) )
                            = p + p 1
                        }
                        = pos + close_end 2
                    } {
                        ( string_push_char out 123 )
                        ( string_push_char out 123 )
                        = pos + pos 2
                    }
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
}

// ── template_render — substitute {{key}} placeholders ────────────────
//
// Also resolves {{> path }} include directives before var substitution.

@ template_render s template ( Vec TemplateVar ) vars → String {
    : i tlen ( nurl_str_len template )

    // Phase 1: resolve includes
    : String expanded ( string_with_cap + tlen 256 )
    ( __resolve_includes expanded template tlen 0 )

    // Phase 2: substitute {{key}} vars on the expanded template
    : s expanded_data ( string_data expanded )
    : i elen ( nurl_str_len expanded_data )
    : String out ( string_with_cap + elen 256 )
    : ~ i pos 0

    ~ < pos elen {
        : i c1 ( nurl_str_get expanded_data pos )
        : b left_brace == c1 123
        : b has_next < + pos 1 elen
        ? & left_brace has_next {
            : i c2 ( nurl_str_get expanded_data + pos 1 )
            ? == c2 123 {
                : i close_end ( __scan_to_close expanded_data + pos 2 elen )
                : b found_close >= close_end + pos 2
                ? found_close {
                    : i key_len - close_end + pos 2
                    : b found ( __try_push_var vars + pos 2 expanded_data key_len out )
                    ? ! found {
                        // Emit raw {{key}} for unmatched vars
                        : ~ i kk - pos 2
                        ~ < kk + close_end 2 {
                            ( string_push_char out ( nurl_str_get expanded_data kk ) )
                            = kk + kk 1
                        }
                    } {}
                    = pos + close_end 2
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

    ( string_free expanded )
    ^ out
}

// ── template_render_layout — render content into a layout ────────────
//
// Replaces {{% content %}} in the layout with the given content string,
// then renders {{key}} vars on the result.
// {{% is differentiated from {{> (include) and {{key (var) by the % char.

@ template_render_layout s layout s content ( Vec TemplateVar ) vars → String {
    : i llen ( nurl_str_len layout )
    : i clen ? == content 0 0 ( nurl_str_len content )

    // Find {{% content %}} in layout
    : String pre ( string_with_cap + llen clen )
    : ~ i pos 0
    : ~ b found_marker F

    ~ & < pos llen ! found_marker {
        : i c1 ( nurl_str_get layout pos )
        : b has_4 < + pos 3 llen
        ? & == c1 123 has_4 {
            : i c2 ( nurl_str_get layout + pos 1 )
            : i c3 ( nurl_str_get layout + pos 2 )
            ? & == c2 123 == c3 37 {
                // Found {{% — scan for %}}
                : i close_end ( __scan_to_close layout + pos 3 llen )
                ? >= close_end + pos 3 {
                    : i marker_start + pos 3
                    : i marker_len - close_end marker_start
                    : s marker_slice ( nurl_str_slice layout marker_start marker_len )
                    ? != 0 ( nurl_str_eq marker_slice `content ` ) {
                        = found_marker T
                        // Push content, skip past %}}
                        ( string_push_str pre content )
                        = pos + close_end 2
                    } {
                        // Not content marker — emit raw
                        : ~ i p - pos 2
                        ~ < p + close_end 2 {
                            ( string_push_char pre ( nurl_str_get layout p ) )
                            = p + p 1
                        }
                        = pos + close_end 2
                    }
                } {
                    ( string_push_char pre c1 )
                    = pos + pos 1
                }
            } {
                ( string_push_char pre c1 )
                = pos + pos 1
            }
        } {
            ( string_push_char pre c1 )
            = pos + pos 1
        }
    }

    // Append remaining layout after marker
    ~ < pos llen {
        ( string_push_char pre ( nurl_str_get layout pos ) )
        = pos + pos 1
    }

    // If no marker found, prepend content before layout
    : s pre_data ( string_data pre )
    : i pre_len ( nurl_str_len pre_data )
    : String final_out ( string_with_cap + pre_len 256 )
    ? ! found_marker {
        ( string_push_str final_out content )
    } {}

    ( string_push_str final_out pre_data )
    ( string_free pre )

    // Now render {{key}} vars on the combined result
    : s final_data ( string_data final_out )
    : String rendered ( template_render final_data vars )
    ( string_free final_out )
    ^ rendered
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
