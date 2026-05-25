// nurlweb/nurlweb.nu — Single-import aggregator (v3.0 slim core)
// Stability: stable
//
// Clone nurlweb into your project as `nurlweb/`:
//   git clone https://github.com/clawbolt/nurlweb nurlweb
//
// Then import:
//   $ `nurlweb/nurlweb.nu`    → core framework (App + Respond + RouteGroup)
//   $ `nurlweb/app.nu`        → micro-framework only (App)
//
// Legacy modules moved to nurlweb/legacy/ (still accessible via shims):
//   $ `nurlweb/legacy/ctx.nu`       → rich request context
//   $ `nurlweb/legacy/session.nu`   → cookie + server-side sessions
//   $ `nurlweb/legacy/orm.nu`       → SQLite ORM
//   $ `nurlweb/legacy/template.nu`  → {{key}} template engine
//   $ `nurlweb/legacy/auth.nu`      → basic + bearer auth
//   $ `nurlweb/legacy/auth_jwt.nu`  → JWT authentication
//   $ `nurlweb/legacy/upload.nu`    → multipart file upload
//   $ `nurlweb/legacy/validate.nu`  → JSON schema validation
//   $ `nurlweb/legacy/ws.nu`        → WebSocket server
//   $ `nurlweb/legacy/cors.nu`      → CORS middleware
//   $ `nurlweb/legacy/csrf.nu`      → CSRF protection
//   $ `nurlweb/legacy/compress.nu`  → gzip compression
//   $ `nurlweb/legacy/error.nu`     → error recovery middleware
//   $ `nurlweb/legacy/logger.nu`    → request logging
//   $ `nurlweb/legacy/static.nu`    → static file serving
//   $ `nurlweb/legacy/timeout.nu`   → request timeout
//   (existing imports via original paths still work via shims)

$ `nurlweb/app.nu`
$ `nurlweb/respond.nu`
$ `nurlweb/routegroup.nu`
