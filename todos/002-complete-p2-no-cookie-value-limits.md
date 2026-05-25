---
status: complete
priority: p2
tags: [code-review, security]
agent: security-sentinel
file: session.nu:25-29
---

# No Cookie Value Length Limits

## Finding
`session_set` accepts arbitrary-length name and value strings and passes them directly to `response_set_cookie`. Browsers enforce cookie size limits (~4KB total per domain), but the framework doesn't validate. Large values could silently fail or cause HTTP header overflow.

## Location
- `session.nu:28` — `( response_set_cookie r name value opts )` with no length check

## Impact
- Cookies exceeding browser limits silently dropped — session data loss
- Potential HTTP header size issues if combined with other cookies
- No feedback to caller that their data exceeded limits

## Recommendation
Add a `max_cookie_size` constant (e.g., 4096 bytes) and validate in `session_set`. Return an error or truncate with a warning comment in docs.

```nurl
: i MAX_COOKIE_SIZE 3800  // leave headroom for cookie attributes

@ session_set Ctx ctx HttpResponse r s name s value → v {
    ? > ( nurl_str_len value ) MAX_COOKIE_SIZE {
        // value too large — skip or log warning
        ^ @ v {}
    } {}
    // ... existing code ...
}
```
