#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
FIXTURES="$SCRIPT_DIR/fixtures"

# Source the sync script to get sync_directory and other helper functions
export GH_TOKEN="fake-token"
export GITHUB_WORKSPACE="$REPO_ROOT"
export TEST="true"
source "$REPO_ROOT/.github/scripts/sync.sh"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC}  $*"; }
fail() {
  echo -e "  ${RED}FAIL${NC}  $*"
  FAILURES=$((FAILURES + 1))
}
info() { echo -e "  ${YELLOW}····${NC}  $*"; }
FAILURES=0

# ── Temp workspace ────────────────────────────────────────────────────────────
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Compare expected and actual outputs strictly:
# 1. Verify the list of file paths is identical.
# 2. Compare the content of each file.
compare_to_expected() {
  local name="$1"
  local result_dir="$2"
  local expected_dir="$FIXTURES/expected/$name"
  local case_failed=0

  if [ ! -d "$expected_dir" ] && [ "${BLESS:-0}" != "1" ]; then
    info "No expected/ dir for '$name' — skipping file comparison"
    return 0
  fi

  # BLESS mode: copy result → expected instead of comparing
  if [ "${BLESS:-0}" = "1" ]; then
    rm -rf "$expected_dir"
    mkdir -p "$expected_dir"
    cp -a "$result_dir/." "$expected_dir/"
    info "Blessed expected output for '$name'"
    return 0
  fi

  # Get sorted list of relative file paths in expected and actual directories
  local expected_files actual_files
  expected_files=$(find "$expected_dir" -type f | sed "s|^$expected_dir/||" | sort)
  actual_files=$(find "$result_dir" -type f | sed "s|^$result_dir/||" | sort)

  # Check that the list of generated file paths matches the expected paths exactly
  if [ "$expected_files" != "$actual_files" ]; then
    fail "$name: generated file paths do not match expected paths"
    return 1
  fi

  # Compare contents of each file
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    local expected_file="$expected_dir/$rel"
    local result_file="$result_dir/$rel"

    if ! diff -u "$expected_file" "$result_file" > /dev/null 2>&1; then
      fail "$name: $rel does not match expected"
      case_failed=1
    fi
  done <<< "$expected_files"

  return $case_failed
}

# ── Discover test cases ───────────────────────────────────────────────────────
cases=()
for d in "$FIXTURES/repos"/*/; do
  cases+=("$(basename "$d")")
done

echo ""
echo -e "${BOLD}=== sync.sh golden-file tests ===${NC}"
echo ""

# ── Run sync once against all cases ──────────────────────────────────────────
info "Running sync_directory against: ${cases[*]}"
echo ""

# ── Compare results to expected ───────────────────────────────────────────────
for name in "${cases[@]}"; do
  echo -e "  ${BOLD}[$name]${NC}"

  # Setup result directory
  result_dir="$TMP/result_$name"
  rm -rf "$result_dir"
  mkdir -p "$result_dir"

  # Copy fixture repository template files
  fixture_dir="$FIXTURES/repos/$name"
  cp -a "$fixture_dir/." "$result_dir/"

  # Run the sync logic purely on the directory in a subshell
  (sync_directory "$result_dir" "$name" "$REPO_ROOT/.github/scripts" > /dev/null)

  if compare_to_expected "$name" "$result_dir"; then
    pass "all expected files match"
  fi
  echo ""
done

# ── Summary ───────────────────────────────────────────────────────────────────
if [ "$FAILURES" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All tests passed!${NC}"
else
  echo -e "${RED}${BOLD}$FAILURES check(s) failed.${NC}"
  exit 1
fi
