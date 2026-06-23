#!/usr/bin/env bash
# test_sync.sh — Local integration tests for sync.sh
# Uses direct directory testing and sources sync.sh to avoid git operations.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

# Source the sync script to get sync_directory and helper functions
export GH_TOKEN="fake-token"
export GITHUB_WORKSPACE="$REPO_ROOT"
source "$SCRIPT_DIR/sync.sh"

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
pass() { echo -e "${GREEN}  PASS${NC} $*"; }
fail() {
  echo -e "${RED}  FAIL${NC} $*"
  FAILURES=$((FAILURES + 1))
}
info() { echo -e "${YELLOW}  ····${NC} $*"; }

FAILURES=0

# ── Temp workspace ────────────────────────────────────────────────────────────
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

# ── Helper: create a virtual downstream directory ─────────────────────────────
# Usage: make_repo_dir <name> [config_json]
make_repo_dir() {
  local name="$1"
  local config="${2:-}"
  local dest="$TEST_ROOT/$name"
  
  rm -rf "$dest"
  mkdir -p "$dest/.github"
  echo "# $name" > "$dest/README.md"

  if [ -n "$config" ]; then
    printf '%s\n' "$config" > "$dest/.github/config.json"
  fi
  
  echo "$dest"
}

# ═════════════════════════════════════════════════════════════════════════════
# TESTS
# ═════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== sync.sh integration tests ==="
echo ""

# ── Test 1: New repo (no config.json) gets all 3 OSes ────────────────────────
info "Test 1: New repo gets all 3 OS inputs in ci.yml"
dest=$(make_repo_dir "new-repo")
(sync_directory "$dest" "new-repo" "$SCRIPT_DIR" > /dev/null)

ci="$dest/.github/workflows/ci.yml"
if [ ! -f "$ci" ]; then
  fail "ci.yml was not created"
elif grep -q "test-linux:" "$ci" && grep -q "test-macos:" "$ci" && grep -q "test-windows:" "$ci"; then
  pass "All 3 OS inputs present"
elif grep -q "__LINUX__\|__MACOS__\|__WINDOWS__" "$ci"; then
  fail "Placeholders were not replaced"
else
  fail "ci.yml is missing expected OS inputs"
fi

cfg="$dest/.github/config.json"
if [ -f "$cfg" ] && jq -e '.os | length == 3' "$cfg" > /dev/null 2>&1; then
  pass "config.json has all 3 OSes"
else
  fail "config.json missing or doesn't have 3 OSes"
fi

# ── Test 2: Existing repo with linux-only config keeps only linux input ───────
info "Test 2: Linux-only config.json keeps single 'test' input"
dest=$(make_repo_dir "linux-only" '{"package":"linux-only","os":["linux"]}')
(sync_directory "$dest" "linux-only" "$SCRIPT_DIR" > /dev/null)

ci="$dest/.github/workflows/ci.yml"
if [ ! -f "$ci" ]; then
  fail "ci.yml was not created"
elif grep -q "^      test:$" "$ci" && ! grep -q "inputs\.test-linux\|test-macos\|test-windows" "$ci"; then
  pass "Single 'test' input, no OS-specific keys"
else
  fail "Expected single 'test' input for linux-only repo"
fi

# Ensure config.json was NOT changed
cfg="$dest/.github/config.json"
os_count=$(jq '.os | length' "$cfg" 2> /dev/null || echo 0)
if [ "$os_count" -eq 1 ]; then
  pass "config.json left untouched (still linux-only)"
else
  fail "config.json was modified (os count=$os_count, expected 1)"
fi

# ── Test 3: Existing repo with all 3 OSes keeps all 3 inputs ─────────────────
info "Test 3: Full OS config.json keeps all 3 OS inputs"
dest=$(make_repo_dir "full-os" '{"package":"full-os","os":["linux","macos","windows"]}')
(sync_directory "$dest" "full-os" "$SCRIPT_DIR" > /dev/null)

ci="$dest/.github/workflows/ci.yml"
if grep -q "test-linux:" "$ci" && grep -q "test-macos:" "$ci" && grep -q "test-windows:" "$ci"; then
  pass "All 3 OS inputs present"
else
  fail "Expected all 3 OS inputs for full-os repo"
fi

# ── Test 4: config.json package name is preserved after sync ──────────────────
info "Test 4: Existing package name is preserved"
dest=$(make_repo_dir "timeutil" '{"package":"timeutil","os":["linux","macos","windows"],"version-files":["src/timeutil.c"]}')
(sync_directory "$dest" "timeutil" "$SCRIPT_DIR" > /dev/null)

pkg=$(jq -r '.package' "$dest/.github/config.json" 2> /dev/null || echo "")
if [ "$pkg" = "timeutil" ]; then
  pass "package name preserved as 'timeutil'"
else
  fail "package name is '$pkg', expected 'timeutil'"
fi

# ── Test 5: New repo gets package name = repo name ────────────────────────────
info "Test 5: New repo config.json package defaults to repo name"
dest=$(make_repo_dir "my-lib")
(sync_directory "$dest" "my-lib" "$SCRIPT_DIR" > /dev/null)

pkg=$(jq -r '.package' "$dest/.github/config.json" 2> /dev/null || echo "")
if [ "$pkg" = "my-lib" ]; then
  pass "package name defaulted to 'my-lib'"
else
  fail "package name is '$pkg', expected 'my-lib'"
fi

# ── Test 6: No __MODULES__ placeholder left in .rockspec ─────────────────────
info "Test 6: No unreplaced placeholders in generated .rockspec"
dest=$(make_repo_dir "clean-repo")
(sync_directory "$dest" "clean-repo" "$SCRIPT_DIR" > /dev/null)

if grep -rq "__MODULES__\|__PACKAGE__\|__REPO__\|__VERSION__" "$dest/.github/" 2> /dev/null; then
  fail "Unreplaced placeholders found in .github/"
else
  pass "No unreplaced placeholders"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
else
  echo -e "${RED}$FAILURES test(s) failed.${NC}"
  exit 1
fi
