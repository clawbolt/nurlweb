// nurlweb/test_timeout.nu — Compile test for timeout.nu
$ `nurlweb/timeout.nu`

@ test_timeout → ( @ HttpResponse HttpRequest ) {
    ^ ( with_timeout 5000
        \ HttpRequest req → HttpResponse {
            ^ ( response_text 200 `ok\n` )
        })
}

@ main → i { ^ 0 }
