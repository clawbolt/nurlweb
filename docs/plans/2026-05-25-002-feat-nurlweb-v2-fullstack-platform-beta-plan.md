---
title: feat: NurlWeb v2 — Full-Stack Application Platform
type: feat
status: active
date: 2026-05-25
origin: docs/architecture-reflection-2026-05-25.md
deepened: 2026-05-25
ceo-reviewed: 2026-05-25
mode: SCOPE_EXPANSION
---

# NurlWeb v2 — Full-Stack Application Platform

## Overview

v1.x built the micro-framework base (14 modules, ~2875 LOC, all stdlib wrappers).
v2 breaks the zero-fork boundary — building database, auth, and template infrastructure
directly on NURL C builtins where stdlib doesn't yet provide primitives.

6 CEO-approved modules transform nurlweb from a "web wiring layer" into a
full-stack application platform: ORM, JWT auth, template engine upgrade,
dev server with hot reload, middleware ecosystem, and CLI code generators.

**Total: ~1100 LOC new code, 6 new modules, 1 upgraded module, 3 new tools.**

## Problem Frame

v1.x nurlweb is solid but deliberately lean. Real application developers need:

- **Database access** — stdlib has full sqlite3 C builtins but no .nu wrapper. Every app must write raw sqlite3_prepare/bind/step loops.
- **Token-based auth** — Basic Auth only. No JWT sign/verify for API development. HMAC-SHA256 builtins exist unused.
- **Template conditionals/loops** — {{key}} substitution is not a template engine. No `{{#each}}`, no `{{#if}}`.
- **Dev experience** — Manual compile-link-run cycle. No hot reload, no CLI generators.
- **Production middleware** — No compression, CSRF protection, request timeouts.

Every gap has a C builtin ready — nurlweb just needs to build on them.

## Requirements Trace

- R1. SQLite ORM-lite: `orm_model`, `orm_find`, `orm_where`, `orm_create`, `orm_update`, `orm_delete` — wrapping sqlite3 C builtins
- R2. Template upgrade: `{{#each}}`, `{{#if}}/{{#else}}` — recursive parser, backward compatible
- R3. JWT Auth: `jwt_sign`, `jwt_verify`, `auth_jwt_required` — HMAC-SHA256, alg=none hardening
- R4. Dev server: `nurlweb dev --watch` — auto-recompile on file change
- R5. Middleware: `compress.nu`, `csrf.nu`, `timeout.nu`
- R6. CLI generators: `nurlweb g model/controller/middleware/scaffold` — template-driven code gen
- R7. Self-built modules use C builtins only, not stdlib .nu internals
- R8. Zero existing API breakage — all new modules are opt-in
- R9. Compile-time test per module (exit 0 with nurlc)

## Scope Boundaries

- **In scope:** orm.nu, template.nu upgrade, auth_jwt.nu, compress.nu, csrf.nu, timeout.nu, dev server, CLI generators
- **Self-build threshold:** module exists in 2+ real app requirements AND stdlib won't ship within 3 months
- **Out of scope:** Redis session store (no Redis client in stdlib), HTTP/2 (too complex for self-build), plugin auto-discovery (v3), migration system (v3), OpenAPI generation

## Context & Research

### C Builtins Available (verified)

| Builtin | Signature | Used By |
|---------|-----------|---------|
| `nurl_sqlite_open` | `i8*` path → `i64` handle | orm.nu |
| `nurl_sqlite_prepare` | `i64` db, `i8*` sql → `i64` stmt | orm.nu |
| `nurl_sqlite_bind_int/text/null` | `i64` stmt, `i64` idx, ... → `i64` err | orm.nu |
| `nurl_sqlite_step` | `i64` stmt → `i64` (100=row, 101=done) | orm.nu |
| `nurl_sqlite_column_int/text` | `i64` stmt, `i64` idx → ... | orm.nu |
| `nurl_sqlite_finalize` | `i64` stmt → void | orm.nu |
| `nurl_hmac_sha256_hex` | `i8*` key, `i8*` msg → `i8*` hex | auth_jwt.nu |
| `nurl_sha256_hex` | `i8*` msg → `i8*` hex | auth_jwt.nu |

### Previous Decisions

- **Zero fork → self-build threshold:** v1.x strategy was "wrap stdlib only." v2 introduces self-built modules for stdlib gaps. Decision rule: C builtin exists AND stdlib .nu wrapper absent AND 2+ app needs.
- **Ctx-first convention:** preserved. New modules accepting request context use Ctx as first arg.
- **Single-file modules:** orm.nu may exceed 200 LOC (estimated ~300). This is accepted — sqlite3 wrapping is inherently complex. If >400 LOC, split into orm.nu + orm_query.nu.

## Key Technical Decisions

- **D1: orm.nu uses sqlite3 C builtins directly** — no stdlib intermediary. Type mapping via struct field metadata.
- **D2: JWT alg=none hardening** — jwt_verify ignores `alg` header, always uses HMAC-SHA256
- **D3: Template upgrade is additive** — existing `template_render`/`template_render_html` unchanged. New parser extends same module.
- **D4: Dev server is POSIX shell** — `inotifywait` (Linux) / `fswatch` (macOS) + signal-based restart
- **D5: CLI generators use template.nu** — `nurlweb g scaffold` renders .nu files from templates/

## High-Level Technical Design

```
nurlweb CLI (new · g · dev)
        │
┌───────▼──────────────────────────────────────────────────────────┐
│                     New Modules (v2)                              │
│  orm.nu (sqlite3) · auth_jwt.nu (HMAC-SHA256)                    │
│  compress.nu · csrf.nu · timeout.nu                              │
│  template.nu (upgraded: loops + conditionals)                     │
└───────┬──────────────────────────────────────────────────────────┘
        │
┌───────▼──────────────────────────────────────────────────────────┐
│                     Existing (v1.x)                               │
│  app.nu  ctx.nu  routegroup.nu  session.nu  upload.nu            │
│  cors.nu  validate.nu  error.nu  auth.nu  static.nu              │
│  ws.nu  respond.nu  logger.nu                                    │
└───────┬──────────────────────────────────────────────────────────┘
        │
┌───────▼──────────────────────────────────────────────────────────┐
│                     NURL C builtins + stdlib                       │
│  sqlite_* · hmac_sha256_hex · sha256_hex · compress              │
│  http_* · json · string · vec · file · tcp · net                 │
└──────────────────────────────────────────────────────────────────┘
```

### Module Designs

**orm.nu** (~300 LOC):
- `orm_model(s table, Vec<OrmField> fields) → OrmModel` — model definition
- `orm_find([Model], i id) → ?Model` — single row lookup
- `orm_where([Model], s column, ?i value) → Vec<Model>` — filtered query
- `orm_create([Model], Model) → ?Model` — INSERT returning row
- `orm_update([Model], i id, Model) → ?Model` — UPDATE returning row
- `orm_delete([Model], i id) → b` — DELETE, returns success
- Type mapping: FIELD_INT, FIELD_TEXT, FIELD_BLOB, FIELD_REAL
- Parameterized queries — zero SQL injection risk

**auth_jwt.nu** (~120 LOC):
- `jwt_sign(s payload_json, s secret) → String` — HMAC-SHA256 JWT
- `jwt_verify(s token, s secret) → ?JwtClaims` — verify + decode payload
- `auth_jwt_required(App, s secret) → v` — middleware, 401 on invalid/expired
- Alg=none hardening: verify ignores token header alg, always uses HS256

**template.nu upgrade** (~150 LOC added):
- `{{#each items}}...{{/each}}` — iterate over Vec, binds `this`
- `{{#if condition}}...{{#else}}...{{/if}}` — boolean branch
- Recursive block parser, max depth 16

**Middleware ecosystem** (~150 LOC total):
- `compress.nu` — `app_with_compress(App) → v`, wraps stdlib compress builtins
- `csrf.nu` — `csrf_token(Ctx) → String`, `app_with_csrf(App, s secret) → v`
- `timeout.nu` — `app_with_timeout(App, i ms) → v`, 408 on overrun

**Dev server** (~80 LOC shell):
- `nurlweb dev [--watch] [--port N]` — build + serve + watch
- File change detection: fswatch (macOS) / inotifywait (Linux)
- Signal-based restart: SIGTERM → recompile → spawn new process

**CLI generators** (~200 LOC shell):
- `nurlweb g model Name field:type...` → generates model struct + orm definition
- `nurlweb g controller Name action...` → generates handler stubs
- `nurlweb g scaffold Name field:type...` → full CRUD (model + controller + routes)
- `nurlweb g middleware Name` → generates middleware module

## API Surface Summary

| Module | Public Functions | LOC |
|--------|-----------------|-----|
| orm.nu | `orm_model`, `orm_find`, `orm_where`, `orm_create`, `orm_update`, `orm_delete` | ~300 |
| auth_jwt.nu | `jwt_sign`, `jwt_verify`, `auth_jwt_required` | ~120 |
| template.nu (upgrade) | `template_render` (extended), `template_render_html` (extended) | +150 |
| compress.nu | `app_with_compress` | ~40 |
| csrf.nu | `csrf_token`, `csrf_verify`, `app_with_csrf` | ~60 |
| timeout.nu | `app_with_timeout` | ~50 |
| Dev server | `nurlweb dev` | ~80 |
| CLI generators | `nurlweb g` subcommands | ~200 |
| **Total** | | **~1000 LOC** |

## File Manifest

### New files
- `nurlweb/orm.nu` — SQLite ORM-lite
- `nurlweb/test_orm.nu` — compile-time test
- `nurlweb/auth_jwt.nu` — JWT auth
- `nurlweb/test_jwt.nu` — compile-time test
- `nurlweb/compress.nu` — response compression
- `nurlweb/test_compress.nu` — compile-time test
- `nurlweb/csrf.nu` — CSRF protection
- `nurlweb/test_csrf.nu` — compile-time test
- `nurlweb/timeout.nu` — request timeout
- `nurlweb/test_timeout.nu` — compile-time test

### Modified files
- `nurlweb/template.nu` — add {{#each}}, {{#if}}/{{#else}} block parser
- `nurlweb/test_template.nu` — add block rendering tests
- `nurlweb/bin/nurlweb` — add `dev` and `g` subcommands
- `nurlweb/nurlweb.nu` — add v2 module imports
- `nurlweb/FRAMEWORK.md` — v2 API reference
- `nurlweb/README.md` — feature table
- `nurlweb/CHANGELOG.md` — 0.4.0.0
- `nurlweb/VERSION` — 0.4.0.0

## Test Plan

### Compile-time tests (exit 0 with nurlc)
- test_orm.nu — orm_model/find/where/create/update/delete + struct type mapping
- test_jwt.nu — jwt_sign/verify + middleware composition
- test_compress.nu — app_with_compress middleware
- test_csrf.nu — csrf_token/verify + middleware
- test_timeout.nu — app_with_timeout middleware
- test_template.nu — add #each/#if block rendering cases

### New total: 20 compile tests

## Sequencing

| Phase | Items | Est. LOC | Depends On |
|-------|-------|----------|-----------|
| **V2-A** | orm.nu + test_orm.nu | +360 | sqlite3 C builtins |
| **V2-B** | auth_jwt.nu + test_jwt.nu | +190 | HMAC-SHA256 C builtins |
| **V2-C** | template.nu upgrade + test update | +200 | existing template.nu |
| **V2-D** | compress.nu + csrf.nu + timeout.nu + tests | +210 | app.nu middleware pipeline |
| **V2-E** | nurlweb dev + nurlweb g | +280 | template.nu (for generators) |
| **Finalize** | docs, version bump | +50 | all modules shipped |

**Total: ~1290 LOC**

## Risks & Dependencies

| Risk | Severity | Mitigation |
|------|----------|------------|
| orm.nu sqlite3 error handling — binding errors, schema mismatch | Medium | Map all sqlite3 error codes to NURL error types. Test with malformed SQL. |
| jwt_sign base64 encoding — NURL has no base64 builtin | **High** | Must implement base64url encoding in ~30 LOC. Verify against RFC 7515 test vectors. |
| Template recursion depth — nested #each/#if blocks | Low | Hard cap at 16 levels. Document stack usage. |
| nurlweb dev cross-platform — fswatch vs inotifywait | Low | Detect OS automatically. Fall back to polling (sleep 1s) if neither available. |
| orm.nu > 300 LOC | Low | Split into orm.nu + orm_schema.nu if >400 LOC before implementation. |
| Self-build precedent — future modules may proliferate | Medium | Document self-build threshold in FRAMEWORK.md. Require 2+ app needs + absent stdlib + existing C builtin. |

## Alternative Approaches Considered

- **ORM via code generation (compile-time SQL → NURL structs):** Rejected. NURL has no macro system. Runtime sqlite3 binding is simpler and sufficient.
- **JWT via external process:** Rejected. NURL has HMAC builtins — calling an external `openssl` process adds deployment complexity.
- **Template upgrade as separate module:** Rejected. Would fork the template.nu user base. Adding to existing module is additive and backward-compatible.
- **nurlweb dev as Rust/Go binary:** Rejected. Shell script is zero-dependency and trivially debuggable.

## Open Questions

### Resolved During Planning
- Zero fork boundary: established self-build threshold (C builtin exists + stdlib absent + 2+ app needs)
- orm.nu 200 LOC limit: waived — estimated 300 LOC is acceptable for sqlite3 complexity
- JWT alg=none: must be hardened in implementation

### Deferred to Implementation
- Exact orm_field type mapping (how does Vec<OrmField> map to sqlite3 column types?)
- JWT base64url encoding implementation strategy
- nurlweb g scaffold template structure

## Documentation / Operational Notes

- **FRAMEWORK.md:** add Self-Build Module Policy section
- **FRAMEWORK.md:** add ORM, JWT, Middleware ecosystem API reference
- **README.md:** `nurlweb new` → `nurlweb g scaffold` → `nurlweb dev` quickstart flow
- **CHANGELOG.md:** 0.4.0.0 — v2 Full-Stack Platform
- **VERSION:** 0.4.0.0

## Sources & References

- Architecture reflection: [docs/architecture-reflection-2026-05-25.md](../architecture-reflection-2026-05-25.md)
- CEO plan: `~/.gstack/projects/nurlweb/ceo-plans/2026-05-25-nurlweb-v2-platform.md`
- Previous plan: [docs/plans/2026-05-25-001-architecture-fixes-and-features-beta-plan.md](2026-05-25-001-architecture-fixes-and-features-beta-plan.md)
- C builtins: sqlite_*, hmac_sha256_hex, sha256_hex, compress (verified in nurlc LLVM IR output)
- nurlc: `/Users/t77yq/Documents/Codex/2026-05-24/nurl-lang-nurl-https-github-com-2/build/nurlc`

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Full-stack platform vision (SCOPE EXPANSION) | 2 | CLEAR | 6/6 accepted, 1 JWT alg=none hardening, 1 orm.nu self-build precedent, 0 critical gaps |

- **VERDICT:** CEO CLEARED — ready for eng review + implementation
