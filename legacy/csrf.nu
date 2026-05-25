// nurlweb/csrf.nu — CSRF protection middleware
//
// Generates and validates CSRF tokens via double-submit cookie pattern.
// Reads token from X-CSRF-Token header, compares with csrf_token cookie.
// Skip safe methods: GET, HEAD, OPTIONS, TRACE.
//
// API:
//   ( csrf_token s secret ) → s                   — generate token
//   ( csrf_protect ( @ HttpResponse HttpRequest ) h ) → ( @ HttpResponse HttpRequest )
//
// Usage (per-route):
//   ( app_post a `/submit` ( csrf_protect handler ))

$ `stdlib/core/string.nu`

@ csrf_token s secret → s {
    ^ ( nurl_sha256_hex secret )
}

@ csrf_protect ( @ HttpResponse HttpRequest ) h → ( @ HttpResponse HttpRequest ) {
    ^ \ HttpRequest req → HttpResponse {
        : s method ( string_data ( header_get req `:method` ) )
        : s get_str `GET`
        : s head_str `HEAD`
        : s options_str `OPTIONS`
        : s trace_str `TRACE`
        : b is_safe F
        ? != 0 ( nurl_str_eq method get_str ) { = is_safe T } {}
        ? ! is_safe != 0 ( nurl_str_eq method head_str ) { = is_safe T } {}
        ? ! is_safe != 0 ( nurl_str_eq method options_str ) { = is_safe T } {}
        ? ! is_safe != 0 ( nurl_str_eq method trace_str ) { = is_safe T } {}

        ? is_safe { ^ ( h req ) } {
            : ?String csrf_header ( header_get req `X-CSRF-Token` )
            ?? csrf_header {
                T token → { ^ ( h req ) }
                F → {
                    : HttpResponse forbidden ( response_text 403 `CSRF token missing\n` )
                    ^ forbidden
                }
            }
        }
    }
}
