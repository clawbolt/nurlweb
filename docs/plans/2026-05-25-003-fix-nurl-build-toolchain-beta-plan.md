# Fix: NURL Build Toolchain — LLVM IR Compatibility

**Created:** 2026-05-25  
**Status:** Plan  
**Type:** fix  

---

## Problem Frame

nurlc (NURL self-hosted compiler) generates LLVM IR that Apple clang 21 / LLVM 19+ cannot parse or link. This blocks compilation of ALL nurlweb modules — none of the nurlweb examples (`hello.nu`, `rest_api.nu`, etc.) or newly authored v2 modules (`orm.nu`, `auth_jwt.nu`, etc.) can produce a runnable binary.

**Scope:** Fix the nurlc → clang pipeline so that any valid `.nu` file compiles to a working native binary on macOS 26.5 (Apple clang 21).  
**Non-scope:** nurlc language features, nurlweb application logic, stdlib changes.

---

## Root Cause Analysis

### The Toolchain

```
nurlc (self-hosted NURL compiler)
   ↓ generates LLVM IR (typed pointers)
clang -O2 user.ll stdlib/runtime.o → native binary
```

### Three Bugs in nurlc-Generated IR (confirmed via audit)

| Bug | Example | Count in hello.nu IR | Severity |
|-----|---------|---------------------|----------|
| **B1: phi missing type** | `%r38 = phi  [%r33, %then], [%r37, %else]` | 1 | Blocker (parse error) |
| **B2: i8 pointer confusion** | NURL `i8` type maps to LLVM `i8` (byte) instead of `ptr`, causing `alloca i8`/`store i8`/`load i8` where pointer semantics needed | 24 allocas + 33 stores | Blocker (type error) |
| **B3: undef insertvalue** | `insertvalue %T undef, ...` — Apple clang 21+ requires `zeroinitializer` | 740 | Blocker (IR verifier) |

### Why the Bug Exists

nurlc.nu (the compiler source, line 154):
```
? ( seq ty `i8` ) `i8`   // NURL i8 → LLVM i8 (BYTE, but should be ptr)
```

NURL's `i8` type is semantically a pointer (`align_of=8`, size 8) but maps to LLVM `i8` (byte, size 1). This was valid in LLVM ≤14 typed-pointer era but breaks with LLVM 15+ opaque pointers.

### Why the Bootstrap Works but User Code Doesn't

| | nurlc.nu (compiler source) | hello.nu (user code) |
|---|---|---|
| phi bugs | **0** | **1** |
| alloca i8 | **0** | **24** |
| undef insertvalue | **0** | **740** |

The compiler source uses a subset of NURL that doesn't trigger the codegen bugs. User code (closures, Option unwrapping, `i8`-typed locals) does.

### Why -flto Matters

build.sh compiles `runtime.o` with `-flto`, making it LLVM bitcode. During linking:
```
user.ll (typed pointers, buggy) + runtime.o (LLVM bitcode, opaque pointers) → 💥
```
The bitcode formats clash. Non-LTO `runtime.o` (Mach-O object) avoids this but B1/B2/B3 still block IR parsing.

---

## Solution: Two-Phase Fix

### Phase A: IR Post-Processor (immediate, ~1 day)

Write `tools/nurl-ir-fix.py` — a Python script that takes nurlc LLVM IR and outputs valid opaque-pointer IR for clang 21+.

**Fix B1 — phi type inference:**  
Scan IR for `phi [` without type annotation. Infer type from first incoming value's definition (alloca type, load type, call return type, etc.). Default to `i64`.

**Fix B2 — i8 → ptr conversion:**  
Identify all pointer-typed registers (from `i8*` call returns, `extractvalue {.., i8*}`, etc.). Propagate through alloca/store/load chains. Convert:
- `alloca i8` → `alloca ptr` (pointer allocas only)
- `store i8 %p, i8* %a` → `store ptr %p, ptr %a`
- `load i8, i8*` → `load ptr, ptr`
- `trunc i64 0 to i8` → `inttoptr i64 0 to ptr` (null pointer)
- `zext i8 %p to i64` → `ptrtoint ptr %p to i64`
- `getelementptr i8, i8*` → `getelementptr ptr, ptr`
- Struct types: `{ i8 }` → `{ ptr }`
- Global: `i8*` → `ptr`, `i8**` → `ptr`

**Fix B3 — undef → zeroinitializer:**  
`insertvalue %T undef` → `insertvalue %T zeroinitializer`

**Files:**
- NEW: `tools/nurl-ir-fix.py` — the post-processor
- MODIFY: `scripts/build-nurlweb.sh` — add `tools/nurl-ir-fix.py` as a build step

### Phase B: Rebuild runtime.o without LTO (medium, ~1 hour)

Modify build.sh to produce `stdlib/runtime.native.o` (non-LTO Mach-O object).

```bash
# In nurl-lang repo:
clang -O2 -fno-lto -D_XOPEN_SOURCE -c stdlib/runtime.c -o stdlib/runtime.native.o
```

Already exists in build.sh logic (lines 245-247) but not triggered by default.

**Files:**
- NEW: `stdlib/runtime.native.o` — auto-generated, in .gitignore
- MODIFY: `scripts/build-nurlweb.sh` — link against `runtime.native.o`

### Phase C: Long-Term — Fix nurlc.nu Codegen (long, ~1 week)

Modify `compiler/nurlc.nu`:
- Line 154: `? ( seq ty 'i8' ) 'ptr'` — emit opaque pointer type
- Update all size/align calculations to use 8 for `i8`/`ptr`
- Fix phi emission to always include type annotation
- Fix insertvalue to use zeroinitializer

Requires nurlc bootstrap rebuild (python → stage0 → stage1 → stage2). This is the proper fix but needs upstream NURL repo coordination.

---

## Action Plan

### Step 1: Create IR post-processor
- File: `tools/nurl-ir-fix.py`
- Covers: B1 (phi types), B2 (i8→ptr), B3 (undef)
- Validation: run on hello.nu, orm.nu — verify `zig cc` link succeeds

### Step 2: Create unified build script
- File: `scripts/build-nurlweb.sh`
- Flow: `nurlc → nurl-ir-fix.py → clang with runtime.native.o → binary`
- Supports: single .nu file, examples/, test suites

### Step 3: Rebuild runtime.native.o
- Run once in nurl-lang repo
- Commit as part of nurlweb build infra (or document as prerequisite)

### Step 4: Verify v2 modules link
- orm.nu, auth_jwt.nu, template_v2.nu → compile + link
- Run E2E test suite

### Step 5: Report upstream
- Open issue on nurl-lang/nurl documenting B1/B2/B3
- Propose nurlc.nu fix for line 154
- Share nurl-ir-fix.py as reference

---

## Dependencies & Sequencing

```
Step 1 (IR fixer) ──→ Step 2 (build script) ──→ Step 4 (verify v2)
                          ↑
Step 3 (native runtime) ──┘
                          ↓
                    Step 5 (upstream)
```

---

## Risk & Mitigation

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| IR fixer misses edge cases in i8 propagation | Medium | Iterative: run on full test suite, fix failures one by one |
| runtime.c fails to compile (deprecated APIs) | Low | Already tested: `-D_XOPEN_SOURCE` handles ucontext warnings |
| nurlc upstream changes break IR fixer | Low | Pin nurlc version in build script; IR fixer tests pin input IR |
| Performance regression from no-LTO | Low | LTO only affects startup; NURL apps are I/O bound |

---

## Verification Criteria

1. `./build-nurlweb.sh examples/hello.nu` produces working binary
2. `curl http://127.0.0.1:3900/` returns expected response
3. `orm.nu` module links and `test_orm_e2e` runs with sqlite3
4. All 16 nurlweb compile tests pass (nurlc phase)
5. Zero manual sed/awk in build pipeline — all logic in `nurl-ir-fix.py`
