#!/usr/bin/env bash

set -euo pipefail

# Configure Git author details
configure_git() {
  git config --global user.name "github-actions[bot]"
  git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"
}

# Copy central template files to target repository clone
sync_repository_files() {
  local clone_dir="$1"
  cp -a template/. "$clone_dir/"
}

# Resolve and write release-please version manifest
release_please() {
  # Fetch tags and resolve release version
  git fetch --tags
  local latest_tag
  latest_tag=$(git describe --tags --abbrev=0 2> /dev/null || echo "")

  local latest_version="${latest_tag#v}"
  latest_version="${latest_version:-0.0.0}"

  sed -i "s/__VERSION__/$latest_version/g" .github/release-please-manifest.json

  # Inject version-files list from config.json if defined
  if [ -f ".github/config.json" ]; then
    local version_files_json
    version_files_json=$(jq -c '.["version-files"] // empty' .github/config.json 2> /dev/null || echo "")
    if [ -n "$version_files_json" ] && [ "$version_files_json" != "[]" ]; then
      jq --argjson files "$version_files_json" \
        '.packages["."]["extra-files"] = $files' \
        .github/release-please-config.json > tmp.json &&
        mv tmp.json .github/release-please-config.json
    fi
  fi

  npx prettier --write .github/release-please-config.json
}

# Check if an operating system is enabled in config.json
has_os() {
  local os_name="$1"
  local default_val="$2"

  if [ -f ".github/config.json" ]; then
    jq -r "
      if .os then
        ([.os[] | select(. == \"$os_name\")] | length > 0)
      else
        $default_val
      end
    " .github/config.json 2> /dev/null ||
      echo "$default_val"
  else
    echo "$default_val"
  fi
}

# Parse config.json and populate OS runner inputs in ci.yml
ci_workflow() {
  # Remove inputs and parameter entries for disabled OSes
  if [ "$(has_os "linux" "true")" = "false" ]; then
    sed -i '/^[[:space:]]*test-linux:$/,/^[[:space:]]*default: __LINUX__$/d' .github/workflows/ci.yml
    sed -i '/test-linux:.*inputs\.test-linux/d' .github/workflows/ci.yml
  fi
  if [ "$(has_os "macos" "false")" = "false" ]; then
    sed -i '/^[[:space:]]*test-macos:$/,/^[[:space:]]*default: __MACOS__$/d' .github/workflows/ci.yml
    sed -i '/test-macos:.*inputs\.test-macos/d' .github/workflows/ci.yml
  fi
  if [ "$(has_os "windows" "false")" = "false" ]; then
    sed -i '/^[[:space:]]*test-windows:$/,/^[[:space:]]*default: __WINDOWS__$/d' .github/workflows/ci.yml
    sed -i '/test-windows:.*inputs\.test-windows/d' .github/workflows/ci.yml
  fi

  # Count enabled OSes
  local count=0
  local enabled_os=""
  if [ "$(has_os "linux" "true")" = "true" ]; then
    count=$((count + 1))
    enabled_os="linux"
  fi
  if [ "$(has_os "macos" "false")" = "true" ]; then
    count=$((count + 1))
    enabled_os="macos"
  fi
  if [ "$(has_os "windows" "false")" = "true" ]; then
    count=$((count + 1))
    enabled_os="windows"
  fi

  # If exactly 1 OS is enabled, rename the input definition and reference to 'test'
  if [ "$count" -eq 1 ]; then
    sed -i "s/^[[:space:]]*test-${enabled_os}:$/      test:/g" .github/workflows/ci.yml
    sed -i "s/inputs\.test-${enabled_os}/inputs\.test/g" .github/workflows/ci.yml
    sed -i 's/description: "Test on .*"/description: "Test"/g' .github/workflows/ci.yml
  fi

  # Replace remaining placeholders
  sed -i -e "s/__LINUX__/$(has_os "linux" "true")/g" \
    -e "s/__MACOS__/$(has_os "macos" "false")/g" \
    -e "s/__WINDOWS__/$(has_os "windows" "false")/g" \
    .github/workflows/ci.yml
}

# Resolve and write repository-specific rockspec from template
process_rockspec() {
  local repo_name="$1"
  local src_dir="lua"
  [ -d "src" ] && src_dir="src"

  local package_name="${repo_name}"
  if [ -f ".github/config.json" ]; then
    local config_package
    config_package=$(jq -r '.package // empty' .github/config.json 2> /dev/null || echo "")
    if [ -n "$config_package" ]; then
      package_name="$config_package"
    fi
  fi

  # Check if the target repo already has an existing custom rockspec file
  local existing_rockspec
  existing_rockspec=$(find . -maxdepth 1 -name "*.rockspec" ! -name ".rockspec" -print -quit)

  if [ -n "$existing_rockspec" ]; then
    echo "Found existing custom rockspec: $existing_rockspec. Skipping template generation."
    rm -f .rockspec # clean up the copied template file
  else
    if [ -f ".rockspec" ]; then
      sed -i -e "s/__PACKAGE__/${package_name}/g" \
        -e "s/__REPO__/${repo_name}/g" \
        -e "s/__MODULE__/${repo_name}/g" \
        -e "s/__SRC__/${src_dir}/g" \
        .rockspec
      mv .rockspec "${package_name}-scm-1.rockspec"
    fi
  fi
}

# Commit and push changes if any diffs exist
commit_and_push() {
  local repo_name="$1"
  git add -A
  if ! git diff-index --quiet HEAD; then
    git commit -m "chore: auto-sync"
    git push origin main
  else
    echo "No changes found for $repo_name. Skipping push."
  fi
}

main() {
  # Discover target repositories (active repos, excluding .github and site repos)
  # TEMPORARY: Only sync and test on the 'temp' repository
  local repos="temp"
  # local repos
  # repos=$(gh repo list BlueLua \
  #   --limit 1000 \
  #   --json name,isArchived \
  #   -q '.[] | select(.isArchived == false and .name != ".github" and .name != "bluelua.github.io") | .name')

  configure_git

  for r in $repos; do
    echo "=== Syncing repository: $r ==="
    local clone_dir="/tmp/$r"
    rm -rf "$clone_dir"

    # Clone using the PAT token
    git clone "https://x-access-token:${GH_TOKEN}@github.com/BlueLua/$r.git" "$clone_dir"

    # Copy template files
    sync_repository_files "$clone_dir"

    cd "$clone_dir"

    # Process configurations and workflows
    process_rockspec "$r"
    release_please
    ci_workflow

    # Commit & push changes
    commit_and_push "$r"

    # Clean up local clone
    cd "$GITHUB_WORKSPACE"
    rm -rf "$clone_dir"
  done
}

main "$@"
