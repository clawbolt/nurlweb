#!/usr/bin/env bash
# nurlweb/test_e2e.sh — E2E smoke tests for nurlweb examples
# Run: NURL_NET_TESTS=1 bash nurlweb/test_e2e.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# nurlc + runtime from the nurl-lang repo
NURL_LANG="/Users/t77yq/Documents/Codex/2026-05-24/nurl-lang-nurl-https-github-com-2"
NURLC="$NURL_LANG/build/nurlc"
RUNTIME="$NURL_LANG/stdlib/runtime.o"

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
    rm -f "$SCRIPT_DIR/test_hello" "$SCRIPT_DIR/test_hello.ll" \
          "$SCRIPT_DIR/test_rest" "$SCRIPT_DIR/test_rest.ll"
}
trap cleanup EXIT

# ── Shared link step ──────────────────────────────────────────────────

CURL_LIBS=($(pkg-config --libs libcurl 2>/dev/null || echo "-lcurl"))
OPENSSL_LIBS=($(pkg-config --libs openssl 2>/dev/null || echo "-lssl -lcrypto"))
SQLITE3_LIBS=($(pkg-config --libs sqlite3 2>/dev/null || echo "-lsqlite3"))
ZLIB_LIBS=($(pkg-config --libs zlib 2>/dev/null || echo "-lz"))
ZSTD_LIBS=($(pkg-config --libs libzstd 2>/dev/null || echo "-lzstd"))

link_bin() {
    local src="$1" out="$2"
    clang -O2 "$src" "$RUNTIME" -lm -lpthread \
        "${CURL_LIBS[@]}" "${OPENSSL_LIBS[@]}" "${SQLITE3_LIBS[@]}" \
        "${ZLIB_LIBS[@]}" "${ZSTD_LIBS[@]}" -o "$out" 2>/dev/null
}

# ── Build & test hello.nu ─────────────────────────────────────────────

echo "Building hello.nu..."
"$NURLC" "$SCRIPT_DIR/examples/hello.nu" > "$SCRIPT_DIR/test_hello.ll" 2>/dev/null
link_bin "$SCRIPT_DIR/test_hello.ll" "$SCRIPT_DIR/test_hello"

echo "Starting hello server on :3909..."
"$SCRIPT_DIR/test_hello" &
PID=$!
sleep 1

if curl -s http://127.0.0.1:3909/ | grep -q "nurlweb"; then
    pass_test "GET / returns hello"
else
    fail_test "GET /" "no hello in response"
fi

if [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3909/nope)" = "404" ]; then
    pass_test "GET /nope returns 404"
else
    fail_test "GET /nope" "expected 404"
fi

kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true
PID=""

# ── Build & test rest_api.nu (CRUD cycle) ─────────────────────────────

echo ""
echo "Building rest_api.nu..."
"$NURLC" "$SCRIPT_DIR/examples/rest_api.nu" > "$SCRIPT_DIR/test_rest.ll" 2>/dev/null
link_bin "$SCRIPT_DIR/test_rest.ll" "$SCRIPT_DIR/test_rest"

echo "Starting REST API server on :3920..."
"$SCRIPT_DIR/test_rest" &
PID=$!
sleep 1

# CREATE — POST /items
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    -H 'Content-Type: application/json' \
    -d '{"name":"test-item"}' http://127.0.0.1:3920/items)
if [ "$code" = "201" ]; then
    pass_test "POST /items → 201 Created"
else
    fail_test "POST /items" "expected 201, got $code"
fi

# LIST — GET /items
resp=$(curl -s http://127.0.0.1:3920/items)
if echo "$resp" | grep -q "test-item"; then
    pass_test "GET /items returns created item"
else
    fail_test "GET /items" "item not found in response: $resp"
fi

# GET by ID — GET /items/0
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3920/items/0)
if [ "$code" = "200" ]; then
    pass_test "GET /items/0 → 200 OK"
else
    fail_test "GET /items/0" "expected 200, got $code"
fi

# UPDATE — PUT /items/0
code=$(curl -s -o /dev/null -w '%{http_code}' -X PUT \
    -H 'Content-Type: application/json' \
    -d '{"name":"updated-item"}' http://127.0.0.1:3920/items/0)
if [ "$code" = "200" ]; then
    pass_test "PUT /items/0 → 200 OK"
else
    fail_test "PUT /items/0" "expected 200, got $code"
fi

# DELETE — DELETE /items/0
code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE \
    http://127.0.0.1:3920/items/0)
if [ "$code" = "204" ]; then
    pass_test "DELETE /items/0 → 204 No Content"
else
    fail_test "DELETE /items/0" "expected 204, got $code"
fi

# 404 — GET /items/999 (nonexistent)
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3920/items/999)
if [ "$code" = "404" ]; then
    pass_test "GET /items/999 → 404 Not Found"
else
    fail_test "GET /items/999" "expected 404, got $code"
fi

kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All E2E tests passed!" || echo "Some tests failed."

exit $fail
