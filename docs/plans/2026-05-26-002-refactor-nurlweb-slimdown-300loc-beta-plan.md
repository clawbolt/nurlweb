---
title: refactor: nurlweb slim-down — 21 → 4 core modules (Phase 1 of Great Split)
type: refactor
status: draft
date: 2026-05-26
parent: "[CEO Review] nurlweb + nurlweb-kit 根本重构"
dependencies: none
---

# nurlweb Slim-Down: 21 Modules → 4 Core (~300 LOC)

## Overview

nurlweb currently has 21 modules (3817 LOC) — a micro-framework that grew into a mini-framework. The CEO Review identified that 17 modules belong in nurlweb-kit (the "Egg.js" layer), not nurlweb (the "Koa" layer).

This plan executes Phase 1 of the Great Split — **nurlweb slim-down**. Zero API breakage via legacy shims. Phase 2 (not in scope) moves shimmed modules into nurlweb-kit.

## Problem Frame

**Current state:** nurlweb has auth, JWT, ORM, session, template engine, WebSocket, validation, upload, CORS, CSRF — all in a "micro-framework." Users import 15+ modules to build a CRUD app. The README says "six function names to learn" but the truth is ~26.

**Target state:** nurlweb = 4 core modules (app, respond, routegroup, aggregator). Everything else lives in `legacy/` with thin re-export shims at original paths. Users who don't need the extras import only `nurlweb/app.nu`.

**Compatibility guarantee:** Every existing `$ 'nurlweb/<module>.nu'` import continues to work via one-line shim files. No user code changes required.

## Core Keep (4 files, ~307 LOC)

| File | LOC | Why keep |
|------|-----|----------|
| `app.nu` | 172 | The framework. App, Router, Middleware, Serve. |
| `respond.nu` | 46 | Response shortcuts. Used by ctx.nu. Standalone utility. |
| `routegroup.nu` | 70 | Prefix route grouping. Zero new concepts, delegates to Router. |
| `nurlweb.nu` | ~19 | Entry point. Updated: imports app.nu directly instead of ctx.nu. |

## Legacy Move (17 files → `legacy/`)

| Category | Files | Internal deps |
|----------|-------|---------------|
| **Auth** | `auth.nu` (70), `auth_jwt.nu` (85) | auth depends on ctx |
| **Middleware** | `compress.nu` (19), `cors.nu` (22), `csrf.nu` (44), `error.nu` (129), `logger.nu` (76), `timeout.nu` (16) | compress/cors/error/logger depend on app; csrf standalone; timeout standalone |
| **Context** | `ctx.nu` (266) | depends on app + respond |
| **Data** | `orm.nu` (384) | standalone |
| **View** | `template.nu` (619), `template_v2.nu` (10) | v2 depends on template |
| **Network** | `static.nu` (58), `upload.nu` (71), `ws.nu` (97) | static/upload depend on ctx |
| **Validation** | `validate.nu` (168) | depends on ctx |
| **Session** | `session.nu` (184) | depends on ctx |

## Shim Strategy

Each moved module gets a one-line replacement at its original path:

```nurl
// nurlweb/auth.nu — moved to legacy/ in v3.0
// Import directly for new code: $ `nurlweb/legacy/auth.nu`
$ `nurlweb/legacy/auth.nu`
```

**Why shims instead of direct move:** Users who clone nurlweb will have existing `$ 'nurlweb/ctx.nu'` imports. Moving files without shims breaks every existing project. Shims cost 1 file each (17 files × 3 lines ≈ 51 LOC) and guarantee zero breakage.

**Shim naming convention:** The comment tells humans where the file moved. The `$` line is the only runtime code. No logic duplication.

## File Tree: Before → After

```
nurlweb/                          nurlweb/
├── app.nu          (keep)        ├── app.nu          (keep)
├── respond.nu      (keep)        ├── respond.nu      (keep)
├── routegroup.nu   (keep)        ├── routegroup.nu   (keep)
├── nurlweb.nu      (keep, edit)  ├── nurlweb.nu      (edited)
├── ctx.nu          (→ legacy)    ├── ctx.nu          (SHIM → legacy/ctx.nu)
├── auth.nu         (→ legacy)    ├── auth.nu         (SHIM)
├── auth_jwt.nu     (→ legacy)    ├── auth_jwt.nu     (SHIM)
├── compress.nu     (→ legacy)    ├── compress.nu     (SHIM)
├── cors.nu         (→ legacy)    ├── cors.nu         (SHIM)
├── csrf.nu         (→ legacy)    ├── csrf.nu         (SHIM)
├── error.nu        (→ legacy)    ├── error.nu        (SHIM)
├── logger.nu       (→ legacy)    ├── logger.nu       (SHIM)
├── orm.nu          (→ legacy)    ├── orm.nu          (SHIM)
├── session.nu      (→ legacy)    ├── session.nu      (SHIM)
├── static.nu       (→ legacy)    ├── static.nu       (SHIM)
├── template.nu     (→ legacy)    ├── template.nu     (SHIM)
├── template_v2.nu  (→ legacy)    ├── template_v2.nu  (SHIM)
├── timeout.nu      (→ legacy)    ├── timeout.nu      (SHIM)
├── upload.nu       (→ legacy)    ├── upload.nu       (SHIM)
├── validate.nu     (→ legacy)    ├── validate.nu     (SHIM)
├── ws.nu           (→ legacy)    ├── ws.nu           (SHIM)
├── test_*.nu       (→ legacy)    │
                                  ├── legacy/
                                  │   ├── ctx.nu
                                  │   ├── auth.nu
                                  │   ├── auth_jwt.nu
                                  │   ├── ...
                                  │   ├── ws.nu
                                  │   └── tests/
                                  │       ├── test_auth.nu
                                  │       ├── ...
                                  │       └── test_ws.nu
```

## Detailed Changes

### Change 1: `nurlweb.nu` — new entry point

**Before:**
```nurl
$ `nurlweb/ctx.nu`
```

**After:**
```nurl
// nurlweb/nurlweb.nu — Single-import aggregator (v3.0 slim core)
//
// Clone nurlweb into your project as `nurlweb/`:
//   git clone https://github.com/clawbolt/nurlweb nurlweb
//
// Then import:
//   $ `nurlweb/nurlweb.nu`    → core framework (App + Respond + RouteGroup)
//   $ `nurlweb/app.nu`        → micro-framework only (App)
//
// Legacy modules available under legacy/:
//   $ `nurlweb/legacy/ctx.nu`       → rich request context
//   $ `nurlweb/legacy/session.nu`   → cookie + server-side sessions
//   $ `nurlweb/legacy/orm.nu`       → SQLite ORM
//   $ `nurlweb/legacy/template.nu`  → {{key}} template engine
//   (existing imports via original paths still work via shims)

$ `nurlweb/app.nu`
$ `nurlweb/respond.nu`
$ `nurlweb/routegroup.nu`
```

### Change 2: Create `legacy/` directory + move files

Each moved file keeps its content unchanged. Only location changes.

```
mkdir nurlweb/legacy/
mkdir nurlweb/legacy/tests/

# Move modules
mv nurlweb/{auth, auth_jwt, compress, cors, csrf, ctx, error, logger, orm, session, static, template, template_v2, timeout, upload, validate, ws}.nu nurlweb/legacy/

# Move tests
mv nurlweb/test_*.nu nurlweb/legacy/tests/
```

### Change 3: Create shim files at original paths

**Shim template:**
```nurl
// nurlweb/<name>.nu — moved to nurlweb/legacy/<name>.nu (nurlweb v3.0)
// For new code, import directly: $ `nurlweb/legacy/<name>.nu`
$ `nurlweb/legacy/<name>.nu`
```

**Shim files to create (17 files):**
- `ctx.nu`, `auth.nu`, `auth_jwt.nu`, `compress.nu`, `cors.nu`, `csrf.nu`
- `error.nu`, `logger.nu`, `orm.nu`, `session.nu`, `static.nu`
- `template.nu`, `template_v2.nu`, `timeout.nu`, `upload.nu`, `validate.nu`, `ws.nu`

### Change 4: No changes to nurlweb-kit

Phase 1 is scoped to nurlweb only. nurlweb-kit continues to import from `nurlweb/` via shims until Phase 2 migrates modules into kit.

## Compatibility Impact

| User scenario | Before | After | Broken? |
|---------------|--------|-------|---------|
| `$ 'nurlweb/nurlweb.nu'` | imports ctx → app + respond + all | imports app + respond + routegroup directly | **No break** — smaller surface, same core API |
| `$ 'nurlweb/app.nu'` | imports app.nu | imports app.nu (unchanged) | **No break** |
| `$ 'nurlweb/ctx.nu'` | imports ctx.nu (266 LOC) | shim → legacy/ctx.nu (same content) | **No break** |
| `$ 'nurlweb/orm.nu'` | imports orm.nu (384 LOC) | shim → legacy/orm.nu (same content) | **No break** |
| `$ 'nurlweb/auth.nu'` | imports auth.nu (70 LOC) | shim → legacy/auth.nu (same content) | **No break** |

**Zero breaking changes.** Every import path resolves to the same module content. NURL's import system (`$ 'path'`) is textual include — shims work identically to direct files.

## Verification

### Verification 1: Core compiles in isolation
```bash
./build/nurlc nurlweb/app.nu        # must compile
./build/nurlc nurlweb/respond.nu    # must compile
./build/nurlc nurlweb/routegroup.nu # must compile
./build/nurlc nurlweb/nurlweb.nu    # must compile (new aggregator)
```

### Verification 2: All 20 tests pass via shims
```bash
for f in nurlweb/legacy/tests/test_*.nu; do
  ./build/nurlc "$f" || echo "FAIL: $f"
done
# Expected: 20/20 pass
```

### Verification 3: Shim transparency
```bash
# Original import path still resolves
./build/nurlc -e '$ `nurlweb/ctx.nu`'   # compiles
./build/nurlc -e '$ `nurlweb/orm.nu`'   # compiles
```

### Verification 4: Legacy direct import works
```bash
./build/nurlc -e '$ `nurlweb/legacy/ctx.nu`'  # compiles
```

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Circular shim — shim imports legacy, legacy imports something that imports shim | Low | Legacy modules only import nurlweb core + stdlib, never other shims. Verified by dep graph. |
| `template_v2.nu` shim breaks because it imports `template.nu` | Low | Both shimmed — v2 shim → legacy/v2, which imports legacy/template. Same resolution path. |
| nurlweb-kit tests break because they import from nurlweb | Low | nurlweb-kit imports `nurlweb/app.nu` (core, unchanged) and `nurlweb/template.nu` (shimmed). Shims transparent. |
| Someone removes legacy/ thinking it's unused | Medium | README + comments in nurlweb.nu document the legacy/ directory. |

## Dependencies & Sequencing

```
Phase 1 (this plan)
  ├── Create legacy/ directory
  ├── Move 17 modules + 20 tests into legacy/
  ├── Create 17 shim files at original paths
  ├── Update nurlweb.nu entry point
  └── Verify: 20/20 tests via shims, core compiles standalone
        │
        ▼
Phase 2 (nurlweb-kit absorption — NOT in scope)
  ├── Move legacy/ modules into nurlweb-kit
  ├── Delete shim files
  └── Update kit imports
```

## Execution Notes

- **Test-first posture:** Run the full test suite BEFORE any file moves. Commit baseline. Move files. Re-run tests. Diff must show zero regressions.
- **No code changes in moved modules.** File content is identical — only location changes.
- **Shim files are 3 lines each.** Use a shell loop to generate them.
- **nurlweb-kit is untouched.** This is a nurlweb-only change.

## NOT in Scope

- Moving modules into nurlweb-kit (Phase 2)
- Deleting legacy/ directory (Phase 3, after kit absorption)
- Changing any module's internal code
- Merging template.nu + template_v2.nu (already done in prior review)
- Changing nurlweb-kit's import paths
- The CLI generator improvements
