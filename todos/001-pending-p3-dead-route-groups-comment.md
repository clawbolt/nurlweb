---
status: complete
priority: p3
tag: code-review, quality
---

# Remove dead "Route groups" comment block from app.nu

**Finding:** `app.nu` has a comment block (~5 lines) describing `app_group` — a feature that is deferred to v1.1 and not implemented. This is dead documentation in the code.

**Location:** `app.nu`, the section header "// ── Route groups ──" and the comment below it.

**Action:** Remove the comment block. The pattern (manual prefix variables) is already documented in FRAMEWORK.md.
