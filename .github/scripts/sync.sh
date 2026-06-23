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
  local repo_name="$2"

  local has_config="false"
  if [ -f "$clone_dir/.github/config.json" ]; then
    has_config="true"
    mv "$clone_dir/.github/config.json" "$clone_dir/.github/config.json.bak"
  fi

  cp -a template/. "$clone_dir/"

  if [ "$has_config" = "true" ]; then
    mv "$clone_dir/.github/config.json.bak" "$clone_dir/.github/config.json"
  else
    # If the target repo didn't have config.json, populate the template package name with repo_name
    sed -i "s/__PACKAGE__/${repo_name}/g" "$clone_dir/.github/config.json"
  fi
}

# Resolve and write release-please version manifest
release_please() {
  # Fetch tags and resolve release version if inside a git repository
  local latest_tag=""
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    git fetch --tags || true
    latest_tag=$(git describe --tags --abbrev=0 2> /dev/null || echo "")
  fi

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
    sed -i '/^[[:space:]]*test-linux:$/,/^[[:space:]]*default: false$/d' .github/workflows/ci.yml
    sed -i '/test-linux:.*inputs\.test-linux/d' .github/workflows/ci.yml
  fi
  if [ "$(has_os "macos" "true")" = "false" ]; then
    sed -i '/^[[:space:]]*test-macos:$/,/^[[:space:]]*default: false$/d' .github/workflows/ci.yml
    sed -i '/test-macos:.*inputs\.test-macos/d' .github/workflows/ci.yml
  fi
  if [ "$(has_os "windows" "true")" = "false" ]; then
    sed -i '/^[[:space:]]*test-windows:$/,/^[[:space:]]*default: false$/d' .github/workflows/ci.yml
    sed -i '/test-windows:.*inputs\.test-windows/d' .github/workflows/ci.yml
  fi

  # Count enabled OSes
  local count=0
  local enabled_os=""
  if [ "$(has_os "linux" "true")" = "true" ]; then
    count=$((count + 1))
    enabled_os="linux"
  fi
  if [ "$(has_os "macos" "true")" = "true" ]; then
    count=$((count + 1))
    enabled_os="macos"
  fi
  if [ "$(has_os "windows" "true")" = "true" ]; then
    count=$((count + 1))
    enabled_os="windows"
  fi

  # If exactly 1 OS is enabled, rename the input definition and reference to 'test'
  if [ "$count" -eq 1 ]; then
    sed -i "s/^[[:space:]]*test-${enabled_os}:$/      test:/g" .github/workflows/ci.yml
    sed -i "s/inputs\.test-${enabled_os}/inputs\.test/g" .github/workflows/ci.yml
    sed -i 's/description: "Test on .*"/description: "Test"/g' .github/workflows/ci.yml
  fi

  # Replace with: placeholders with actual enabled values
  sed -i -e "s/__LINUX__/$(has_os "linux" "true")/g" \
    -e "s/__MACOS__/$(has_os "macos" "true")/g" \
    -e "s/__WINDOWS__/$(has_os "windows" "true")/g" \
    .github/workflows/ci.yml
}

# Parse config.json and populate OS matrix in test.yml
test_workflow() {
  if [ -f .github/workflows/test.yml ]; then
    local os_list=""
    [ "$(has_os "linux" "true")" = "true" ] && os_list="$os_list, \"ubuntu-latest\""
    [ "$(has_os "macos" "true")" = "true" ] && os_list="$os_list, \"macos-latest\""
    [ "$(has_os "windows" "true")" = "true" ] && os_list="$os_list, \"windows-latest\""
    os_list="[${os_list#, }]"

    # If no OS is enabled, fallback to ubuntu-latest
    [ "$os_list" = "[]" ] && os_list='["ubuntu-latest"]'

    sed -i "s/\[\"__OS_LIST__\"\]/$os_list/g" .github/workflows/test.yml
  fi
}


# Resolve and write dynamic links in CONTRIBUTING.md
contributing_md() {
  local repo_name="$1"
  if [ -f "CONTRIBUTING.md" ]; then
    local package_name="${repo_name}"
    if [ -f ".github/config.json" ]; then
      local config_package
      config_package=$(jq -r '.package // empty' .github/config.json 2> /dev/null || echo "")
      if [ -n "$config_package" ]; then
        package_name="$config_package"
      fi
    fi
    sed -i -e "s/__REPO__/${repo_name}/g" \
      -e "s/__PACKAGE__/${package_name}/g" \
      CONTRIBUTING.md

    npx prettier --write CONTRIBUTING.md
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

# Core file sync and processing logic for a repository directory
sync_directory() {
  local target_dir="$1"
  local repo_name="$2"
  local script_dir="$3"

  # Copy template files
  sync_repository_files "$target_dir" "$repo_name"

  cd "$target_dir"

  # Process configurations and workflows
  bash "$script_dir/rockspec.sh" "$repo_name"
  release_please
  ci_workflow
  test_workflow
  contributing_md "$repo_name"
}

main() {
  local script_dir
  script_dir=$(cd "$(dirname "$0")" && pwd)

  # Discover target repositories (active repos, excluding .github and site repos)
  local repos
  repos=$(gh repo list BlueLua \
    --limit 1000 \
    --json name,isArchived \
    -q '.[] | select(.isArchived == false and .name != ".github" and .name != "bluelua.github.io") | .name')

  configure_git

  for r in $repos; do
    echo "=== Syncing repository: $r ==="
    local clone_dir="/tmp/$r"
    rm -rf "$clone_dir"

    # Clone using the PAT token
    git clone "https://x-access-token:${GH_TOKEN}@github.com/BlueLua/$r.git" "$clone_dir"

    # Sync and process the repository files
    sync_directory "$clone_dir" "$r" "$script_dir"

    # Commit & push changes
    cd "$clone_dir"
    commit_and_push "$r"

    # Clean up local clone
    cd "$GITHUB_WORKSPACE"
    rm -rf "$clone_dir"
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
