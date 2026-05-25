---
status: pending
priority: p3
tags: [code-review, architecture]
agent: code-simplicity-reviewer
---

# P3: orm.nu leaks C-level raw pointer builtins through NURL type system

## Finding
`orm_query` uses `nurl_poke`, `nurl_peek`, `nurl_zalloc`, `nurl_realloc` directly — these are compiler builtins for manual memory management. The 150+ LOC result-set builder does raw pointer arithmetic that has nothing to do with SQL.

This makes orm.nu fragile (one wrong offset = buffer corruption at runtime) and unreadable for LLMs trying to understand the ORM layer.

## Recommendation
Encapsulate the C-level operations behind a `RowIterator` type or a `__rows_builder` internal function. The public API should never expose `nurl_poke`/`nurl_peek`.
