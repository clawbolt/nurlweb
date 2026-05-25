---
status: complete
priority: p2
tags: [code-review, security]
agent: security-sentinel
file: template.nu:1-7
---

# Template Rendering: No HTML Escaping — Documentation Gap

## Finding
`template_render` performs raw string substitution of `{{key}}` placeholders with no HTML entity escaping. If used in an HTML context (e.g., rendering user-submitted content into HTML responses), this is an XSS vector.

The module header describes it as "string template rendering" — not "HTML template rendering" — so this is **not a bug**, but it's a dangerous **footgun** for LLM agents who may not distinguish the two contexts.

## Location
- `template.nu:1-7` — module header doesn't mention HTML safety
- `FRAMEWORK.md` — template docs don't warn about HTML context

## Impact
An LLM generating NURL code might use `template_render` to build HTML responses with user data, creating XSS vulnerabilities.

## Recommendation
1. Add a prominent warning in the module header and FRAMEWORK.md:
   ```
   // WARNING: template_render does NOT escape HTML entities.
   // Do NOT use for HTML templates with untrusted input.
   // Use a dedicated HTML template engine for web output.
   ```
2. Consider renaming to `string_template_render` to make the "string" context explicit.
3. Future: add `html_template_render` that escapes by default.
