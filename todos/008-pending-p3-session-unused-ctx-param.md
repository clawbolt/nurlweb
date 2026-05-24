---
status: complete
priority: p3
tags: [code-review, simplicity]
agent: code-simplicity-reviewer
file: session.nu:25-36
---

# Unused Ctx Parameter in session_set and session_del

## Finding
`session_set` and `session_del` accept `Ctx ctx` as their first parameter but never read from it. This is intentional — the FRAMEWORK.md design mandates "Ctx as first arg for uniform LLM-friendly API surface."

## Location
- `session.nu:25` — `session_set Ctx ctx HttpResponse r s name s value → v`
- `session.nu:31` — `session_del Ctx ctx HttpResponse r s name → v`

## Impact
- Dead parameter that LLMs must supply (mild friction)
- Slightly misleading — suggests Ctx is needed when it isn't
- Follows the established convention (ctx_ok, ctx_json, etc. also take Ctx without using it for response helpers)

## Recommendation
This is a deliberate design choice, not a bug. Consider:
- Document in FRAMEWORK.md that response/utility functions take Ctx for API uniformity even when unused
- OR: break the convention for utility functions that truly don't need Ctx (trade uniform API for honesty)

Given the LLM-first design, keeping the convention is reasonable. This todo is informational — close as "won't fix" if the convention is intentional.
