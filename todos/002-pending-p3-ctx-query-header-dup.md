---
status: complete
priority: p3
tag: code-review, quality
---

# ctx_query and ctx_header are identical — consolidate or comment

**Finding:** `ctx_query` and `ctx_header` in ctx.nu have identical implementations:
```nurl
@ ctx_query Ctx c s name → ?String  { ^ ( header_get . c req name ) }
@ ctx_header Ctx c s name → ?String { ^ ( header_get . c req name ) }
```
Both call `header_get`. In NURL's HTTP stack, query params are stored in headers, so this is technically correct. But the duplication without explanation is confusing.

**Options:**
- A) Add a comment: `// In NURL's HTTP stack, query pairs are stored in headers`
- B) Have `ctx_query` delegate to `ctx_header`: `@ ctx_query Ctx c s name → ?String { ^ ( ctx_header c name ) }`
