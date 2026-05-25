// nurlweb/test_compress.nu — Compile test for compress.nu
$ `nurlweb/compress.nu`

@ test_compress → v {
    : App a ( app_new `127.0.0.1` 9001 )
    ( app_with_compress a )
    ( app_free a )
}

@ main → i { ^ 0 }
