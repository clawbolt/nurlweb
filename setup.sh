#!/usr/bin/env bash
# nurlweb/setup.sh — Configure project for compilation
#
# Creates symlinks so that NURL's $ import paths resolve correctly.
# Run once from your project root (where nurlweb/ and nurlweb-kit/ live).
#
# Usage:
#   sh nurlweb/setup.sh /path/to/nurl-lang
#   # or:
#   NURL_LANG_ROOT=/path/to/nurl-lang sh nurlweb/setup.sh
#
# Prerequisites:
#   - nurl-lang cloned and built (./build.sh in nurl-lang root)
#   - nurlweb/ and nurlweb-kit/ in your project directory

set -euo pipefail

NURL_LANG_ROOT="${1:-${NURL_LANG_ROOT:-}}"

if [ -z "$NURL_LANG_ROOT" ]; then
    echo "Usage: sh nurlweb/setup.sh /path/to/nurl-lang"
    echo "   or: NURL_LANG_ROOT=/path/to/nurl-lang sh nurlweb/setup.sh"
    exit 1
fi

# Resolve to absolute path
NURL_LANG_ROOT="$(cd "$NURL_LANG_ROOT" && pwd)"

if [ ! -d "$NURL_LANG_ROOT/stdlib" ]; then
    echo "Error: $NURL_LANG_ROOT/stdlib not found."
    echo "Is this a nurl-lang repository with a built stdlib?"
    exit 1
fi

NURLC="$NURL_LANG_ROOT/build/nurlc"
RUNTIME="$NURL_LANG_ROOT/stdlib/runtime.o"

# ── Create stdlib symlink ────────────────────────────────────────────

if [ -L "stdlib" ]; then
    rm stdlib
    echo "Replaced existing stdlib symlink"
elif [ -d "stdlib" ]; then
    echo "Error: stdlib/ exists as a real directory. Remove or rename it first."
    exit 1
fi

ln -s "$NURL_LANG_ROOT/stdlib" stdlib
echo "Linked stdlib → $NURL_LANG_ROOT/stdlib"

# ── Verify toolchain ─────────────────────────────────────────────────

if [ -x "$NURLC" ]; then
    echo "Found nurlc: $NURLC"
else
    echo "Warning: nurlc not found at $NURLC"
    echo "Build nurl-lang first: cd $NURL_LANG_ROOT && sh build.sh"
fi

if [ -f "$RUNTIME" ]; then
    echo "Found runtime: $RUNTIME"
else
    echo "Warning: runtime.o not found at $RUNTIME"
fi

# ── Summary ──────────────────────────────────────────────────────────

echo ""
echo "Setup complete. You can now build nurlweb apps:"
echo ""
echo "  export NURLC=$NURLC"
echo "  export NURL_RUNTIME=$RUNTIME"
echo "  \$NURLC examples/hello.nu > hello.ll"
echo "  clang -O2 hello.ll \$NURL_RUNTIME -lm -lpthread \\"
echo "    \$(pkg-config --libs libcurl openssl sqlite3 zlib libzstd 2>/dev/null || echo \"-lcurl -lssl -lcrypto -lsqlite3 -lz -lzstd\") \\"
echo "    -o hello"
echo "  ./hello"
