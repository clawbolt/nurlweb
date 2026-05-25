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
// WARNING: template_render does NOT escape HTML entities. Use
// template_render_html for HTML contexts with untrusted input.
// This module is safe for plain-text interpolation; HTML needs the html variant.
//
// API:
//   ( template_render        s template ( Vec TemplateVar ) vars )  → String
//   ( template_render_html    s template ( Vec TemplateVar ) vars )  → String
//   ( template_render_layout  s layout  s content  ( Vec TemplateVar ) vars ) → String
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

// ── __html_escape — escape HTML entities ─────────────────────────────

@ __html_escape s input → String {
    : i ilen ( nurl_str_len input )
    : String out ( string_with_cap ilen )
    : ~ i pos 0
    ~ < pos ilen {
        : i c ( nurl_str_get input pos )
        ?? c {
            38  → { ( string_push_str out `&amp;` )  }
            60  → { ( string_push_str out `&lt;` )   }
            62  → { ( string_push_str out `&gt;` )   }
            34  → { ( string_push_str out `&quot;` ) }
            39  → { ( string_push_str out `&#39;` )  }
            _   → { ( string_push_char out c ) }
        }
        = pos + pos 1
    }
    ^ out
}

// ── template_render_html — HTML-safe template rendering ──────────────
//
// Identical to template_render but HTML-escapes all substituted values.
// Use for HTML templates with untrusted user input.
// Escape set: < → &lt;, > → &gt;, & → &amp;, " → &quot;, ' → &#39;

@ template_render_html s template ( Vec TemplateVar ) vars → String {
    : i tlen ( nurl_str_len template )

    : String expanded ( string_with_cap + tlen 256 )
    ( __resolve_includes expanded template tlen 0 )

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
                                        ? != ( nurl_str_get expanded_data + pos 2 m ) ( nurl_str_get tvkey m ) {
                                            = match F
                                        } {}
                                        = m + m 1
                                    }
                                } { = match F }
                                ? match {
                                    : String escaped ( __html_escape ( string_data . tv value ) )
                                    ( string_push_str out ( string_data escaped ) )
                                    ( string_free escaped )
                                    = found T
                                } {}
                            }
                            F → {}
                        }
                        = vi + vi 1
                    }
                    ? ! found {
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

// ═══════════════════════════════════════════════════════════════════════
// v2 block directives — merged from template_v2.nu
// ═══════════════════════════════════════════════════════════════════════
//
// Pre-processes {{#if key}}body{{/if}} and {{#unless key}}body{{/unless}}
// blocks before {{key}} substitution.
//
// API:
//   ( template_if  s tpl ( Vec TemplateVar ) vars ) → String  — expand blocks
//   ( template_v2  s tpl ( Vec TemplateVar ) vars ) → String  — blocks + render

// ── __find_close — find matching {{/X}} given literal close marker ───

@ __find_close s tpl i start i end s marker i mlen → i {
    : ~ i pos start
    : ~ i result -1
    ~ & < pos end == result -1 {
        : i c0 ( nurl_str_get tpl pos )
        ? == c0 123 {
            : b all_match T
            : ~ i mi 0
            ~ & all_match < mi mlen {
                : i tc ( nurl_str_get tpl + pos mi )
                : i mc ( nurl_str_get marker mi )
                ? != tc mc { = all_match F } {}
                = mi + mi 1
            }
            ? all_match { = result pos } {}
        } {}
        = pos + pos 1
    }
    ^ result
}

// ── template_if — expand {{#if key}}...{{/if}} and {{#unless key}}...{{/unless}} ─

@ template_if s tpl ( Vec TemplateVar ) vars → String {
    : i tlen ( nurl_str_len tpl )
    : String out ( string_with_cap + tlen 256 )
    : ~ i pos 0

    ~ < pos tlen {
        : i c1 ( nurl_str_get tpl pos )
        : b enuf ? >= + pos 5 tlen T F

        ? & enuf == c1 123 {
            : i c2 ( nurl_str_get tpl + pos 1 )
            : i c3 ( nurl_str_get tpl + pos 2 )
            ? & == c2 123 == c3 35 {
                // {{#... — could be #if or #unless
                : i c4 ( nurl_str_get tpl + pos 3 )
                : i c5 ( nurl_str_get tpl + pos 4 )

                ? & == c4 105 == c5 102 {
                    // {{#if — read key name
                    : i c6 ( nurl_str_get tpl + pos 5 )
                    ? == c6 32 {
                        // {{#if KEY}}
                        : i key_start + pos 6
                        : i key_end -1
                        : ~ i ks key_start
                        ~ & < ks tlen == key_end -1 {
                            : i kc ( nurl_str_get tpl ks )
                            ? == kc 125 { = key_end - ks 1 } {}
                            = ks + ks 1
                        }
                        ? >= key_end key_start {
                            : i klen - key_end key_start
                            : i after_tag + key_end 2  // skip KEY}}
                            // Find {{/if}}
                            : s close_marker `{{/if}}`
                            : i cmatch ( __find_close tpl after_tag tlen close_marker 7 )
                            ? >= cmatch after_tag {
                                : i body_start after_tag
                                : i body_len - cmatch body_start
                                : i after_close + cmatch 7

                                // Check if key has a value
                                : s key ( nurl_str_slice tpl key_start klen )
                                : b has_val F
                                : i vn ( vec_len [TemplateVar] vars )
                                : ~ i vi 0
                                ~ & ! has_val < vi vn {
                                    : ?TemplateVar tv ( vec_get [TemplateVar] vars vi )
                                    ?? tv {
                                        T v → {
                                            : s vk ( string_data . v key )
                                            : i match ( nurl_str_eq vk key )
                                            ? != match 0 { = has_val T } {}
                                        }
                                        F → {}
                                    }
                                    = vi + vi 1
                                }

                                ? has_val {
                                    // Emit body
                                    : ~ i bp body_start
                                    ~ < bp + body_start body_len {
                                        ( string_push_char out ( nurl_str_get tpl bp ) )
                                        = bp + bp 1
                                    }
                                } {}

                                = pos after_close
                            } { = pos + pos 1 }
                        } { = pos + pos 1 }
                    } { = pos + pos 1 }
                } {
                    // Check for #unless
                    : b ul_enuf ? >= + pos 9 tlen T F
                    ? ul_enuf {
                        : i c6 ( nurl_str_get tpl + pos 5 )
                        : i c7 ( nurl_str_get tpl + pos 6 )
                        : i c8 ( nurl_str_get tpl + pos 7 )
                        : i c9 ( nurl_str_get tpl + pos 8 )
                        ? & & & == c6 110 == c7 108 == c8 101 == c9 115 {
                            : i c10 ( nurl_str_get tpl + pos 9 )
                            ? == c10 115 {
                                // {{#unless — read key
                                : i c11 ( nurl_str_get tpl + pos 10 )
                                ? == c11 32 {
                                    : i key_start + pos 11
                                    : ~ i ks key_start
                                    : i key_end -1
                                    ~ & < ks tlen == key_end -1 {
                                        : i kc ( nurl_str_get tpl ks )
                                        ? == kc 125 { = key_end - ks 1 } {}
                                        = ks + ks 1
                                    }
                                    ? >= key_end key_start {
                                        : i klen - key_end key_start
                                        : i after_tag + key_end 2
                                        : s close_unless `{{/unless}}`
                                        : i cm ( __find_close tpl after_tag tlen close_unless 11 )
                                        ? >= cm after_tag {
                                            : i body_start after_tag
                                            : i body_len - cm body_start
                                            : i after_close + cm 11
                                            : s key ( nurl_str_slice tpl key_start klen )
                                            : b has_val F
                                            : i vn ( vec_len [TemplateVar] vars )
                                            : ~ i vi 0
                                            ~ & ! has_val < vi vn {
                                                : ?TemplateVar tv ( vec_get [TemplateVar] vars vi )
                                                ?? tv {
                                                    T v → {
                                                        : s vk ( string_data . v key )
                                                        ? != 0 ( nurl_str_eq vk key ) { = has_val T } {}
                                                    }
                                                    F → {}
                                                }
                                                = vi + vi 1
                                            }
                                            ? ! has_val {
                                                : ~ i bp body_start
                                                ~ < bp + body_start body_len {
                                                    ( string_push_char out ( nurl_str_get tpl bp ) )
                                                    = bp + bp 1
                                                }
                                            } {}
                                            = pos after_close
                                        } { = pos + pos 1 }
                                    } { = pos + pos 1 }
                                } { = pos + pos 1 }
                            } { = pos + pos 1 }
                        } { = pos + pos 1 }
                    } { = pos + pos 1 }
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

// ── template_v2 — full pipeline: if-expand then key-substitute ────────

@ template_v2 s tpl ( Vec TemplateVar ) vars → String {
    : String expanded ( template_if tpl vars )
    : s exp_data ( string_data expanded )
    : String result ( template_render exp_data vars )
    ( string_free expanded )
    ^ result
}
