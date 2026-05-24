---
status: complete
priority: p3
tag: code-review, security
---

# Document body size / unbounded allocation risk in FRAMEWORK.md

**Finding:** `ctx_body_raw` and `ctx_body_json` read the entire request body into memory without any size limit. A malicious client could send a huge body and cause unbounded memory allocation.

**Context:** This is by design — NurlWeb is a low-level framework. Input validation is the caller's responsibility. However, this should be documented so users are aware.

**Action:** Add a note to FRAMEWORK.md under "Known Limitations" or "Patterns → Body":
> Body reading has no size limit — callers should check Content-Length before reading large bodies, or use streaming (when available in NURL stdlib).
