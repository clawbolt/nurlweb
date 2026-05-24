// nurlweb/test_template.nu — Compile-time unit tests for template.nu
//
// Verifies that template types and functions compile correctly.
// Run: ./build/nurlc nurlweb/test_template.nu
// Expected: exit 0

$ `nurlweb/template.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`

// ── Test: TemplateVar construction ───────────────────────────────────

@ test_template_var → TemplateVar {
    : String k ( string_new )
    ( string_push_str k `name` )
    : String v ( string_new )
    ( string_push_str v `Alice` )
    ^ @ TemplateVar { k v }
}

// ── Test: template_render compiles ───────────────────────────────────

@ test_template_render → String {
    : ( Vec TemplateVar ) vars ( vec_new [TemplateVar] )
    : TemplateVar tv ( test_template_var )
    ( vec_push [TemplateVar] vars tv )
    : String out ( template_render `Hello {{name}}!` vars )
    ( vec_free [TemplateVar] vars )
    ^ out
}

// ── Test: no vars — literal output ───────────────────────────────────

@ test_template_no_vars → String {
    : ( Vec TemplateVar ) vars ( vec_new [TemplateVar] )
    : String out ( template_render `Hello World!` vars )
    ( vec_free [TemplateVar] vars )
    ^ out
}

// ── Test: single brace edge case (F2) — {{ without }} ────────────────

@ test_template_single_brace → String {
    : ( Vec TemplateVar ) vars ( vec_new [TemplateVar] )
    : String out ( template_render `{{` vars )
    ( vec_free [TemplateVar] vars )
    ^ out
}

// ── Test: template_render_layout compiles ─────────────────────────────

@ test_template_layout → String {
    : ( Vec TemplateVar ) vars ( vec_new [TemplateVar] )
    : TemplateVar tv @ TemplateVar {
        ( string_new ) ( string_new )
    }
    ( string_push_str . tv key `title` )
    ( string_push_str . tv value `My Page` )
    ( vec_push [TemplateVar] vars tv )
    : String out ( template_render_layout
        `<html><head><title>{{title}}</title></head><body>{{% content %}}</body></html>`
        `<p>Hello</p>` vars )
    ( string_free . tv key )
    ( string_free . tv value )
    ( vec_free [TemplateVar] vars )
    ^ out
}

// ── Test: template_render_layout — no marker, content prepended ──────

@ test_template_layout_no_marker → String {
    : ( Vec TemplateVar ) vars ( vec_new [TemplateVar] )
    : String out ( template_render_layout `plain text` `content` vars )
    ( vec_free [TemplateVar] vars )
    ^ out
}

// ── Test: layout with multiple vars ───────────────────────────────────

@ test_template_layout_multi → String {
    : ( Vec TemplateVar ) vars ( vec_new [TemplateVar] )
    : TemplateVar t1 @ TemplateVar { ( string_new ) ( string_new ) }
    ( string_push_str . t1 key `title` )
    ( string_push_str . t1 value `Home` )
    ( vec_push [TemplateVar] vars t1 )
    : TemplateVar t2 @ TemplateVar { ( string_new ) ( string_new ) }
    ( string_push_str . t2 key `year` )
    ( string_push_str . t2 value `2026` )
    ( vec_push [TemplateVar] vars t2 )
    : String out ( template_render_layout
        `{{title}} | {{% content %}} | {{year}}`
        `body` vars )
    ( string_free . t1 key ) ( string_free . t1 value )
    ( string_free . t2 key ) ( string_free . t2 value )
    ( vec_free [TemplateVar] vars )
    ^ out
}

// ── Test: template_render with unmatched var — emits raw ─────────────

@ test_template_unmatched → String {
    : ( Vec TemplateVar ) vars ( vec_new [TemplateVar] )
    : String out ( template_render `{{missing}}` vars )
    ( vec_free [TemplateVar] vars )
    ^ out
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
