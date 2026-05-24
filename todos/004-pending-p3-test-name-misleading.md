---
status: complete
priority: p3
tag: code-review, quality
---

# test_app_workers name is misleading

**Finding:** `test_app_workers` in test_basic.nu verifies that `app_with_workers` sets the `worker_count` field, but the name suggests it tests actual worker pool behavior. Since tests are compile-time only, this can't test runtime behavior.

**Action:** Rename to `test_app_with_workers_sets_field` or `test_app_workers_count` — make it clear this is a field-set test, not a runtime test.
