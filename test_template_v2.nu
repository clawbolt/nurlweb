// nurlweb/test_template_v2.nu — Compile-time tests for template_v2.nu
//
// Run: ./build/nurlc nurlweb/test_template_v2.nu
// Expected: exit 0

$ `nurlweb/template_v2.nu`

// ── template_if smoke test ───────────────────────────────────────────

@ test_template_if → String {
    : Vec TemplateVar vars ( vec_new [TemplateVar] )
    : TemplateVar tv @ TemplateVar { ( string_with_cap 4 ) ( string_with_cap 4 ) }
    ( string_push_str ( string_data . tv key ) `show` )
    ( string_push_str ( string_data . tv value ) `yes` )
    ( vec_push [TemplateVar] vars tv )

    : s tpl `before {{#if show}}VISIBLE{{/if}} after`
    ^ ( template_if tpl vars )
}

// ── template_if hidden ────────────────────────────────────────────────

@ test_template_if_hidden → String {
    : Vec TemplateVar vars ( vec_new [TemplateVar] )
    : s tpl `x {{#if missing}}HIDDEN{{/if}} y`
    ^ ( template_if tpl vars )
}

// ── template_v2 full pipeline ─────────────────────────────────────────

@ test_template_v2 → String {
    : Vec TemplateVar vars ( vec_new [TemplateVar] )
    : TemplateVar tv @ TemplateVar { ( string_with_cap 8 ) ( string_with_cap 8 ) }
    ( string_push_str ( string_data . tv key ) `name` )
    ( string_push_str ( string_data . tv value ) `World` )
    ( vec_push [TemplateVar] vars tv )

    : s tpl `Hello {{name}}! {{#if name}}You are {{name}}{{/if}}`
    ^ ( template_v2 tpl vars )
}

// ── template_unless ───────────────────────────────────────────────────

@ test_template_unless → String {
    : Vec TemplateVar vars ( vec_new [TemplateVar] )
    : s tpl `{{#unless missing}}SHOWN{{/unless}}done`
    ^ ( template_if tpl vars )
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
