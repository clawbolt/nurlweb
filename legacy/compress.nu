// nurlweb/compress.nu — Response compression middleware (gzip)
//
// Wraps stdlib with_gzip to compress responses > 256 bytes.
// Clients must send Accept-Encoding: gzip.
//
// API:
//   ( app_with_compress App a ) → v
//
// Usage:
//   ( app_with_compress app )

$ `nurlweb/app.nu`
$ `stdlib/ext/http_full.nu`

@ app_with_compress App a → v {
    ( app_use a \ ( @ HttpResponse HttpRequest ) inner → ( @ HttpResponse HttpRequest ) {
        ^ ( with_gzip inner )
    })
}
