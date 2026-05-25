# Changelog

## [0.3.0.0] - 2026-05-25

### Added
- `cors.nu` — permissive CORS middleware wrapper (app_with_cors)
- `session.nu` SessionStore — in-memory server-side session storage (get/set/del, MemorySessionStore default)
- `template.nu` Layout — `template_render_layout` with `{{% content %}}` marker
- `template.nu` Include — `{{> path }}` directive for template composition
- `bin/nurlweb` — CLI project scaffolding (`nurlweb new my-app`)
- `templates/app.nu.tmpl` — project template with routes + middleware stubs
- `templates/hello.nu.tmpl` — minimal hello-world project template
- E2E CRUD test cycle for `examples/rest_api.nu` in `test_e2e.sh`

### Changed
- `session.nu`: extended with SessionStore struct + session_store_* API
- `template.nu`: added __scan_to_close, __resolve_includes, template_render_layout
- `template_render`: now resolves `{{> path }}` includes before var substitution
- `nurlweb.nu`: updated module import comments for v1.2
- `test_session.nu`: added 5 SessionStore compile-time tests
- `test_template.nu`: added layout, include, edge case, and unmatched var tests
- `test_e2e.sh`: hardcoded nurlc/runtime paths for standalone nurlweb repo

### Fixed
- CEO F2: template single-brace `{{` edge case — scanner now emits literal `{{` when `}}` not found
- CEO F1: upload.nu Content-Length bypass — nurl_str_to_int returns 0 for non-numeric input, fallback check verified against stdlib multipart

## [0.2.0.0] - 2026-05-25

### Added
- `ctx_param_i` — integer param extraction (nurlc ?i bug fixed, unblocks Phase B)
- `app_with_dos` — app-level DoS protection via `server_new_with_dos` (stdlib)
- `session.nu` — cookie-based session management (get/set/del, production defaults)
- `upload.nu` — multipart file upload wrapper (upload_parts, upload_free)
- `template.nu` — minimal `{{key}}` string template rendering (Vec<TemplateVar>)
- `examples/rest_api.nu` — full REST API demo with ctx_param_i

### Changed
- `App` struct: added `dos_max_conns` / `dos_max_per_ip` fields
- `__serve_bind`: uses `server_new_with_dos` when dos limits are configured
- `nurlweb.nu`: added commented v1.2 module imports

## [0.1.0.0] - 2026-05-24

### Added
- Initial release: NurlWeb v1 — LLM-first web framework for NURL
- `app.nu` (~150 LOC) — micro layer: routes, middleware pipeline, blocking + async serve
- `ctx.nu` (~130 LOC) — rich layer: unified Ctx with param/query/header/body extraction, response shortcuts
- `nurlweb.nu` — single-import aggregator
- `examples/hello.nu` — minimal smoke test (verified E2E)
- Unit test suites: `test_basic.nu` (app.nu), `test_ctx.nu` (ctx.nu)
- `test_e2e.sh` — curl-based E2E smoke tests
- `FRAMEWORK.md` — full API reference with patterns
- `README.md` — quick start and build instructions

### Changed
- `app_serve` and `app_serve_async` share `__serve_bind` helper (DRY)
- `ctx_body_json` delegates to `ctx_body_raw` (DRY)

### Fixed
- Import path mismatch: README clone path aligned with `nurlweb.nu` internal imports
- `test_e2e.sh` trap references `PID` before assignment — now initialized
