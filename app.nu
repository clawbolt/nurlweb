// nurlweb/app.nu — NurlWeb micro-framework v1
//
// A ~200 LOC wiring reducer for the NURL HTTP stack. Single App struct
// that owns router, middleware pipeline, server config, and the full
// life-cycle loop. Builds on http_server.nu, http_router.nu, and
// http_middleware.nu without forking any of them.
//
// Design: LLM-first. Six function names to learn. One import. Three
// canonical examples. Handler signature unchanged from http_router.nu.
//
// API:
//   ( app_new            s host i port )                  → App
//   ( app_with_workers   App a i n )                      → App
//   ( app_with_dos       App a i max_conns i max_per_ip ) → App
//
//   ( app_get    App a s route handler )                  → v
//   ( app_post   App a s route handler )                  → v
//   ( app_put    App a s route handler )                  → v
//   ( app_patch  App a s route handler )                  → v
//   ( app_delete App a s route handler )                  → v
//   ( app_any    App a s method s route handler )         → v
//
//   ( app_use    App a middleware )                       → v
//
//   ( app_serve        App a )                            → !v NetErr
//   ( app_serve_async  App a )                            → !v NetErr
//
//   ( app_free   App a )                                  → v
//
// Middleware: same closure shape as http_middleware.nu combinators
//   middleware = ( @ ( @ HttpResponse HttpRequest ) ( @ HttpResponse HttpRequest ) )
//
// Progressive composition: each app_use wraps the existing composed
// handler with the new middleware — last registered = innermost, runs
// closest to the route handler. Zero allocation beyond closure captures.

$ `stdlib/std/net.nu`
$ `stdlib/std/signal.nu`
$ `stdlib/std/async.nu`
$ `stdlib/ext/http_router.nu`
$ `stdlib/ext/http_server.nu`

// ── App struct ────────────────────────────────────────────────────────

: App {
    Router router
    ( @ HttpResponse HttpRequest ) handler
    s host
    i port
    i worker_count
    i dos_max_conns
    i dos_max_per_ip
}

// ── Lifecycle ─────────────────────────────────────────────────────────

@ app_new s host i port → App {
    : Router r ( router_new )
    // Default handler: dispatch through the router. Captures `r` by
    // value in the closure — router_handle takes Router + HttpRequest,
    // returns HttpResponse, matching the server's handler contract.
    : ( @ HttpResponse HttpRequest ) h
        \ HttpRequest req → HttpResponse { ^ ( router_handle r req ) }
    ^ @ App { r h host port 0 0 0 }
}

@ app_with_workers App a i n → App {
    = . a worker_count n
    ^ a
}

// app_with_dos — Enables per-IP DoS protection at the server accept
// layer. Accepts individual fields (not the full stdlib DosLimits
// struct) to avoid silently dropping fields added in future stdlib
// versions. Set max_conns = 0 to disable (default).
@ app_with_dos App a i max_conns i max_per_ip → App {
    = . a dos_max_conns max_conns
    = . a dos_max_per_ip max_per_ip
    ^ a
}

@ app_free App a → v {
    // router_free frees all route data and handler closures.
    // The composed handler closure is freed when App goes out of scope
    // (or when the caller explicitly calls app_free).
    ( router_free . a router )
}

// ── Route registration ────────────────────────────────────────────────

@ app_get App a s route ( @ HttpResponse HttpRequest Params ) handler → v {
    ( router_get . a router route handler )
}

@ app_post App a s route ( @ HttpResponse HttpRequest Params ) handler → v {
    ( router_post . a router route handler )
}

@ app_put App a s route ( @ HttpResponse HttpRequest Params ) handler → v {
    ( router_put . a router route handler )
}

@ app_patch App a s route ( @ HttpResponse HttpRequest Params ) handler → v {
    ( router_patch . a router route handler )
}

@ app_delete App a s route ( @ HttpResponse HttpRequest Params ) handler → v {
    ( router_delete . a router route handler )
}

@ app_any App a s method s route ( @ HttpResponse HttpRequest Params ) handler → v {
    ( router_any . a router method route handler )
}

// ── Middleware pipeline ────────────────────────────────────────────────

// Progressive composition: wraps the current composed handler with the
// new middleware. Last registered = innermost (closest to route handler).
// Same closure shape as http_middleware.nu's with_* combinators.
@ app_use App a ( @ ( @ HttpResponse HttpRequest ) ( @ HttpResponse HttpRequest ) ) middleware → v {
    : ( @ HttpResponse HttpRequest ) old_handler . a handler
    : ( @ HttpResponse HttpRequest ) new_handler ( middleware old_handler )
    = . a handler new_handler
}

// ── Serve ─────────────────────────────────────────────────────────────

// Shared bind: tcp_listen → server_new → signal_install → runner.
// Takes a `runner` closure that receives the bound server and returns
// !v NetErr; app_close unconditionally after the runner finishes.
// When dos_max_conns > 0, uses server_new_with_dos for per-IP DoS
// protection (constructs DosLimits internally — no leaky struct pass-through).
@ __serve_bind App a ( @ !v NetErr HttpServer ) runner → !v NetErr {
    : ! TcpListener NetErr lr ( tcp_listen . a host . a port )
    ?? lr {
        T listener → {
            : i dc . a dos_max_conns
            : HttpServer srv
            ? > dc 0 {
                : DosLimits dl ( dos_default_limits )
                = . dl max_concurrent_conns dc
                = . dl max_conns_per_ip . a dos_max_per_ip
                = srv ( server_new_with_dos listener . a handler dl )
            } {
                = srv ( server_new listener . a handler )
            }
            ( signal_install_shutdown listener )
            : !v NetErr rr ( runner srv )
            ( server_stop srv )
            ^ rr
        }
        F e → { ^ @ !v NetErr { F e } }
    }
}

// Blocking server: __serve_bind + server_run.
// Installs SIGINT/SIGTERM graceful shutdown. Returns on clean stop.
@ app_serve App a → !v NetErr {
    ^ ( __serve_bind a
        \ HttpServer srv → !v NetErr { ^ ( server_run srv ) } )
}

// Async (fiber-based) server: uses the single-thread fiber scheduler
// (shipped Phase 1+2). M:N work-stealing (Phase 3) is a free upgrade
// when it lands — no API change needed.
@ app_serve_async App a → !v NetErr {
    ( runtime_init . a worker_count )
    : !v NetErr rr ( __serve_bind a
        \ HttpServer srv → !v NetErr { ^ ( server_run_async srv ) } )
    ( runtime_shutdown )
    ^ rr
}
