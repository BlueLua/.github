#!/usr/bin/env bash

# This script auto-generates README.md based on template/README.md and config.json.

set -euo pipefail

CONFIG=".github/config.json"

# Centralized fallback values for repository configurations
DESC="Lua library."
OS=("linux" "macos" "windows")
FEAT_LUAV="**Multiple Lua Versions**: Compatible with LuaJIT, Lua 5.1, 5.2, 5.3, 5.4, and 5.5."
FEAT_OS="**Cross-Platform**: Works consistently across Windows, macOS, and Linux."

# Determine the repository name. Use the first argument by default,
# or the directory name if the TEST environment variable is set.
repo_name="$1"
if [ -n "${TEST:-}" ]; then
  repo_name="$(basename "$PWD")"
  repo_name="${repo_name#result_}"
fi

# ── resolve_package ───────────────────────────────────────────────────────────
# Reads .package from config.json, falling back to repo_name.
resolve_package() {
  package=$(jq -r '.package // empty' "$CONFIG" 2>/dev/null)
  package="${package:-$repo_name}"
}

# ── resolve_os ────────────────────────────────────────────────────────────────
# Reads .os[] from config.json, falling back to linux, macos, and windows.
resolve_os() {
  os_list=$(jq -r '.os[]?' "$CONFIG" 2>/dev/null | xargs || true)
  if [ -z "$os_list" ]; then
    os_list="${OS[*]}"
  fi

  local os_str
  os_str=$(echo "$os_list" | sed 's/ / | /g')
  os_encoded=$(jq -rn --arg str "$os_str" '$str | @uri')
}

# ── resolve_features ──────────────────────────────────────────────────────────
# Reads .features[] from config.json and formats them as markdown bullet points.
resolve_features() {
  local features=()
  while IFS= read -r line; do
    [ -n "$line" ] && features+=("$line")
  done < <(jq -r '.features[]? // empty' "$CONFIG" 2>/dev/null)

  # Always append the default "Multiple Lua Versions" feature
  features+=("$FEAT_LUAV")

  # Always append the default "Cross-Platform" feature if all 3 OSes are present
  if [[ "$os_list" =~ "linux" ]] && [[ "$os_list" =~ "macos" ]] && [[ "$os_list" =~ "windows" ]]; then
    features+=("$FEAT_OS")
  fi

  # Format features as markdown bullet points
  features_list=""
  for f in "${features[@]}"; do
    features_list="$features_list- $f"$'\n'
  done
}

# ── resolve_desc ──────────────────────────────────────────────────────────────
# Reads .desc from config.json, falling back to a generic description.
resolve_desc() {
  desc=$(jq -r '.desc // empty' "$CONFIG" 2>/dev/null)
  desc="${desc:-$DESC}"
}

# ── resolve_usage ─────────────────────────────────────────────────────────────
# Builds the usage block with the require line and optional custom usage code.
resolve_usage() {
  local module="${repo_name//-/_}"
  local require_line="local $module = require \"$repo_name\""

  local usage_extra
  usage_extra=$(jq -r '.usage // empty' "$CONFIG" 2>/dev/null)

  # Trim leading/trailing whitespace and newlines
  usage_extra="${usage_extra#"${usage_extra%%[![:space:]]*}"}"
  usage_extra="${usage_extra%"${usage_extra##*[![:space:]]}"}"

  if [ -n "$usage_extra" ]; then
    usage_str="$require_line"$'\n\n'"$usage_extra"
  else
    usage_str="$require_line"
  fi
}

# ── escape_sed ────────────────────────────────────────────────────────────────
# Escapes special characters for safe inclusion in a sed replacement pattern.
escape_sed() {
  local val="$1"
  val="${val//\\/\\\\}"
  val="${val//\//\\/}"
  val="${val//&/\\&}"
  val="${val//$'\n'/\\n}"
  printf '%s' "$val"
}

# ── apply_template ────────────────────────────────────────────────────────────
# Replaces dynamic placeholders in README.md and formats it.
apply_template() {
  local esc_package esc_desc esc_os esc_features esc_usage esc_repo
  esc_package=$(escape_sed "$package")
  esc_desc=$(escape_sed "$desc")
  esc_os=$(escape_sed "$os_encoded")
  esc_features=$(escape_sed "$features_list")
  esc_usage=$(escape_sed "$usage_str")
  esc_repo=$(escape_sed "$repo_name")

  sed -i \
    -e "s/__PACKAGE__/$esc_package/g" \
    -e "s/__REPO__/$esc_repo/g" \
    -e "s/__PLATFORMS__/$esc_os/g" \
    -e "s/__DESC__/$esc_desc/g" \
    -e "s/__FEATURES__/$esc_features/g" \
    -e "s/__USAGE__/$esc_usage/g" \
    -e "/<!-- prettier-ignore -->/d" \
    README.md

  npx prettier --write README.md 2>/dev/null || true
}

# ── main ──────────────────────────────────────────────────────────────────────
if [ -f "README.md" ] && grep -q "__PACKAGE__" README.md && [ -f "$CONFIG" ]; then
  resolve_package
  resolve_os
  resolve_desc
  resolve_features
  resolve_usage
  apply_template
fi
