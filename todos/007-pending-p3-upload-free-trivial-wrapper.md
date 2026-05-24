---
status: pending
priority: p3
tags: [code-review, simplicity]
agent: code-simplicity-reviewer
file: upload.nu:40-42
---

# upload_free is a Trivial Wrapper

## Finding
`upload_free` is a one-line alias for `multipart_parts_free`:

```nurl
@ upload_free ( Vec MultipartPart ) parts → v {
    ( multipart_parts_free parts )
}
```

This exists solely for API surface consistency (to pair with `upload_parts`). The stdlib function is equally discoverable.

## Impact
- 3 LOC that add no functionality
- Slight LLM confusion — "should I use upload_free or multipart_parts_free?"
- Low severity — the wrapper is harmless

## Recommendation
**Option A:** Remove `upload_free` and document in FRAMEWORK.md that callers should use `multipart_parts_free` directly. Add a note in upload.nu header.

**Option B:** Keep for API consistency but add a comment explaining it's an alias.

Given the LLM-first design philosophy (uniform naming), Option B is reasonable. The tradeoff is clear: 3 LOC for predictable naming patterns.
