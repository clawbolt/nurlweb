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
}

// ── Lifecycle ─────────────────────────────────────────────────────────

@ app_new s host i port → App {
    : Router r ( router_new )
    // Default handler: dispatch through the router. Captures `r` by
    // value in the closure — router_handle takes Router + HttpRequest,
    // returns HttpResponse, matching the server's handler contract.
    : ( @ HttpResponse HttpRequest ) h
        \ HttpRequest req → HttpResponse { ^ ( router_handle r req ) }
    ^ @ App { r h host port 0 }
}

@ app_with_workers App a i n → App {
    = . a worker_count n
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

// Blocking server: tcp_listen → server_new → server_run.
// Installs SIGINT/SIGTERM graceful shutdown. Returns on clean stop.
@ app_serve App a → !v NetErr {
    : ! TcpListener NetErr lr ( tcp_listen . a host . a port )
    ?? lr {
        T listener → {
            : HttpServer srv ( server_new listener . a handler )
            ( signal_install_shutdown listener )
            : !v NetErr rr ( server_run srv )
            ( server_stop srv )
            ^ rr
        }
        F e → { ^ @ !v NetErr { F e } }
    }
}

// Async (fiber-based) server: uses the single-thread fiber scheduler
// (shipped Phase 1+2). M:N work-stealing (Phase 3) is a free upgrade
// when it lands — no API change needed.
@ app_serve_async App a → !v NetErr {
    ( runtime_init . a worker_count )

    : ! TcpListener NetErr lr ( tcp_listen . a host . a port )
    ?? lr {
        T listener → {
            : HttpServer srv ( server_new listener . a handler )
            ( signal_install_shutdown listener )
            : !v NetErr rr ( server_run_async srv )
            ?? rr {
                T _ → {
                    ( server_stop srv )
                    ( runtime_shutdown )
                    ^ @ !v NetErr { T 0 }
                }
                F e → {
                    ( server_stop srv )
                    ( runtime_shutdown )
                    ^ @ !v NetErr { F e }
                }
            }
        }
        F e → { ^ @ !v NetErr { F e } }
    }
}
