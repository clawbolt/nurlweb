#!/usr/bin/env bash
# nurlweb/test_e2e.sh — E2E smoke tests
# Run: NURL_NET_TESTS=1 bash nurlweb/test_e2e.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
NURLC="$REPO_ROOT/build/nurlc"
RUNTIME="$REPO_ROOT/stdlib/runtime.o"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass=0
fail=0

pass_test() { echo -e "${GREEN}PASS${NC} $1"; pass=$((pass + 1)); }
fail_test() { echo -e "${RED}FAIL${NC} $1 — $2"; fail=$((fail + 1)); }

PID=""

cleanup() {
    [ -n "${PID:-}" ] && kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/test_hello" "$SCRIPT_DIR/test_hello.ll"
}
trap cleanup EXIT

# ── Build hello.nu ────────────────────────────────────────────────────

echo "Building hello.nu..."
"$NURLC" "$SCRIPT_DIR/examples/hello.nu" > "$SCRIPT_DIR/test_hello.ll" 2>/dev/null

CURL_LIBS=($(pkg-config --libs libcurl))
OPENSSL_LIBS=($(pkg-config --libs openssl))
SQLITE3_LIBS=($(pkg-config --libs sqlite3))
ZLIB_LIBS=($(pkg-config --libs zlib))
ZSTD_LIBS=($(pkg-config --libs libzstd))

clang -O2 "$SCRIPT_DIR/test_hello.ll" "$RUNTIME" -lm -lpthread \
  "${CURL_LIBS[@]}" "${OPENSSL_LIBS[@]}" "${SQLITE3_LIBS[@]}" \
  "${ZLIB_LIBS[@]}" "${ZSTD_LIBS[@]}" -o "$SCRIPT_DIR/test_hello" 2>/dev/null

echo "Starting hello server on :3909..."
"$SCRIPT_DIR/test_hello" &
PID=$!
sleep 1

# ── Test 1: health check ──────────────────────────────────────────────

if curl -s http://127.0.0.1:3909/ | grep -q "nurlweb"; then
    pass_test "GET / returns hello"
else
    fail_test "GET /" "no hello in response"
fi

# ── Test 2: 404 route ─────────────────────────────────────────────────

if [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3909/nope)" = "404" ]; then
    pass_test "GET /nope returns 404"
else
    fail_test "GET /nope" "expected 404"
fi

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All E2E tests passed!" || echo "Some tests failed."

kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true

exit $fail
