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

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
