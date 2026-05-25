# TODO: nurlweb-kit Reference Documentation

## What
Write FRAMEWORK.md equivalent for nurlweb-kit — full API reference with examples for all kit_ functions.

## Why
nurlweb has FRAMEWORK.md (14805 bytes) documenting every function. nurlweb-kit introduces ~25 new functions (kit_config_*, kit_resources, kit_lifecycle_*, kit_log_*, kit_mount, kit_template_auto) plus CLI commands. Without reference docs, developers have to read source code.

## Pros
- Developers can discover kit APIs without reading source
- CLI help text is not enough for learning conventions
- Matches nurlweb's documentation standard

## Cons
- ~150 LOC of markdown to write and maintain
- Must stay in sync with kit module changes

## Context
Plan-eng-review (2026-05-26) noted the plan doesn't specify documentation beyond CLI help. Documentation is deferred to after implementation is stable.

## Depends on / blocked by
- Depends on: all kit modules implemented and API stable
- Order: last step before release
