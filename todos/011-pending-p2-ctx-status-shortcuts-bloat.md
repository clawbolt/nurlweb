---
status: complete
priority: p2
tags: [code-review, simplicity]
agent: code-simplicity-reviewer
---

# P2: ctx.nu — 10 HTTP status shortcuts bloats API surface

## Finding
`ctx.nu` defines 10 status convenience functions: `ctx_ok`, `ctx_created`, `ctx_accepted`, `ctx_no_content`, `ctx_bad_request`, `ctx_unauthorized`, `ctx_forbidden`, `ctx_not_found`, `ctx_conflict`, `ctx_error`.

The claimed "6 function names to learn" is not true when ctx.nu adds 10 more. An LLM can write `ctx_text ctx 201 body` just as easily as `ctx_created ctx body`.

## Recommendation
Keep only 3: `ctx_ok`, `ctx_not_found`, `ctx_error`. Remove the other 7. Rare status codes (201, 204, 409) don't justify dedicated functions.
