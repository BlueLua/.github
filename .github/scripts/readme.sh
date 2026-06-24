#!/usr/bin/env bash

# This script auto-generates README.md based on template/README.md and config.json.

set -euo pipefail

repo_name="$1"
if [ -z "$repo_name" ] || [ "$repo_name" = "src" ] || [ "$repo_name" = "lua" ]; then
  repo_name="$(basename "$PWD")"
fi

CONFIG=".github/config.json"

# ── resolve_package ───────────────────────────────────────────────────────────
# Reads .package from config.json, falls back to repo_name.
# Sets: $package, $lua_var
resolve_package() {
  package=$(jq -r '.package // empty' "$CONFIG" 2> /dev/null)
  package="${package:-$repo_name}"
  lua_var="${package//-/_}"
}

# ── resolve_os ────────────────────────────────────────────────────────────────
# Reads .os[] from config.json, falls back to all three platforms.
# Sets: $os_list (array), $os_encoded (URL-encoded for Shields.io badge)
resolve_os() {
  os_list=()
  while IFS= read -r line; do
    [ -n "$line" ] && os_list+=("$line")
  done < <(jq -r '.os[]? // empty' "$CONFIG" 2> /dev/null)

  if [ ${#os_list[@]} -eq 0 ]; then
    os_list=("linux" "macos" "windows")
  fi

  local os_str=""
  for os in "${os_list[@]}"; do
    if [ -z "$os_str" ]; then
      os_str="$os"
    else
      os_str="$os_str | $os"
    fi
  done
  os_encoded=$(jq -rn --arg str "$os_str" '$str | @uri')
}


# ── resolve_features ──────────────────────────────────────────────────────────
# Reads .features[] from config.json (always an array).
# Appends default "Multiple Lua Versions" and "Cross-Platform" entries.
# Sets: $features_list (formatted markdown bullet string)
resolve_features() {
  local features=()
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] && features+=("$line")
  done < <(jq -r '.features[]? // empty' "$CONFIG" 2> /dev/null)

  # Default: Multiple Lua Versions
  local has_lua="false"
  for f in "${features[@]+"${features[@]}"}"; do
    [[ "$f" == *"Multiple Lua Versions"* ]] && has_lua="true" && break
  done
  if [ "$has_lua" = "false" ]; then
    features+=("**Multiple Lua Versions**: Compatible with LuaJIT, Lua 5.1, 5.2, 5.3, 5.4, and 5.5.")
  fi

  # Default: Cross-Platform (only when all 3 OSes are present)
  local has_linux="false" has_macos="false" has_windows="false"
  for os in "${os_list[@]}"; do
    local os_lower
    os_lower=$(echo "$os" | tr '[:upper:]' '[:lower:]')
    [ "$os_lower" = "linux" ] && has_linux="true"
    [ "$os_lower" = "macos" ] && has_macos="true"
    [ "$os_lower" = "windows" ] && has_windows="true"
  done

  if [ "$has_linux" = "true" ] && [ "$has_macos" = "true" ] && [ "$has_windows" = "true" ]; then
    local has_cross="false"
    for f in "${features[@]+"${features[@]}"}"; do
      [[ "$f" == *"Cross-Platform"* ]] && has_cross="true" && break
    done
    if [ "$has_cross" = "false" ]; then
      features+=("**Cross-Platform**: Works consistently across Windows, macOS, and Linux.")
    fi
  fi

  # Format as markdown bullets
  features_list=""
  for f in "${features[@]+"${features[@]}"}"; do
    features_list="$features_list- $f"$'\n'
  done
}

# ── resolve_desc ──────────────────────────────────────────────────────────────
# Reads .desc from config.json, falls back to a generic string.
# Sets: $desc
resolve_desc() {
  desc=$(jq -r '.desc // empty' "$CONFIG" 2> /dev/null)
  desc="${desc:-Lua library.}"
}

# ── resolve_usage ─────────────────────────────────────────────────────────────
# Builds the usage block: always starts with the require statement, followed
# by a blank line and the extra usage content from config.json (if any).
# Sets: $usage_str
resolve_usage() {
  local module="$repo_name"
  local require_line="local $module = require \"$module\""

  local usage_raw
  usage_raw=$(jq -r '.usage // empty' "$CONFIG" 2> /dev/null)

  local usage_extra=""
  if [ -n "$usage_raw" ]; then
    local usage_lines=()
    while IFS= read -r line; do
      usage_lines+=("$line")
    done <<< "$usage_raw"

    for line in "${usage_lines[@]}"; do
      if [ -z "$usage_extra" ]; then
        usage_extra="$line"
      else
        usage_extra="$usage_extra"$'\n'"$line"
      fi
    done

    usage_extra="${usage_extra#"${usage_extra%%[![:space:]]*}"}"
    usage_extra="${usage_extra%"${usage_extra##*[![:space:]]}"}"
  fi

  if [ -n "$usage_extra" ]; then
    usage_str="$require_line"$'\n\n'"$usage_extra"
  else
    usage_str="$require_line"
  fi
}

# ── escape_sed ────────────────────────────────────────────────────────────────
# Escapes a string for safe use as a sed replacement value.
escape_sed() {
  local val="$1"
  val="${val//\\/\\\\}"
  val="${val//\//\\/}"
  val="${val//&/\\&}"
  val="${val//$'\n'/\\n}"
  printf '%s' "$val"
}

# ── apply_template ────────────────────────────────────────────────────────────
# Substitutes all __PLACEHOLDER__ tokens in README.md, strips prettier-ignore
# guards, then runs prettier to format the final output.
apply_template() {
  local esc_package esc_desc esc_os esc_features esc_usage
  esc_package=$(escape_sed "$package")
  esc_desc=$(escape_sed "$desc")
  esc_os=$(escape_sed "$os_encoded")
  esc_features=$(escape_sed "$features_list")
  esc_usage=$(escape_sed "$usage_str")

  sed -i \
    -e "s/__PACKAGE__/$esc_package/g" \
    -e "s/__PLATFORMS__/$esc_os/g" \
    -e "s/__DESC__/$esc_desc/g" \
    -e "s/__FEATURES__/$esc_features/g" \
    -e "s/__USAGE__/$esc_usage/g" \
    -e "/<!-- prettier-ignore -->/d" \
    README.md

  npx prettier --write README.md 2> /dev/null || true
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
