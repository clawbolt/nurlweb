// nurlweb/logger.nu — Structured JSON Logging Middleware
//
// Wraps the handler pipeline with structured JSON request logging.
// Uses the same closure shape as http_middleware.nu — composes via app_use.
// Register LAST (outermost) after all other middleware so it sees the
// final response including any transformations (CORS headers, error
// rewrites). Same ordering pattern as app_catch in error.nu.
//
// API:
//   ( app_with_logger App a ) → v
//   ( ctx_request_id   Ctx c ) → ?String
//
// Usage:
//   ( app_with_logger app )          // register logger middleware
//   : ?String rid ( ctx_request_id ctx )  // get request ID in handler

$ `nurlweb/app.nu`
$ `nurlweb/ctx.nu`
$ `stdlib/ext/http_full.nu`
$ `stdlib/core/string.nu`

// ── ctx_request_id — extract X-Request-Id from incoming request ─────

@ ctx_request_id Ctx c → ?String {
    ^ ( header_get . c req `X-Request-Id` )
}

// ── __log_json — emit structured log line ────────────────────────────
//
// Logs method, path, status, bytes as a single-line JSON object via
// nurl_print (writes to stdout). No timestamp — blocked on stdlib time
// module. No UUID generation — only echoes incoming X-Request-Id.

@ __log_json s method s path i status i bytes ?String req_id → v {
    ( nurl_print_str `{"method":"` )
    ( nurl_print_str method )
    ( nurl_print_str `","path":"` )
    ( nurl_print_str path )
    ( nurl_print_str `","status":` )
    ( nurl_print_int status )
    ( nurl_print_str `,"bytes":` )
    ( nurl_print_int bytes )
    ?? req_id {
        T rid → {
            ( nurl_print_str `,"request_id":"` )
            ( nurl_print_str ( string_data rid ) )
            ( nurl_print_str `"` )
        }
        F → {}
    }
    ( nurl_print_str `}\n` )
}

// ── app_with_logger — structured logging middleware ──────────────────
//
// Wraps the handler pipeline with per-request JSON logging.
// Logs after the handler runs so it captures the actual response status
// and body size. Error responses from error.nu or route handlers are
// logged with their error status code.

@ app_with_logger App a → v {
    ( app_use a
        \ ( @ HttpResponse HttpRequest ) inner → ( @ HttpResponse HttpRequest ) {
            ^ \ HttpRequest req → HttpResponse {
                : HttpResponse resp ( inner req )
                // Extract method and path for the log line
                : s method ( string_data . req method )
                : s path ( string_data . req path )
                : i status . resp status
                : i body_len ( vec_len [u] . resp body )
                : ?String rid ( header_get . resp headers `X-Request-Id` )
                ( __log_json method path status body_len rid )
                ^ resp
            }
        })
}
