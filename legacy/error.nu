// nurlweb/error.nu — Structured AppError + Error Middleware
//
// Typed errors with HTTP status codes. Catch them in middleware with
// the sentinel-header pattern (X-NurlWeb-Error) and render consistent
// JSON/text/HTML responses.
//
// API:
//   error_not_found(s code, s msg)        → HttpResponse (404 + sentinel)
//   error_validation(s code, s msg)       → HttpResponse (422 + sentinel)
//   error_unauthorized(s code, s msg)     → HttpResponse (401 + sentinel)
//   error_forbidden(s code, s msg)        → HttpResponse (403 + sentinel)
//   error_conflict(s code, s msg)         → HttpResponse (409 + sentinel)
//   error_internal(s code, s msg)         → HttpResponse (500 + sentinel)
//   app_catch(App a, renderer)            → v  (middleware)
//
// Renderer signature: ( @ HttpResponse AppError ) — receives the
// original error response + derived AppError, returns a rendered one.
//
// Usage:
//   ( app_catch app
//       \ HttpResponse orig AppError ae → HttpResponse {
//           ^ ( response_text . ae status
//               ( nurl_str_cat3 `{"error":"` . ae code `"}\n` ) )
//       })

$ `nurlweb/app.nu`
$ `nurlweb/respond.nu`
$ `stdlib/ext/http_full.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`

// ── AppError struct ───────────────────────────────────────────────────

: AppError {
    i status
    s code
    s message
}

// ── Error constructors (return HttpResponse with sentinel header) ─────

// All error_* functions return an HttpResponse with the appropriate
// HTTP status, the message as body, and X-NurlWeb-Error: <code> header.
// app_catch middleware detects this header and rewrites the response.

@ __error_response i status s code s msg → HttpResponse {
    : HttpResponse r ( response_text status msg )
    ( response_set_header r `X-NurlWeb-Error` code )
    ^ r
}

@ error_not_found s code s msg → HttpResponse {
    ^ ( __error_response 404 code msg )
}

@ error_validation s code s msg → HttpResponse {
    ^ ( __error_response 422 code msg )
}

@ error_unauthorized s code s msg → HttpResponse {
    ^ ( __error_response 401 code msg )
}

@ error_forbidden s code s msg → HttpResponse {
    ^ ( __error_response 403 code msg )
}

@ error_conflict s code s msg → HttpResponse {
    ^ ( __error_response 409 code msg )
}

@ error_internal s code s msg → HttpResponse {
    ^ ( __error_response 500 code msg )
}

// ── app_catch middleware ──────────────────────────────────────────────

// Wraps the composed handler pipeline. After the inner handler runs,
// inspects the response for X-NurlWeb-Error sentinel. If found,
// constructs an AppError and delegates to the renderer for a clean
// error response. Otherwise passes the response through unchanged.
//
// Must be registered LAST (outermost) to catch errors from all other
// middleware and route handlers.
@ app_catch App a ( @ HttpResponse AppError ) renderer → v {
    ( app_use a
        \ ( @ HttpResponse HttpRequest ) inner → ( @ HttpResponse HttpRequest ) {
            ^ \ HttpRequest req → HttpResponse {
                : HttpResponse resp ( inner req )
                : ?String err_code ( header_get . resp headers `X-NurlWeb-Error` )
                ?? err_code {
                    T code → {
                        // Extract body text for AppError message
                        : i body_len ( vec_len [u] . resp body )
                        ? > body_len 0 {
                            : String tmp ( string_from_bytes
                                ( vec_data [u] . resp body ) body_len )
                            : s body_text ( string_data tmp )
                            : AppError ae @ AppError { . resp status code body_text }
                            : HttpResponse rendered ( renderer resp ae )
                            ( string_free tmp )
                            ( http_response_free resp )
                            ^ rendered
                        } {
                            : AppError ae @ AppError { . resp status code `` }
                            : HttpResponse rendered ( renderer resp ae )
                            ( http_response_free resp )
                            ^ rendered
                        }
                    }
                    F → { ^ resp }
                }
            }
        })
}

// ── Default JSON error renderer ───────────────────────────────────────

// Convenience: renders AppError as {"error":{"code":"...","message":"..."}}
// with the correct HTTP status and Content-Type: application/json.
@ error_render_json HttpResponse orig AppError ae → HttpResponse {
    : s json_body ( nurl_str_cat3
        `{"error":{"code":"` . ae code `","message":"` )
    : s json_body2 ( nurl_str_cat json_body . ae message )
    : s json_body3 ( nurl_str_cat json_body2 `"}}\n` )
    : HttpResponse r ( response_text . ae status json_body3 )
    ( response_set_header r `Content-Type` `application/json; charset=utf-8` )
    ^ r
}
