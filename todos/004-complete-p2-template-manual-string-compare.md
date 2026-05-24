---
status: complete
priority: p2
tags: [code-review, architecture, quality]
agent: architecture-strategist
file: template.nu:30-63
---

# Manual String Comparison in __try_push_var

## Finding
`__try_push_var` implements manual byte-by-byte string comparison (~35 LOC) instead of using stdlib's `string_eq` or equivalent. This:

1. Duplicates string comparison logic that should be in stdlib
2. Is fragile — won't handle Unicode normalization, case folding, etc.
3. Adds maintenance burden for what should be a one-liner
4. May have subtle bugs around edge cases (empty keys, non-ASCII)

## Location
- `template.nu:44-63` — manual comparison loop in `__try_push_var`

## Impact
- Potential correctness bugs with non-ASCII template keys
- Harder to audit and maintain
- Bloats the template module (~35 LOC could be ~3 LOC)

## Recommendation
Check if NURL stdlib has `string_eq` or add one. Replace the manual comparison:

```nurl
// If stdlib has string_eq:
@ __try_push_var ... → b {
    // ...
    ? ( string_eq tvkey ( string_data . tv key ) ) {
        ( string_push_str out ( string_data . tv value ) )
        ^ T
    } {}
    // ...
}
```

If no string_eq exists, this manual implementation should be extracted into a shared utility rather than embedded in template.nu.
