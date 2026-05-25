// nurlweb/upload.nu — File upload via multipart/form-data
//
// Ergonomic wrapper around stdlib http_multipart.nu. Parses multipart
// file uploads into a Vec<MultipartPart> that callers can scan for
// specific fields via stdlib's multipart_find_first / multipart_count.
// Enforces Content-Length limit (default 10 MiB) before parsing to
// prevent memory exhaustion from large uploads.
//
// Memory model: upload_parts / upload_parts_with_limit return OWNED
// parts — caller must free with upload_free when done.
// upload_free is an alias for stdlib multipart_parts_free, kept for
// API surface consistency (LLM-friendly naming: upload_* prefix).
//
// API:
//   ( upload_parts              Ctx ctx ) → ?( Vec MultipartPart )
//   ( upload_parts_with_limit   Ctx ctx i max_bytes ) → ?( Vec MultipartPart )
//   ( upload_free               ( Vec MultipartPart ) parts ) → v
//
// Constants:
//   UPLOAD_MAX_DEFAULT         → i     10485760 (10 MiB)
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
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`

// ── Constants ────────────────────────────────────────────────────────

@ UPLOAD_MAX_DEFAULT → i { ^ 10485760 }

// ── upload_parts (default limit) ─────────────────────────────────────

@ upload_parts Ctx ctx → ?( Vec MultipartPart ) {
    ^ ( upload_parts_with_limit ctx ( UPLOAD_MAX_DEFAULT ) )
}

// ── upload_parts_with_limit — Content-Length check before parse ─────

@ upload_parts_with_limit Ctx ctx i max_bytes → ?( Vec MultipartPart ) {
    : ?String cl_opt ( header_get . ctx req `Content-Length` )
    ?? cl_opt {
        T cl_str → {
            : i cl ( nurl_str_to_int cl_str )
            ? > cl max_bytes {
                ^ @ ?( Vec MultipartPart ) { F }
            } {}
        }
        F _ → {}
    }
    ^ ( request_multipart_parts . ctx req )
}

// ── upload_free — release multipart parts ────────────────────────────

@ upload_free ( Vec MultipartPart ) parts → v {
    ( multipart_parts_free parts )
}
