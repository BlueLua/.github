#!/usr/bin/env bash

set -euo pipefail

# Configure Git author details
configure_git() {
  git config --global user.name "github-actions[bot]"
  git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"
}

# Helper to perform in-place regex replacement in a file
replace_in_file() {
  local file="$1"
  shift
  while [ "$#" -gt 0 ]; do
    sed -i "s|$1|$2|g" "$file"
    shift 2
  done
}

# Copy central template files to target repository clone
sync_repository_files() {
  local clone_dir="$1"
  local repo_name="$2"

  # List of files to preserve if they already exist in the target repository
  local preserve_files=(
    ".github/config.json"
    "CHANGELOG.md"
  )

  # Backup files
  for file in "${preserve_files[@]}"; do
    if [ -f "$clone_dir/$file" ]; then
      mv "$clone_dir/$file" "$clone_dir/${file}.bak"
    fi
  done

  cp -a template/. "$clone_dir/"

  # If the target repo didn't have config.json, populate the template package name and repo name
  if [ ! -f "$clone_dir/.github/config.json.bak" ]; then
    replace_in_file "$clone_dir/.github/config.json" \
      "__PACKAGE__" "${repo_name}" \
      "__REPO__" "${repo_name}"
  fi

  # Restore files
  for file in "${preserve_files[@]}"; do
    if [ -f "$clone_dir/${file}.bak" ]; then
      rm -f "$clone_dir/$file"
      mv "$clone_dir/${file}.bak" "$clone_dir/$file"
    fi
  done
}

# Resolve and write release-please version manifest
release_please() {
  # Fetch tags and resolve release version if inside a git repository
  local latest_tag=""
  if git rev-parse --is-inside-work-tree &> /dev/null; then
    git fetch --tags || true
    latest_tag=$(git describe --tags --abbrev=0 2> /dev/null || echo "")
  fi

  local latest_version="${latest_tag#v}"
  latest_version="${latest_version:-0.0.0}"

  replace_in_file .github/release-please-manifest.json "__VERSION__" "$latest_version"

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

# Parse config.json and populate OS matrix in test.yml
test_workflow() {
  local test_yml=".github/workflows/test.yml"
  if [ -f "$test_yml" ]; then
    # Fetch raw OS list from config.json
    local raw_os
    raw_os=$(jq -r '.os[]?' .github/config.json 2>/dev/null | xargs || true)

    # Fallback to all three OSes if empty/null
    if [ -z "$raw_os" ]; then
      raw_os="linux macos windows"
    fi

    # Map raw OS values to GitHub runner names
    local os_list=""
    for os in $raw_os; do
      case "$os" in
        linux) os_list="$os_list, \"ubuntu-latest\"" ;;
        macos) os_list="$os_list, \"macos-latest\"" ;;
        windows) os_list="$os_list, \"windows-latest\"" ;;
      esac
    done

    # Format as JSON array string: ["ubuntu-latest", "macos-latest"]
    os_list="[${os_list#, }]"

    # Fallback if no runner was mapped
    if [ "$os_list" = "[]" ]; then
      os_list='["ubuntu-latest"]'
    fi

    replace_in_file "$test_yml" '\["__OS_LIST__"\]' "$os_list"
  fi
}

# Resolve and write dynamic links in CONTRIBUTING.md
contributing_md() {
  local repo_name="$1"
  if [ -f "CONTRIBUTING.md" ]; then
    local package_name
    package_name=$(jq -r '.package // empty' .github/config.json 2>/dev/null || echo "")
    package_name="${package_name:-$repo_name}"

    replace_in_file CONTRIBUTING.md \
      "__REPO__" "${repo_name}" \
      "__PACKAGE__" "${package_name}"

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
  test_workflow
  bash "$script_dir/readme.sh" "$repo_name"
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
