# Plan: NurlWeb Architecture Fixes + v1.3 Features

**Status:** Draft
**Deepened:** 2026-05-25  
**Type:** enhancement + bugfix  
**Source:** [Architecture Reflection 2026-05-25](../architecture-reflection-2026-05-25.md)  
**Scope:** 3 critical fixes + 3 strategic features  
**Target version:** v1.2.1 (fixes) → v1.3 (features)

---

## Problem Frame

The architecture audit surfaced systematic gaps across six dimensions: response helper duplication causing Content-Type inconsistencies, XSS-unsafe template rendering with no escape path, query-string extraction that's a misleading alias for header lookup, no route grouping (the most-requested routing feature), missing body parsers beyond JSON, and zero structured observability. These are additive — nothing needs to be torn down. But each gap independently blocks production readiness.

## Scope Boundary

**In scope:** The six items listed below, plus any test files and documentation updates they require. The refactored `static_dir` argument-swap bug is a freebie included in Fix 3.

**Example refresh:** `examples/rest_api.nu` currently builds JSON responses manually via `string_push_str` chains. After FT2 (body parsers), the example should demonstrate `ctx_body_form` and `ctx_body_urlencoded` patterns. This is a documentation refresh, not new implementation — included as a drive-by in Phase 2.

**Out of scope:** SessionStore Redis backend (stdlib-blocked), response compression (stdlib-blocked), response streaming (stdlib-blocked), CSRF middleware, ETag/caching infrastructure, hot reload, behavioral test framework. These are deferred to v2 or blocked on upstream NURL stdlib changes.

---

## Requirements Traceability

| # | Origin | Type | Requirement |
|---|--------|------|-------------|
| F1 | §2 Duplication 1 | Fix | `ctx.nu` response helpers delegate to `respond.nu` — zero duplicated `response_set_header` calls |
| F2 | §7 Gap 7, §8 Weakest | Fix | `template.nu` offers HTML-escaped rendering path with `<>&"'` escaping |
| F3 | §7 Gap 4 | Fix | `ctx_query` does URL percent-decoding; `ctx_query_all` supports multi-value params where stdlib permits |
| FT1 | §7 Gap 3 | Feature | `app_group` / `routegroup.nu` provides prefix-based route grouping on shared `Router` |
| FT2 | §7 Gaps 2,3 | Feature | `ctx_body_form`, `ctx_body_urlencoded`, `ctx_body_text` in `ctx.nu` |
| FT3 | §7 Gap 12, §8 | Feature | `logger.nu` with `app_with_logger` and `ctx_request_id` for structured JSON observability |

---

## Design Decisions

### Decision 1: `respond.nu` is canonical; `ctx.nu` delegates

**Rationale:** `respond.nu` functions are the minimal unit — they take only what they need (`i status s body`). `ctx.nu` functions add the Ctx-first API surface on top. Having ctx delegate eliminates the bug where `ctx_json` sets `application/json` (no charset) but `respond_json` sets `application/json; charset=utf-8`. After unification, charset=utf-8 is the canonical form everywhere.

**Ripple effect:** `error_render_json` in `error.nu` currently manually calls `response_set_header` to set Content-Type — the same pattern that unification eliminates. As part of F1, `error_render_json` switches to calling `respond_json` instead, removing its own duplicated header logic.

**Tradeoff:** `ctx_text`, `ctx_json`, `ctx_html` get an extra function call hop. NURL's compiler inlines trivial functions, so this is zero-cost at runtime.

### Decision 2: New `template_render_html` function; existing `template_render` unchanged

**Rationale:** The current module explicitly warns "do NOT use for HTML." Adding a separate function preserves backward compatibility (existing plain-text users are unaffected) while providing a safe path for HTML. We do NOT add an `html_escape` flag to `TemplateVar` — that would make the escape decision per-variable, which is confusing (some vars escaped, some not, in the same template). The entire render is either escaped or it isn't.

**Escape set:** `<` → `&lt;`, `>` → `&gt;`, `&` → `&amp;`, `"` → `&quot;`, `'` → `&#39;`. This covers all XSS injection vectors in HTML body, attribute (double-quoted), and attribute (single-quoted) contexts.

**Tradeoff:** We add a 5-character escape table and a ~15-line internal function. The render loop is already character-by-character; escaping adds negligible overhead.

**Security note on includes:** `__resolve_includes` reads files from disk via `stdlib/std/fs.nu`. Include paths are embedded in the template string at authoring time, not user-controllable at request time. However, if the template string itself originates from user input, a database, or any untrusted source, `{{> /etc/passwd }}` could trigger arbitrary file reads. The existing depth limit (8) partially mitigates recursive include bombs but does not prevent single-level path traversal. Recommendation: document that template strings must be trusted/author-time constants, and consider path-safety validation in a future release.

### Decision 3: `ctx_query` delegates to new internal `__url_decode`; `ctx_query_all` is stdlib-permitting

**Rationale:** The stdlib stores query params as headers (flat key-value). Research confirms only `header_get` is available in the nurlweb-visible stdlib surface — no `header_get_all` or multi-value API exists. Individual values may contain `%XX` sequences. NURL provides `nurl_str_get` for character indexing and `string_push_char`/`string_push_str` for output building — sufficient for manual hex decoding without external dependencies.

**Approach:** `ctx_query` calls `__url_decode` on the raw header value before returning. The decode function walks the string character by character: when it sees `%`, it reads the next two chars, validates they are hex digits, and emits the decoded byte. Non-hex `%XX` sequences pass through as literals. `ctx_query_all` returns a single-element `?(Vec String)` wrapping the decoded value — true multi-value support is stdlib-blocked until `header_get_all` exists. A comment in the implementation documents this limitation.

### Decision 4: Route grouping via new `routegroup.nu` module that wraps `App`

**Rationale:** A `RouteGroup` struct holds a reference to the parent `App`'s `Router` plus a prefix string. Route functions (`group_get`, `group_post`, etc.) prepend the prefix to the route pattern before delegating to the parent `App`'s `router_*` functions. This avoids duplicating the App struct (no second Router, no second handler pipeline) and keeps middleware centrally managed.

**API surface:**

```nurl
@ app_group App a s prefix → RouteGroup
@ group_get    RouteGroup g s route handler → v
@ group_post   RouteGroup g s route handler → v
@ group_put    RouteGroup g s route handler → v
@ group_patch  RouteGroup g s route handler → v
@ group_delete RouteGroup g s route handler → v
@ group_any    RouteGroup g s method s route handler → v
```

Middleware and DoS configuration remain on the root App. Route groups are purely a prefixing convenience.

**Tradeoff:** 7 new functions (mirroring `app_get` through `app_any` + `app_group`), ~50 LOC. The closure-capture pattern already works (witness `static_serve_route` which does manual prefix concatenation). This just formalizes it.

### Decision 5: Body parsers live in `ctx.nu`; no new file

**Rationale:** `ctx_body_json` and `ctx_body_raw` are already in `ctx.nu`. Adding `ctx_body_form`, `ctx_body_urlencoded`, `ctx_body_text` there keeps body extraction in one place. `ctx_body_form` delegates to `request_multipart_parts` (same as `upload_parts`). `ctx_body_urlencoded` delegates to header-based extraction (same query-storing mechanism). `ctx_body_text` wraps `ctx_body_raw` with a String return type instead of raw `s`.

**API:**

```nurl
@ ctx_body_form        Ctx c → ?(Vec MultipartPart)
@ ctx_body_urlencoded  Ctx c → ?(Vec UrlEncodedPair)
@ ctx_body_text        Ctx c → String
```

**Implementation note for `ctx_body_urlencoded`:** Unlike query params (which the stdlib auto-stores as headers), URL-encoded form bodies arrive as raw bytes in `req.body`. The function must: (1) extract the raw body via the same pattern as `ctx_body_raw`, (2) split on `&` to get key=value pairs, (3) split each pair on the first `=` to get key and value, (4) URL-decode both key and value using the shared `__url_decode` helper, (5) return a `Vec<UrlEncodedPair>`. `UrlEncodedPair` is a new struct with `String key` and `String value` fields, defined in `ctx.nu`. Memory: caller must free the returned Vec and each pair's Strings — document the cleanup pattern in FRAMEWORK.md.

### Decision 6: New `logger.nu` module with structured JSON output

**Rationale:** Logging is a cross-cutting concern that should be installable as middleware. A separate module keeps it opt-in and avoids pulling logging dependencies into `app.nu`. The middleware wraps the handler, measures duration, and prints a single-line JSON object to stderr after the response.

**API:**

```nurl
@ app_with_logger App a → v
@ ctx_request_id  Ctx c → ?String
```

**Log format (timestamp omitted — stdlib-blocked):** `{"method":"GET","path":"/users/1","status":200,"duration_ms":3,"request_id":"a1b2c3d4"}`. The `duration_ms` field is computable by capturing a counter before/after the inner handler. Timestamp is omitted because research confirms no `stdlib/std/time.nu` or clock functions exist in the nurlweb-visible stdlib surface.

`ctx_request_id` reads `X-Request-Id` header. If absent, returns `None`. UUID4 generation is deferred — NURL has no `uuid` module and we don't want to inline UUID generation.

---

## Files and Modules

### Files to Modify

| File | Change | LOC impact |
|------|--------|------------|
| `respond.nu` | Add `respond_json` charset=utf-8 consistency (already has it); no functional change needed — it's already the canonical form | 0 |
| `error.nu` | `error_render_json` switches from manual `response_set_header` to delegating to `respond_json` (ripple effect of F1) | ~-3 |
| `ctx.nu` | Refactor response helpers to delegate to `respond.nu`; add `ctx_body_form`, `ctx_body_urlencoded`, `ctx_body_text`; upgrade `ctx_query` with URL-decoding; add `ctx_query_all` | ~+40 / -30 |
| `template.nu` | Add `__html_escape_char`, `__try_push_var_html`, `template_render_html`; add `template_render_layout_html` | ~+60 |
| `nurlweb.nu` | Update module import comments to reflect new modules (`routegroup.nu`, `logger.nu`) | ~+5 |
| `FRAMEWORK.md` | Document all new APIs; update LOC counts; add HTML template safety section; document query decoding | ~+80 |
| `README.md` | Update feature table with route groups, body parsers, logger | ~+15 |

### Files to Create

| File | Purpose | Est. LOC |
|------|---------|----------|
| `routegroup.nu` | RouteGroup struct + group_* functions | ~55 |
| `logger.nu` | app_with_logger middleware + ctx_request_id | ~50 |
| `test_routegroup.nu` | Compile-time tests for RouteGroup struct and all group_* functions | ~60 |
| `test_logger.nu` | Compile-time tests for logger middleware and ctx_request_id | ~40 |

### Test Files to Update

| File | Change |
|------|--------|
| `test_ctx.nu` | Add tests for ctx_body_form, ctx_body_urlencoded, ctx_body_text, ctx_query_all; verify refactored response helpers still compile |
| `test_template.nu` | Add tests for template_render_html, template_render_layout_html; verify escaping of all 5 characters |
| `test_respond.nu` | No change — respond.nu is the canonical implementation and already tested |

### Existing Patterns to Follow

- **Response delegation:** `ctx_body_json` already delegates to `ctx_body_raw` — use the same pattern for Ctx→respond delegation
- **Middleware installation:** `app_use` with progressive closure composition — `logger.nu` follows the same shape as `cors.nu`
- **Route registration:** `app_get`/`app_post` etc. delegate to `router_*` in `http_router.nu` — `group_*` functions follow identical delegation
- **Prefix concatenation:** `static_serve_route` already does `nurl_str_cat prefix '/*path'` — `routegroup.nu` generalizes this
- **Test structure:** Compile-time only, one test function per API function, `@ main → i { ^ 0 }` — all new tests follow `test_basic.nu` pattern
- **Comment style:** `// ── Section ──` dividers, function signatures in header comments — match existing
- **Internal helpers:** `__` prefix for non-exported functions — already used in `app.nu`, `session.nu`, `template.nu`

---

## Dependencies and Sequencing

```
Phase 1: Fixes (v1.2.1)
  F1: Unify respond/ctx helpers  ◄── no deps
  F2: HTML template escaping     ◄── no deps (template.nu has no framework deps)
  F3: Query-string parsing       ◄── no deps (ctx.nu internal only)
  → All three are parallelizable

Phase 2: Features (v1.3)
  FT1: Route grouping            ◄── depends on F1 being done (routegroup.nu imports ctx.nu indirectly)
  FT2: Body parsers              ◄── depends on F1 being done (adds to ctx.nu)
  FT3: Structured logging        ◄── depends on F1 being done (logger.nu imports app.nu)
  → All three depend on Phase 1 completion; parallelizable within Phase 2
```

**Blocking dependencies on NURL stdlib:**

- `ctx_query_all` multi-value behavior — blocked on no `header_get_all` in stdlib. Implement single-value only, document limitation.
- `logger.nu` timestamp field — blocked on no `stdlib/std/time.nu` or clock module. Omit timestamp from initial log format. Add when time module ships.
- `ctx_request_id` UUID generation — blocked on no stdlib UUID module. Accept only X-Request-Id header; return None when absent.

---

## Risk Inventory

### Risk 1: `respond.nu` is not auto-imported by `ctx.nu`
**Impact:** If ctx.nu delegates to respond.nu, ctx.nu must import respond.nu. Currently ctx.nu imports `app.nu` (for App transitively). Adding a `respond.nu` import is safe — respond.nu only depends on stdlib. **Mitigation:** Add `$ \`nurlweb/respond.nu\`` to ctx.nu's imports. Verify no circular dependency (respond.nu → stdlib only, ctx.nu → respond.nu → no cycle).

### Risk 2: `template_render_html` code duplication
**Impact:** The naive approach duplicates the 80-line `template_render` body with a one-line change (push escaped vs push raw). **Mitigation:** Extract the render loop into an internal function `__template_render_core` that takes a push-strategy closure. This is cleaner but adds closure-capture complexity. **Decision:** Duplicate with a clear comment. The render loop is stable — it hasn't changed since v0.1. Two copies are safer than premature abstraction in a language with evolving closure semantics. **Maintenance caveat:** If `template_render`'s main loop receives a future bug fix (e.g., `{{` scanning edge case, include resolution), the same fix must be manually applied to `template_render_html`. The two functions share Phase 1 (`__resolve_includes`) but duplicate Phase 2 (var substitution loop). If the loop changes more than once, extract into a shared `__template_render_core` with a push-strategy parameter.

### Risk 3: `routegroup.nu` `Router` field access
**Impact:** `RouteGroup` needs access to `App.router` to delegate route registration. The `Router` field in `App` is public (no access control in NURL), so `group_get` can call `( router_get . parent.router full_path handler )`. **Mitigation:** Verified — all App fields are public struct members. No accessor functions needed.

### Risk 4: Logger middleware ordering
**Impact:** If `app_with_logger` is registered before other middleware, it won't see their effects (CORS headers, error transformations). **Mitigation:** Document in FRAMEWORK.md that logger should be registered LAST (outermost) after all other middleware. Same pattern as `app_catch` in `error.nu`.

### Risk 5: `static_dir` argument-swap bug
**Impact:** During the ctx.nu refactor, we touch the same module that `static.nu` depends on. The `static_dir` bug (swapped args) is adjacent. **Mitigation:** Fix `static_dir` as a freebie in the same PR. It's a one-line fix: change `( static_serve dir ctx )` to `( static_serve ctx dir )`.

---

## Test Scenarios and Verification

### F1: Response helper unification
| Scenario | Verification |
|----------|-------------|
| `ctx_json` returns charset=utf-8 | Compile-time: function signature unchanged. Behavioral: Content-Type header is `application/json; charset=utf-8` (was `application/json` without charset) |
| All `ctx_*` status shortcuts still compile | Existing `test_ctx.nu` passes unmodified |
| `error_render_json` can use `respond_json` | Compile-time: `error_render_json` calls `respond_json` instead of manual `response_set_header` |
| No new import cycle | Compiler resolves all imports without error |

### F2: HTML template escaping
| Scenario | Verification |
|----------|-------------|
| `<script>` becomes `&lt;script&gt;` | Compile-time type check; E2E: `test_template.nu` expanded with output string comparison |
| `"onclick="` becomes `&quot;onclick=&quot;` | Same — covers double-quote attribute injection |
| `'onclick='` becomes `&#39;onclick=&#39;` | Same — covers single-quote attribute injection |
| `&amp;` stays `&amp;amp;` (no double-escaping) | Verify `&` in raw template produces `&amp;` in output, not `&amp;amp;` |
| `template_render` unchanged | Existing `test_template.nu` passes unmodified |
| Layout + HTML escape combined | `template_render_layout_html` escapes content injected into layout |

### F3: Query-string parsing
| Scenario | Verification |
|----------|-------------|
| `%20` decodes to space | Compile-time: `ctx_query` on header value `hello%20world` returns `hello world` |
| `%FF` (invalid hex) passes through | Compile-time: `ctx_query` returns raw `%FF` when hex is invalid |
| `ctx_query_all` returns option | Compile-time: function signature matches `→ ?(Vec String)` |
| Empty query returns None | Compile-time: `ctx_query` on absent header returns `F` |

### FT1: Route grouping
| Scenario | Verification |
|----------|-------------|
| `group_get g '/users'` → `GET /api/users` | Compile-time: RouteGroup struct created, group_get compiled |
| Nested group prefixes concatenate | Compile-time: `app_group app '/v1'` then `app_group v1 '/admin'` → `/v1/admin` |
| Middleware still applies to grouped routes | Compile-time: shared Router means middleware pipeline unchanged |
| Wildcard routes in groups | Compile-time: `group_get g '/*catch'` → prefix + `/*catch` |

### FT2: Body parsers
| Scenario | Verification |
|----------|-------------|
| `ctx_body_text` returns String | Compile-time: function signature `→ String` |
| `ctx_body_form` delegates to stdlib | Compile-time: imports `http_multipart.nu`, calls `request_multipart_parts` |
| `ctx_body_urlencoded` delegates to header extraction | Compile-time: similar `header_get` pattern to `ctx_query` |

### FT3: Structured logging
| Scenario | Verification |
|----------|-------------|
| `app_with_logger` compiles as middleware | Compile-time: closure shape matches `app_use` contract |
| `ctx_request_id` reads X-Request-Id | Compile-time: `header_get` on `X-Request-Id` |
| Logger middleware passes non-error responses through | Compile-time: handler wrapped by logger returns same response |

---

## High-Level Technical Design: template_render_html

The HTML escaping path mirrors `template_render` but replaces the var-substitution call:

```
template_render_html(template, vars):
  Phase 1: resolve includes (identical — includes are .tmpl files, not user input)
  Phase 2: substitute {{key}} vars
    For each {{key}} found:
      Find matching TemplateVar
      If found: push HTML-escaped value character by character
        '<' → "&lt;", '>' → "&gt;", '&' → "&amp;", '"' → "&quot;", "'" → "&#39;"
        other chars → push raw
      If not found: emit raw {{key}} (identical to current behavior)
  Return rendered String
```

The escape table is a 5-entry lookup in `__html_escape_char`:
```
Input char → output string (borrowed literal, no allocation)
'<'  → "&lt;"
'>'  → "&gt;"
'&'  → "&amp;"
'"'  → "&quot;"
'\'' → "&#39;"
```

---

## Execution Notes

- All tests are compile-time only (verify type signatures, not behavior). The NURL test infrastructure does not yet support behavioral assertions.
- E2E verification for HTML escaping and structured logging requires manual `curl` testing — document the curl commands in test file comments.
- The `static_dir` argument-swap bug is fixed as a drive-by in the same PR as F1/F3.
- All new modules follow the existing `// nurlweb/<name>.nu — <description>` header comment convention.
- Memory management: all new `String` allocations must have corresponding `string_free` calls. The HTML escape output uses `string_push_str` (already allocated) — no new allocation per escaped character.
