# TODO: Config Startup Validation

## What
Add `config_expect` function to `config.nu` that validates all required keys exist with correct types at startup. If any key is missing or wrong type, the app exits with a clear error message.

## Why
Without this, a missing env var or typo in config silently produces zero values (empty string, 0, false). The app starts and appears healthy but behaves incorrectly — listens on port 0, connects to empty database host, etc. These bugs are notoriously hard to diagnose because everything "works."

## Pros
- Catches config mistakes at startup with a clear error, not in production with silent wrong behavior
- ~15 LOC — small addition to existing config.nu module
- Standard practice in every Egg.js-level framework (Egg.js: `config.validate()`)

## Cons
- Developers must declare required keys via `config_expect` calls
- Adds one more step to the startup sequence

## Context
Found during plan-eng-review (2026-05-26). The config module defines `config_get`, `config_get_i`, `config_get_b` which return bare values. If a key doesn't exist, they return zero/empty/false silently. This is one of 4 critical gaps identified — the only one deferred to TODO (the other 3 are fixed in-plan).

Implementation: add `config_expect s key s expected_type → v` that checks the key exists and matches type. Call it in `main.nu` before `app_serve`. On failure, print `config error: key "port" expected "int" but missing` and exit 1.

## Depends on / blocked by
- Blocked by: T1 (config.nu must be implemented first)
- Order: implement after config.nu, before schedule.nu
