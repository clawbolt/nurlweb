---
status: complete
priority: p2
tags: [code-review, security]
agent: security-sentinel
---

# P2: orm.nu — table/column name SQL injection via string concatenation

## Finding
`orm.nu` uses `nurl_sqlite_prepare` with parameterized VALUES (via `__orm_bind_params`), but the SQL string itself is built by the caller through `nurl_str_cat`. There is no API for safely quoting identifiers (table names, column names).

```nurl
@ orm_query OrmDB db s sql ( Vec OrmParam ) params → ! ( Vec OrmRow ) DbErr {
    : i stmt ( nurl_sqlite_prepare . db handle sql )
```

If a caller builds SQL like `nurl_str_cat "SELECT * FROM " table_name`, the table name is interpolated unsafely.

## Recommendation
Add `orm_quote_ident(s name) → s` that wraps identifiers in double-quotes and escapes embedded quotes, per SQLite identifier quoting rules.
