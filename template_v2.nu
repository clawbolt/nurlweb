// nurlweb/template_v2.nu — v2 block directives (now merged into template.nu)
//
// Kept as a thin compatibility re-export. All implementations live in template.nu.
// Prefer importing template.nu directly for new code.
//
// API (all in template.nu):
//   ( template_if  s tpl ( Vec TemplateVar ) vars ) → String  — expand #if/#unless blocks
//   ( template_v2  s tpl ( Vec TemplateVar ) vars ) → String  — blocks + render

$ `nurlweb/template.nu`
