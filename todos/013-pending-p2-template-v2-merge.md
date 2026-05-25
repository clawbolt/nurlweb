---
status: complete
priority: p2
tags: [code-review, architecture, simplicity]
agent: code-simplicity-reviewer
---

# P2: template_v2.nu should merge into template.nu

## Finding
Two template modules exist with overlapping concerns:
- `template.nu` (427 LOC): {{key}} substitution, layout/include, render_html
- `template_v2.nu` (191 LOC): #if/#unless block directives

`template_v2` imports `template.nu` and reimplements var lookup (`has_val` inline — same algorithm as `__try_push_var`). Three functions (`template_if`, `template_v2`, `__find_close`) could live in `template.nu`.

## Recommendation
Merge `template_v2.nu` into `template.nu`. Make `template_render` take an `html_escape` flag instead of having `template_render_html` as a separate function.
