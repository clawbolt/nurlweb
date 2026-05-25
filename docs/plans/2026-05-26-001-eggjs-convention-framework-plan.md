---
title: feat: nurlweb-kit — Convention Layer on top of NurlWeb
type: feat
status: active
date: 2026-05-26
mode: SCOPE_EXPANSION
ceo-reviewed: 2026-05-26
---

# nurlweb-kit — Egg.js-equivalent Convention Layer for Compiled-Native

## Overview

Build **nurlweb-kit**, a convention-over-configuration layer that sits **on top of** nurlweb (not inside it). Same relationship as Egg.js → Koa: nurlweb stays the thin micro-framework, kit adds conventions, structure, CLI generators, config, lifecycle, and structured logging.

**12 accepted scope expansions.** The CLI code generator is the center of the developer experience. In a compiled-native world with no runtime reflection, the CLI *is the framework*.

## Architecture

```
User's app/
  main.nu                  ← imports nurlweb-kit
  config/_default.nu       ← env-aware config
  controllers/             ← controller convention
  services/                ← service convention
  models/                  ← model stubs
  middleware/              ← custom middleware
  templates/               ← template files
  tests/                   ← test files

nurlweb-kit/               ← NEW (separate from nurlweb)
  ├── config.nu            ← env-aware config merging
  ├── controller.nu        ← controller convention + app_resources
  ├── service.nu           ← service file convention
  ├── lifecycle.nu         ← app before_start/after_start/before_stop hooks
  ├── logger.nu            ← structured logging (merged, not v2)
  ├── schedule.nu          ← periodic tasks (P3, deferred)
  ├── bin/nurlweb-kit      ← CLI: new, g scaffold, g controller, g service, check, dev
  └── templates/           ← CLI scaffold templates

nurlweb/                   ← UNCHANGED — stays as micro-framework
  app.nu, ctx.nu, orm.nu, template.nu, error.nu, ...
```

## Problem Frame

**rest_api.nu is 200 lines of boilerplate** for 5 CRUD routes on a single resource. That's the problem. A real app has 10+ resources. Egg.js solved this with conventions: auto-loaded controllers, environment-aware config, plugin system, service layer.

NurlWeb can't directly port Egg.js — NURL compiles to LLVM IR, no `require()`, no filesystem scanning, no reflection. The right approach: **conventions + code generator + thin runtime layer**, built as a separate package on top of nurlweb.

## Egg.js → nurlweb-kit Mapping

| Egg.js Concept | nurlweb-kit Equivalent | Key Difference |
|---|---|---|
| Application + lifecycle | `lifecycle.nu` hooks | Closure capture at compile time |
| Agent (cluster master) | Not needed | Multi-fiber scheduler handles it |
| Router (declarative) | `app_resources` | One function = 5 RESTful routes |
| Controller (auto-loaded) | `controller.nu` + CLI generator | CLI creates files, user imports them |
| Service (business logic) | `service.nu` convention | Pure functions, explicit params, no DI |
| Middleware (auto-loaded) | nurlweb `app_use` | Unchanged — kit doesn't touch it |
| Config (env-aware) | `config.nu` startup-time merge | `_default.nu` + `_prod.nu` → merged config |
| Plugin system | Convention, not registry | Import + call `plugin_start(App)` directly |
| Schedule (cron) | `schedule.nu` (P3, deferred) | Async fibers need maturity |
| Logger (structured) | `logger.nu` (merged) | Single module with levels + request logging |

## Modules

### T1 (P1): `config.nu` — Environment-Aware Config (~80 LOC)

Startup-time config merging. Convention:

```
config/
  _default.nu    # base config (always loaded)
  _prod.nu       # production overrides
  _dev.nu        # development overrides
```

Merge strategy: `_default.nu` provides all keys, env-specific file overrides. Missing keys in default → `config_expect` validation error, server doesn't start.

API:
```nurl
@ config_get s key → s          # get string value
@ config_get_i s key → i        # get integer value
@ config_get_b s key → b        # get boolean value
@ config_env → s                # current env name ("dev" / "prod")
@ config_merge s defaults s overrides → s  # merge two config dicts
@ config_expect s key → !v ConfigErr  # validate key exists, fail fast
```

Config source: `NURL_ENV` environment variable, defaults to `"dev"`.

Files: `config.nu`, `config/_default.nu`, `config/_prod.nu`, `test_config.nu`

### T2 (P1): `controller.nu` + `app_resources` (~60 LOC)

Convention: each controller file exports handler functions. CLI creates files, user fills in logic.

**`app_resources` is the key function** — generates GET /, GET /:id, POST /, PUT /:id, DELETE /:id in one call:

```nurl
( app_resources app `/api/users` `user` )
```

Expands to 5 routes wired to `user_index`, `user_show`, `user_create`, `user_update`, `user_delete`.

With `only`/`except` filters (S10):

```nurl
( app_resources app `/api/users` `user` only: [index, show, create] )
( app_resources app `/api/admin` `admin` except: [delete] )
```

API:
```nurl
@ app_resources App a s prefix s controller_name → v
```

Implementation: generates 5 `router_*` calls against the App's Router, mapping to functions named `{name}_index`, `{name}_show`, `{name}_create`, `{name}_update`, `{name}_delete`.

Files: `controller.nu`, `test_controller.nu`

### T3 (P1): `service.nu` — Service Layer (~20 LOC)

Business logic lives in `services/*.nu`. Services are pure functions — no DI, no registry. Explicit parameter passing.

Convention:
```nurl
// services/user_service.nu
@ find_user OrmDB db i id → !OrmRow DbErr { ... }
@ create_user OrmDB db s name s email → !i DbErr { ... }
```

No `service_register`/`service_call` — stringly-typed DI in compiled-native erases type safety. Just import and call.

Files: `service.nu` (convention documentation + helpers only)

### T4 (P1): `lifecycle.nu` — App Lifecycle Hooks (~50 LOC)

Egg.js-style lifecycle hooks for the App.

API:
```nurl
@ app_before_start App a fn_ref → v     # register pre-start hook
@ app_after_start App a fn_ref → v      # register post-start hook
@ app_before_stop App a fn_ref → v      # register pre-stop hook
@ app_run_lifecycle App a → v           # execute lifecycle sequence
```

Semantics:
- `before_start` failure → hard stop, server doesn't start, returns error
- `after_start` failure → log warning, server continues running
- `before_stop` failure → log warning, shutdown continues

Files: `lifecycle.nu`, `test_lifecycle.nu`

### T5 (P1): `logger.nu` — Merged Structured Logging (~100 LOC)

**One logging module.** Extends nurlweb's existing request logger pattern with level-based logging and structured fields. Replaces the separate `logger_v2.nu` concept.

API:
```nurl
@ log_debug s msg → v
@ log_info s msg → v
@ log_warn s msg → v
@ log_error s msg → v
@ log_set_level s level → v             # "debug" / "info" / "warn" / "error"
@ log_with_fields s msg ( Vec LogField ) fields → v  # structured logging
@ app_with_logger App a → v             # request logging middleware (existing)
```

`LogField` is its own type (not `TemplateVar` — avoids template coupling):
```nurl
: LogField { String key String value }
```

Output format (JSON lines):
```json
{"level":"info","ts":"2026-05-26T12:00:00Z","msg":"server started","port":3000}
```

Request logger (`app_with_logger`) uses `log_info` internally. One import, one mental model.

Files: `logger.nu`, `test_logger.nu`

### T6 (P2): CLI Generators — `nurlweb-kit` Commands (~300 LOC)

The CLI is the center of the developer experience. Must produce **working, compilable code** — not empty files.

```bash
nurlweb-kit new blog                              # scaffold project
nurlweb-kit g scaffold post title:s body:s        # working CRUD + tests + routes wired
nurlweb-kit g controller user                     # controller with 5 handler stubs
nurlweb-kit g service user                        # service with find/create/update/delete
nurlweb-kit g model user name:s email:s           # orm model wrapper
nurlweb-kit check                                 # validate project conventions
nurlweb-kit dev                                   # build + run + watch for changes
```

**Auto-wiring:** `g scaffold` produces a `main.nu` with:
- Config imports and `config/_default.nu` created
- Controller imported and `app_resources` call wired
- Service functions defined
- Test stubs in `tests/test_{name}.nu`
- `.gitignore` with `config/_prod.nu` excluded

**Convention directory structure** (S9):
```
myapp/
  main.nu              # entry point (auto-generated)
  config/
    _default.nu        # base config
    _prod.nu           # production overrides (gitignored)
  controllers/
    user.nu            # controller handlers
  services/
    user_service.nu    # business logic
  models/
    user.nu            # orm model wrapper
  middleware/
  templates/
  tests/
    test_user.nu       # test stubs for all CRUD operations
  build.sh             # build script
  .gitignore
```

**`nurlweb-kit check`** (S5): validates:
- config directory exists with `_default.nu`
- controllers export expected handler functions
- `.gitignore` has `config/_prod.nu`
- All `$` imports resolve

**`nurlweb-kit dev`** (S8): wraps `nurlc` + `./app` with `fswatch`/`inotifywait` for auto-rebuild on `.nu` file changes. No hot module replacement (impossible in compiled-native), but a tight edit → compile → run loop.

**Test generation** (S7): `g scaffold user` produces `tests/test_user.nu` with test stubs for:
- `test_user_index` — GET /api/users → 200
- `test_user_show` — GET /api/users/:id → 200
- `test_user_create` — POST /api/users → 201
- `test_user_update` — PUT /api/users/:id → 200
- `test_user_delete` — DELETE /api/users/:id → 204

Files: `bin/nurlweb-kit`, `templates/scaffold/`, `templates/controller/`, `templates/service/`, `templates/model/`

### T7 (P2): `app_mount` for Sub-App Middleware Isolation (~40 LOC)

Current `routegroup.nu` shares the parent App's middleware pipeline. `app_mount` creates a sub-app with its own middleware stack but shares the parent's Router.

```nurl
@ app_mount App parent s prefix → App
```

Useful for API versioning where v1 has different auth middleware than v2.

Files: `app_mount.nu`, `test_app_mount.nu`

### T8 (P2): Template Convention (~15 LOC)

Define `templates/` as the standard template directory. Add auto-resolve:

```nurl
@ template_auto s name ( Vec TemplateVar ) vars → !String IoErr
```

Resolves `name` to `templates/{name}.html`. Works with existing `template.nu` render engine.

Files: `template_convention.nu`

### T9 (P3): `schedule.nu` — Periodic Tasks (~60 LOC, DEFERRED)

Timer-based task execution using NURL async fibers. Deferred until fiber scheduler is production-ready (Phase 3: M:N work-stealing).

API when implemented:
```nurl
@ schedule_every i seconds fn_ref → v
@ schedule_start_all → v
@ schedule_stop_all → v
```

With 60s default timeout and 8 concurrent fiber cap.

Files: `schedule.nu`, `test_schedule.nu`

## Error & Rescue Registry

| CODEPATH | FAILURE | RESCUED? | USER SEES |
|---|---|---|---|
| Config loading | Env file missing | Y → fallback to default | Silent |
| Config loading | Wrong type value | Y → config_expect validation | Compile error or startup crash |
| Config loading | Key missing | Y → config_expect | Startup crash with clear message |
| Plugin start | Plugin panic | Y → optional/required flag | Error logged, optional plugins skip |
| Schedule task | Task hangs | Y (when implemented) → 60s timeout | Warning logged, task cancelled |
| Schedule task | Task fails | Y (when implemented) → error logged | Task stops, others continue |
| Controller wiring | No matching route | Y → 404 | "Not found" |
| Service call | DB error | Y → Result type | Error response |
| Config secrets | Committed to git | Y → .gitignore in CLI | Protected by default |
| Lifecycle before_start | Hook fails | Y → hard stop | Server doesn't start, error message |
| Lifecycle after_start | Hook fails | Y → log warning | Server continues |
| CLI scaffold | Generated code invalid | N → must be prevented | Test every scaffold template |

**1 remaining gap:** CLI scaffold must produce valid code — covered by testing all templates.

## Architecture Decisions

| # | Issue | Decision | Rationale |
|---|-------|----------|-----------|
| 1 | Layer separation | nurlweb-kit is separate from nurlweb | User explicitly requested: build on top, not inside |
| 2 | Plugin registry | No registry, convention only | Import + call `plugin_start(App)` directly. More NURL-idiomatic |
| 3 | Service DI | No DI container | Pure functions with explicit params. Type-safe, no stringly-typed lookup |
| 4 | Controller auto-wiring | CLI generator only | NURL has no module introspection at runtime |
| 5 | Config merge timing | Startup-time, not compile-time | Both configs compile in, merge happens at app startup |
| 6 | config_env source | `NURL_ENV` env var, default `"dev"` | Framework-specific, fails safe |
| 7 | Logger strategy | Single merged module | No logger.nu vs logger_v2.nu confusion |
| 8 | LogField type | Separate from TemplateVar | Avoids template coupling |
| 9 | Schedule.nu priority | P3, deferred | Async fiber scheduler needs maturity |
| 10 | CLI generator priority | P1 | In compiled-native, the CLI IS the framework |
| 11 | app_resources | Include with only/except filters | Highest DX function — one line = 5 RESTful routes |
| 12 | Convention validation | `nurlweb-kit check` command | Catch mistakes at dev time, not compile time |

## NOT in Scope

- RBAC / role-based access control (v3)
- Database migration system (v3)
- OpenAPI / Swagger generation (v3)
- HTTP/2 support (stdlib-blocked)
- Redis session store (no Redis client in stdlib)
- Cluster agent / multi-process (not needed — fiber scheduler)
- Hot reload dev server with HMR (impossible in compiled-native)
- Changes to nurlweb itself (kit is a separate layer)

## Implementation Order

1. **CLI foundation** — `nurlweb-kit new` with convention directory structure (S9)
2. **`config.nu`** — foundation everything depends on
3. **`lifecycle.nu`** — hooks used by plugins and startup
4. **`controller.nu` + `app_resources`** — the highest-value module
5. **`service.nu`** — productivity layer (thin)
6. **`logger.nu`** — merged structured logging
7. **CLI generators** — scaffold, controller, service, model (auto-wiring, S3/S7)
8. **`nurlweb-kit check`** — convention validation (S5)
9. **`app_mount.nu`** — sub-app middleware isolation
10. **Template convention** — auto-resolve
11. **`nurlweb-kit dev`** — dev server with auto-rebuild (S8)
12. **`schedule.nu`** — periodic tasks (P3, deferred)

## Verification

- All 20 existing nurlweb tests continue to pass (kit doesn't touch nurlweb)
- `nurlweb-kit new blog && cd blog && sh build.sh && ./app` → running server
- `nurlweb-kit g scaffold post title:s body:s` → working CRUD with 5 routes
- `app_resources app /api/users user` → 5 RESTful routes wired
- `app_resources app /api/admin admin only: [index, show]` → 2 routes only
- Config merging verified: `_default.nu` + `_prod.nu` → merged
- `config_expect` on missing key → startup crash with clear message
- Lifecycle `before_start` failure → server doesn't start
- Lifecycle `after_start` failure → warning logged, server continues
- `nurlweb-kit check` detects: missing config, missing .gitignore entry, bad controller exports
- `nurlweb-kit dev` auto-rebuilds on `.nu` file change
- Test stubs generated for all scaffolded CRUD operations
- Single logger module with both request logging and general-purpose logging

## Scope Expansion Summary

12 proposals accepted in SCOPE EXPANSION mode:

| # | Proposal | Priority | LOC Est. | Status |
|---|----------|----------|----------|--------|
| S1 | app_resources with RESTful route generation | P1 | ~30 | Accepted |
| S2 | Merge logger_v2 into single logger.nu | P1 | ~100 | Accepted |
| S3 | CLI generators to P1 with auto-wiring | P1 | ~300 | Accepted |
| S4 | Drop plugin.nu registry | P1 | saves ~40 | Accepted |
| S5 | nurlweb-kit check convention validation | P2 | ~60 | Accepted |
| S6 | Downgrade schedule.nu to P3 | P3 | — | Accepted |
| S7 | Test generation in CLI scaffold | P1 | incl. in S3 | Accepted |
| S8 | nurlweb-kit dev command | P2 | ~80 | Accepted |
| S9 | Convention directory structure | P1 | incl. in S3 | Accepted |
| S10 | app_resources only/except filters | P1 | ~15 | Accepted |
| S11 | app_mount sub-app middleware isolation | P2 | ~40 | Accepted |
| S12 | Template convention with auto-resolve | P2 | ~15 | Accepted |

**Total new code: ~640 LOC** across 8 runtime modules + CLI + templates.


## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | CLEAR | 12 proposals, 12 accepted, 0 deferred |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 13 issues, 1 critical gap resolved |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | — |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**UNRESOLVED:** 0
**VERDICT:** CEO + ENG CLEARED — ready to implement.
