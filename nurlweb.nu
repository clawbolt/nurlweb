// nurlweb/nurlweb.nu — Single-import aggregator
//
// Clone nurlweb into your project as `nurlweb/`:
//   git clone https://github.com/clawbolt/nurlweb nurlweb
//
// Then import in your .nu file:
//   $ `nurlweb/nurlweb.nu`    → full framework (App + Ctx)
//   $ `nurlweb/app.nu`        → micro-framework only
//
// ctx.nu transitively includes app.nu — single $ line pulls everything.

$ `nurlweb/ctx.nu`

// ── v1.1 opt-in modules (uncomment to use) ────────────────────────────
//
// $ `nurlweb/validate.nu`   // JSON schema validation (validate_json)
// $ `nurlweb/error.nu`      // structured AppError + error middleware
// $ `nurlweb/respond.nu`    // standalone response shortcuts (no Ctx)
// $ `nurlweb/auth.nu`       // auth helpers Ctx-style (basic/bearer)
// $ `nurlweb/static.nu`     // static file serving (serve_static)
// $ `nurlweb/ws.nu`         // WebSocket integration (separate port)

// ── v1.2 production modules (uncomment to use) ────────────────────────
//
// $ `nurlweb/session.nu`    // cookie-based session management
// $ `nurlweb/upload.nu`     // multipart file upload (upload_parts)
// $ `nurlweb/template.nu`   // {{key}} string template rendering
