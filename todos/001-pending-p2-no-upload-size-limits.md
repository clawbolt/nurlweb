---
status: pending
priority: p2
tags: [code-review, security]
agent: security-sentinel
file: upload.nu:1-42
---

# No Upload Size Limits

## Finding
`upload.nu` delegates entirely to stdlib `http_multipart.nu` without enforcing any maximum upload size. A malicious client could send arbitrarily large multipart bodies, causing memory exhaustion on the server.

## Location
- `upload.nu:37-39` — `upload_parts` directly calls `request_multipart_parts` with no size check
- No `Content-Length` validation before parsing

## Impact
Denial of Service via memory exhaustion from large file uploads. The stdlib may or may not enforce limits — the framework should not rely on stdlib defaults alone.

## Recommendation
Add a `max_upload_size` parameter (either on App or as a separate function) and validate `Content-Length` before calling `request_multipart_parts`. Consider:

```nurl
@ upload_parts_with_limit Ctx ctx i max_bytes → ?( Vec MultipartPart ) {
    // Check Content-Length header before parsing
    : ?String cl_opt ( header_get . ctx req `Content-Length` )
    ?? cl_opt {
        T cl_str → {
            : !i ParseErr ir ( string_to_int cl_str )
            ?? ir {
                T cl → {
                    ? > cl max_bytes {
                        ^ @ ?( Vec MultipartPart ) { F @ Vec MultipartPart {} }
                    } {}
                }
                F _ → {}
            }
        }
        F _ → {}
    }
    ^ ( request_multipart_parts . ctx req )
}
```
