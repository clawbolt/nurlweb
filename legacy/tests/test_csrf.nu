// nurlweb/test_csrf.nu — Compile test for csrf.nu
$ `nurlweb/csrf.nu`

@ test_csrf_token → s {
    ^ ( csrf_token `my-secret-key` )
}

@ test_csrf_protect → ( @ HttpResponse HttpRequest ) {
    ^ ( csrf_protect
        \ HttpRequest req → HttpResponse {
            ^ ( response_text 200 `ok\n` )
        })
}

@ main → i { ^ 0 }
