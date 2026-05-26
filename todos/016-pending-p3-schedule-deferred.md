# TODO: schedule.nu — Periodic Task Execution (Deferred)

## What
Build `schedule.nu` module for timer-based periodic task execution using NURL async fibers.

## Why
Real apps need periodic tasks: session cleanup, cache invalidation, report generation. Egg.js has `schedule` as a first-class convention. Deferring because NURL's fiber scheduler is at Phase 1+2 (single-thread), Phase 3 (M:N work-stealing) is pending. Building on an unstable scheduler risks API breakage.

## Pros
- Complete convention framework: config + lifecycle + resources + scheduling
- Matches Egg.js's feature set
- ~60 LOC implementation when fibers are ready

## Cons
- Depends on fiber scheduler maturity (Phase 3)
- API may change if scheduler semantics shift

## Context
CEO review (2026-05-26) accepted 12 scope expansions. Schedule was originally P2, downgraded to P3 after recognizing the async fiber foundation isn't production-ready. The API design is locked: `kit_schedule_every i seconds fn_ref → v` with 60s default timeout and 8 concurrent fiber cap.

## Depends on / blocked by
- Blocked by: NURL fiber scheduler Phase 3 (M:N work-stealing)
- Order: after kit lifecycle + kit logger are stable
