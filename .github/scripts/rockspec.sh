#!/usr/bin/env bash

# This script auto-generates the build.modules block in the template .rockspec
# based on files in the source directory.

set -euo pipefail

repo_name="${1:-}"
if [ -n "${TEST:-}" ]; then
  repo_name="$(basename "$PWD")"
  repo_name="${repo_name#result_}"
fi
src_dir="lua"
[ -d "src" ] && src_dir="src"

package_name="${repo_name}"
if [ -f ".github/config.json" ]; then
  config_package=$(jq -r '.package // empty' .github/config.json 2> /dev/null || echo "")
  if [ -n "$config_package" ]; then
    package_name="$config_package"
  fi
fi

# Clean up any existing generated rockspecs to prevent duplicates
rm -f *-scm-1.rockspec

if [ ! -f ".rockspec" ]; then
  echo "Error: .rockspec template file not found in root directory!" >&2
  exit 1
fi

# Generate the modules block
modules_list=""
if [ -d "$src_dir" ]; then
  # Find all .lua files (excluding .d.lua) in src_dir and construct module entries
  lua_files=()
  while IFS= read -r -d '' filepath; do
    lua_files+=("$filepath")
  done < <(find "$src_dir" -type f -name "*.lua" ! -name "*.d.lua" -print0 | sort -z)

  for filepath in "${lua_files[@]}"; do
    # Get relative path by stripping the src_dir prefix (e.g. src/myrepo/foo.lua -> myrepo/foo.lua)
    relpath="${filepath#$src_dir/}"
    # Strip extension (.lua)
    mod_path="${relpath%.lua}"
    # Strip trailing /init if present
    mod_name=""
    if [[ "$mod_path" == */init ]]; then
      mod_name="${mod_path%/init}"
    elif [[ "$mod_path" == "init" ]]; then
      mod_name="init"
    else
      mod_name="$mod_path"
    fi
    # Replace "/" with "." to form the module name
    mod_name="${mod_name//\//.}"

    # Add to modules_list with correct indentation
    modules_list="${modules_list}    [\"${mod_name}\"] = \"${filepath}\",\n"
  done

  # Find all .c files in src_dir
  c_files=()
  while IFS= read -r -d '' filepath; do
    c_files+=("$filepath")
  done < <(find "$src_dir" -type f -name "*.c" -print0 | sort -z)

  # Group all C source files into a single module if they exist
  if [ ${#c_files[@]} -gt 0 ]; then
    # If there are Lua wrapper files, we name the C module "<package>._core".
    # Otherwise, it must be the package entrypoint itself, so we name it "<package>".
    c_module_name="${repo_name}"
    if [ ${#lua_files[@]} -gt 0 ]; then
      c_module_name="${repo_name}._core"
    fi

    modules_list="${modules_list}[\"${c_module_name}\"] = {\nsources = {\n"
    for c_file in "${c_files[@]}"; do
      modules_list="${modules_list}\"${c_file}\",\n"
    done
    modules_list="${modules_list}},\n},\n"
  fi
fi

if [ -d "types" ]; then
  # Find all .d.lua files in types directory
  while IFS= read -r -d '' filepath; do
    # Get relative path (e.g. types/evdev.d.lua -> evdev.d.lua)
    relpath="${filepath#types/}"
    # Strip .d.lua extension
    mod_name="${relpath%.d.lua}"

    # Add to modules_list with correct indentation
    modules_list="${modules_list}    [\"${repo_name}.types/${mod_name}\"] = \"${filepath}\",\n"
  done < <(find "types" -name "*.d.lua" -print0 | sort -z)
fi

# Trim trailing newline from modules_list
# shellcheck disable=SC2059
modules_list=$(printf "%b" "$modules_list")

# Replace package and repo placeholders in template .rockspec
sed -i -e "s/__PACKAGE__/${package_name}/g" \
  -e "s/__REPO__/${repo_name}/g" \
  .rockspec

# Replace the __MODULES__ placeholder with the generated modules list
awk -v r="$modules_list" '{gsub(/__MODULES__/, r)}1' .rockspec > .rockspec.tmp && mv .rockspec.tmp .rockspec

# Generate the bin block if a bin file named after the repository exists
bin_block=""
if [ -d "bin" ] && [ -f "bin/${repo_name}" ]; then
  bin_block="install = {\n    bin = {\n      [\"${repo_name}\"] = \"bin/${repo_name}\"\n    }\n  }"
fi

# Replace the __BIN__ placeholder
awk -v r="$bin_block" '{gsub(/__BIN__/, r)}1' .rockspec > .rockspec.tmp && mv .rockspec.tmp .rockspec

# Generate the dependencies list if present in config.json
dependencies_list=""
if [ -f ".github/config.json" ]; then
  dependencies_json=$(jq -r '.dependencies[]?' .github/config.json 2>/dev/null || true)
  if [ -n "$dependencies_json" ]; then
    while IFS= read -r dep; do
      [ -n "$dep" ] && dependencies_list="${dependencies_list}  \"${dep}\",\n"
    done <<< "$dependencies_json"
  fi
fi

# Replace the __DEPENDENCIES__ placeholder
awk -v r="$dependencies_list" '{gsub(/__DEPENDENCIES__/, r)}1' .rockspec > .rockspec.tmp && mv .rockspec.tmp .rockspec

mv .rockspec "${package_name}-scm-1.rockspec"

# Format the generated rockspec file using StyLua if available
if command -v stylua &> /dev/null; then
  stylua "${package_name}-scm-1.rockspec"
elif command -v npx &> /dev/null; then
  npx -y @johnnymorganz/stylua-bin "${package_name}-scm-1.rockspec"
fi

# Validate the generated rockspec if LuaRocks is installed locally
if command -v luarocks &> /dev/null; then
  echo "Validating generated rockspec..."
  luarocks lint "${package_name}-scm-1.rockspec"
  echo "Rockspec successfully validated!"
fi
