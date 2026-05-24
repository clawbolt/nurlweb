---
status: complete
priority: p2
tags: [code-review, architecture, devex]
agent: architecture-strategist
file: nurlweb.nu:14-27
---

# Aspirational v1.1 Module References Don't Exist

## Finding
`nurlweb.nu` contains commented-out `$` imports for 6 v1.1 modules and 3 v1.2 modules. Of these, only the 3 v1.2 modules (`session.nu`, `upload.nu`, `template.nu`) actually exist. The v1.1 modules (`validate.nu`, `error.nu`, `respond.nu`, `auth.nu`, `static.nu`, `ws.nu`) are aspirational — they have no implementations.

## Location
- `nurlweb.nu:14-19` — v1.1 modules (none exist)
- `nurlweb.nu:23-27` — v1.2 modules (all exist after this commit)

## Impact
- LLM agents may uncomment these imports and expect them to work — leading to compile errors
- Sets expectations for features that may never ship
- Confusing for human developers browsing the aggregator

## Recommendation
- **Now:** Move v1.1 aspirational modules to a separate `ROADMAP.md` or a "Future" section in FRAMEWORK.md
- **Now:** Uncomment the v1.2 module imports since they exist
- **Future:** Only add commented imports when the module file is committed (even if experimental)

The v1.2 imports (`session.nu`, `upload.nu`, `template.nu`) should be uncommented now since the modules exist.
