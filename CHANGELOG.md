# Changelog

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
