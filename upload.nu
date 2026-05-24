// nurlweb/upload.nu — File upload via multipart/form-data
//
// Ergonomic wrapper around stdlib http_multipart.nu. Parses multipart
// file uploads into a Vec<MultipartPart> that callers can scan for
// specific fields via stdlib's multipart_find_first / multipart_count.
//
// Memory model: upload_parts returns OWNED parts — caller must free
// with upload_free when done.
//
// API:
//   ( upload_parts Ctx ctx )                      → ?( Vec MultipartPart )
//   ( upload_free  ( Vec MultipartPart ) parts )   → v
//
// Usage:
//   : ?( Vec MultipartPart ) parts_opt ( upload_parts ctx )
//   ?? parts_opt {
//       T parts → {
//           : i idx ( multipart_find_first parts `avatar` )
//           ? >= idx 0 {
//               : ?MultipartPart p ( vec_get [MultipartPart] parts idx )
//               // ... use part data ...
//           } {}
//           ( upload_free parts )
//       }
//       F _ → {}
//   }

$ `nurlweb/ctx.nu`
$ `stdlib/ext/http_multipart.nu`
$ `stdlib/core/vec.nu`

// ── upload_parts — parse multipart body ──────────────────────────────

@ upload_parts Ctx ctx → ?( Vec MultipartPart ) {
    ^ ( request_multipart_parts . ctx req )
}

// ── upload_free — release multipart parts ────────────────────────────

@ upload_free ( Vec MultipartPart ) parts → v {
    ( multipart_parts_free parts )
}
