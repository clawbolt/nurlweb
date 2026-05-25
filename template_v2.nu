// nurlweb/template_v2.nu — Extended template engine with block constructs
//
// Pre-processes {{#if key}}body{{/if}} blocks before {{key}} substitution.
// Uses template.nu for the actual {{key}} rendering.
//
// API:
//   ( template_if s tpl ( Vec TemplateVar ) vars ) → String   — expand #if/#unless
//   ( template_v2 s tpl ( Vec TemplateVar ) vars ) → String    — if + render

$ `nurlweb/template.nu`

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
