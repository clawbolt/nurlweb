// nurlweb/test_upload.nu — Compile-time unit tests for upload.nu
//
// Verifies that upload types and functions compile correctly.
// Run: ./build/nurlc nurlweb/test_upload.nu
// Expected: exit 0

$ `nurlweb/ctx.nu`
$ `nurlweb/upload.nu`
$ `stdlib/ext/http_full.nu`
$ `stdlib/ext/http_multipart.nu`
$ `stdlib/core/vec.nu`

// ── Test: upload_parts compiles (default limit) ──────────────────────

@ test_upload_parts Ctx ctx → ?( Vec MultipartPart ) {
    ^ ( upload_parts ctx )
}

// ── Test: upload_parts_with_limit compiles ────────────────────────────

@ test_upload_parts_with_limit Ctx ctx → ?( Vec MultipartPart ) {
    ^ ( upload_parts_with_limit ctx 5242880 )
}

// ── Test: upload_free compiles ───────────────────────────────────────

@ test_upload_free ( Vec MultipartPart ) parts → v {
    ( upload_free parts )
}

// ── Test: full upload handler ────────────────────────────────────────

@ test_upload_handler HttpRequest req Params params → HttpResponse {
    : Ctx ctx ( ctx_new req params )
    : ?( Vec MultipartPart ) parts_opt ( upload_parts ctx )
    ?? parts_opt {
        T parts → {
            : i n ( multipart_count parts )
            ( upload_free parts )
            ^ ( response_text 200 `ok\n` )
        }
        F _ → {
            ^ ( response_text 400 `no upload\n` )
        }
    }
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
