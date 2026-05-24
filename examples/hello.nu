// examples/hello.nu — Minimal NurlWeb smoke test
//
// Demonstrates: app_new, app_get, app_serve
//
// Build & run (from nurl repo root):
//   ./nurl.sh nurlweb/examples/hello.nu

$ `nurlweb/app.nu`
$ `stdlib/ext/http_full.nu`

@ main → i {
    : App app ( app_new `127.0.0.1` 3909 )

    // Handlers must be closure-wrapped — bare @-fn names don't auto-coerce
    ( app_get app `/`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `nurlweb works!\n` )
        })
    ( app_get app `/health`
        \ HttpRequest req Params params → HttpResponse {
            ^ ( response_text 200 `{"ok":true}\n` )
        })

    ( nurl_print `nurlweb hello server on http://127.0.0.1:3909/\n` )

    : !v NetErr rr ( app_serve app )
    ?? rr {
        T _ → { ^ 0 }
        F _ → { ^ 1 }
    }
}
