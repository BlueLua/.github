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
info "Test 1: New repo gets all 3 OSes in test.yml"
dest=$(make_repo_dir "new-repo")
(sync_directory "$dest" "new-repo" "$SCRIPT_DIR" > /dev/null)

test_workflow_file="$dest/.github/workflows/test.yml"
if [ ! -f "$test_workflow_file" ]; then
  fail "test.yml was not created"
elif grep -q '"ubuntu-latest"' "$test_workflow_file" && grep -q '"macos-latest"' "$test_workflow_file" && grep -q '"windows-latest"' "$test_workflow_file"; then
  pass "All 3 OSes present in matrix"
else
  fail "test.yml is missing expected OS matrix values"
fi

cfg="$dest/.github/config.json"
if [ -f "$cfg" ] && jq -e '.os | length == 3' "$cfg" > /dev/null 2>&1; then
  pass "config.json has all 3 OSes"
else
  fail "config.json missing or doesn't have 3 OSes"
fi

# ── Test 2: Linux-only config.json keeps only linux matrix ───────────────────
info "Test 2: Linux-only config.json keeps single 'ubuntu-latest' in matrix"
dest=$(make_repo_dir "linux-only" '{"package":"linux-only","os":["linux"]}')
(sync_directory "$dest" "linux-only" "$SCRIPT_DIR" > /dev/null)

test_workflow_file="$dest/.github/workflows/test.yml"
if [ ! -f "$test_workflow_file" ]; then
  fail "test.yml was not created"
elif grep -q '"ubuntu-latest"' "$test_workflow_file" && ! grep -q '"macos-latest"\|"windows-latest"' "$test_workflow_file"; then
  pass "Single 'ubuntu-latest' in matrix"
else
  fail "Expected single 'ubuntu-latest' in matrix for linux-only repo"
fi

# Ensure config.json was NOT changed
cfg="$dest/.github/config.json"
os_count=$(jq '.os | length' "$cfg" 2> /dev/null || echo 0)
if [ "$os_count" -eq 1 ]; then
  pass "config.json left untouched (still linux-only)"
else
  fail "config.json was modified (os count=$os_count, expected 1)"
fi

# ── Test 3: Existing repo with all 3 OSes keeps all 3 matrix values ──────────
info "Test 3: Full OS config.json keeps all 3 OSes in matrix"
dest=$(make_repo_dir "full-os" '{"package":"full-os","os":["linux","macos","windows"]}')
(sync_directory "$dest" "full-os" "$SCRIPT_DIR" > /dev/null)

test_workflow_file="$dest/.github/workflows/test.yml"
if grep -q '"ubuntu-latest"' "$test_workflow_file" && grep -q '"macos-latest"' "$test_workflow_file" && grep -q '"windows-latest"' "$test_workflow_file"; then
  pass "All 3 OSes present in matrix"
else
  fail "Expected all 3 OSes in matrix for full-os repo"
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

# ── Test 7: README.md auto-creation from config.json ─────────────────────────
info "Test 7: README.md is auto-created from config.json"
dest=$(make_repo_dir "readme-test" '{"package":"readme-test","desc":"A test library.","features":["Feature A","Feature B"],"usage":"test.run()"}')
rm -f "$dest/README.md"
(sync_directory "$dest" "readme-test" "$SCRIPT_DIR" > /dev/null)

readme="$dest/README.md"
if [ ! -f "$readme" ]; then
  fail "README.md was not created"
elif grep -q "A test library." "$readme" && grep -q "\- Feature A" "$readme" && grep -q "\- Feature B" "$readme" && grep -q "## ✨ Features" "$readme" && grep -q "\[!\[Test\]" "$readme" && grep -q 'local readme_test = require "readme-test"' "$readme" && grep -q "test.run()" "$readme"; then
  pass "README.md correctly generated with description, features, badges, and custom usage"
else
  fail "README.md generation was incorrect"
fi

# ── Test 8: README.md auto-creation with single string multiline ──────────────
info "Test 8: README.md handles single multiline strings for features and usage"
dest=$(make_repo_dir "readme-string-test" '{"package":"readme-string-test","desc":"String library.","features":["Feature X","Feature Y"],"usage":"test.run()"}')
rm -f "$dest/README.md"
(sync_directory "$dest" "readme-string-test" "$SCRIPT_DIR" > /dev/null)

readme="$dest/README.md"
if [ ! -f "$readme" ]; then
  fail "README.md was not created"
elif grep -q "String library." "$readme" && grep -q "\- Feature X" "$readme" && grep -q "\- Feature Y" "$readme" && grep -q 'local readme_string_test = require "readme-string-test"' "$readme" && grep -q "test.run()" "$readme"; then
  pass "README.md correctly generated with multiline strings"
else
  fail "README.md generation with multiline strings was incorrect"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
else
  echo -e "${RED}$FAILURES test(s) failed.${NC}"
  exit 1
fi
