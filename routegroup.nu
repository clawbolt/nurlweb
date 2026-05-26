// nurlweb/routegroup.nu — Route Grouping
// Stability: stable
//
// Prefix-based route grouping on a shared Router. RouteGroup holds a
// reference to the parent App's Router + a prefix string — no second
// Router, no duplicate handler pipeline. Middleware stays centrally managed.
//
// API:
//   ( app_group   App a s prefix ) → RouteGroup
//   ( group_get    RouteGroup g s route handler ) → v
//   ( group_post   RouteGroup g s route handler ) → v
//   ( group_put    RouteGroup g s route handler ) → v
//   ( group_patch  RouteGroup g s route handler ) → v
//   ( group_delete RouteGroup g s route handler ) → v
//   ( group_any    RouteGroup g s method s route handler ) → v
//
// Usage:
//   : RouteGroup api ( app_group app `/api/v1` )
//   ( group_get api `/users`
//       \ HttpRequest req Params params → HttpResponse { ... })
//   ( group_post api `/users`
//       \ HttpRequest req Params params → HttpResponse { ... })

$ `nurlweb/app.nu`
$ `stdlib/core/string.nu`

// ── RouteGroup — Router ref + prefix ─────────────────────────────────

: RouteGroup {
    Router router
    s prefix
}

@ app_group App a s prefix → RouteGroup {
    ^ @ RouteGroup { . a router prefix }
}

// ── Group route registration ─────────────────────────────────────────
//
// Each group_* function prepends the prefix to the route pattern,
// then delegates to the shared Router's route function.

@ group_get RouteGroup g s route ( @ HttpResponse HttpRequest Params ) handler → v {
    : s full ( nurl_str_cat . g prefix route )
    ( router_get . g router full handler )
}

@ group_post RouteGroup g s route ( @ HttpResponse HttpRequest Params ) handler → v {
    : s full ( nurl_str_cat . g prefix route )
    ( router_post . g router full handler )
}

@ group_put RouteGroup g s route ( @ HttpResponse HttpRequest Params ) handler → v {
    : s full ( nurl_str_cat . g prefix route )
    ( router_put . g router full handler )
}

@ group_patch RouteGroup g s route ( @ HttpResponse HttpRequest Params ) handler → v {
    : s full ( nurl_str_cat . g prefix route )
    ( router_patch . g router full handler )
}

@ group_delete RouteGroup g s route ( @ HttpResponse HttpRequest Params ) handler → v {
    : s full ( nurl_str_cat . g prefix route )
    ( router_delete . g router full handler )
}

@ group_any RouteGroup g s method s route ( @ HttpResponse HttpRequest Params ) handler → v {
    : s full ( nurl_str_cat . g prefix route )
    ( router_any . g router method full handler )
}
