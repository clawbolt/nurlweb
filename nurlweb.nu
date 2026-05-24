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
