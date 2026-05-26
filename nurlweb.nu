// nurlweb/nurlweb.nu — Single-import aggregator (slim core)
// Stability: stable
//
// Clone nurlweb into your project as `nurlweb/`:
//   git clone https://github.com/clawbolt/nurlweb nurlweb
//
// Then import:
//   $ `nurlweb/nurlweb.nu`    → core framework (App + Respond + RouteGroup)
//   $ `nurlweb/app.nu`        → micro-framework only (App)
//
// Higher-level conventions live in the companion nurlweb-kit repository:
//   $ `nurlweb-kit/context/ctx.nu`          → rich request context
//   $ `nurlweb-kit/middleware/session.nu`  → cookie + server-side sessions
//   $ `nurlweb-kit/orm/orm.nu`             → SQLite ORM
//   $ `nurlweb-kit/view/template.nu`       → {{key}} template engine
//   $ `nurlweb-kit/middleware/auth.nu`     → basic + bearer auth
//   $ `nurlweb-kit/middleware/cors.nu`     → CORS middleware
//   $ `nurlweb-kit/validation/validate.nu` → JSON schema validation

$ `nurlweb/app.nu`
$ `nurlweb/respond.nu`
$ `nurlweb/routegroup.nu`
