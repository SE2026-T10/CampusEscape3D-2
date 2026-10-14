#!/usr/bin/env bash
# Validates the project with the official Godot build ($GODOT):
#   1. the engine is exactly Godot 4.7.2 stable (official)
#   2. the project imports with no script or resource errors
#   3. every script compiles (tools/ci/check_scripts.gd)
#   4. the project version is set, the Windows preset's file and product
#      versions match it (X.Y.Z.0), and on a tag build the tag is vX.Y.Z
# Exits non-zero on the first failure. Logs go to ci-logs/.
set -euo pipefail
: "${GODOT:?Set GODOT to the Godot executable (tools/ci/setup_godot.sh prints it)}"
mkdir -p ci-logs

version="$("$GODOT" --headless --version | tail -n 1)"
echo "Godot: $version"
case "$version" in
  4.7.2.stable.official.*) ;;
  *) echo "::error::Expected Godot 4.7.2.stable.official, got $version"; exit 1 ;;
esac

echo "Importing the project"
timeout 600 "$GODOT" --headless --path . --editor --quit > ci-logs/import.log 2>&1 || {
  echo "::error::Project import failed"; tail -n 50 ci-logs/import.log; exit 1; }
if grep -E "SCRIPT ERROR|Parse Error|Failed loading resource|Failed to load" ci-logs/import.log; then
  echo "::error::Errors while importing the project (ci-logs/import.log)"; exit 1
fi

echo "Compiling every script"
timeout 300 "$GODOT" --headless --path . --script res://tools/ci/check_scripts.gd > ci-logs/check_scripts.log 2>&1 || {
  echo "::error::A script does not compile"; cat ci-logs/check_scripts.log; exit 1; }
grep "CHECK SCRIPTS PASSED" ci-logs/check_scripts.log

project_version="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
if [ -z "$project_version" ]; then echo "::error::application/config/version is not set in project.godot"; exit 1; fi
echo "Project version: $project_version"
for key in file_version product_version; do
  preset="$(sed -n "s/^application\/$key=\"\(.*\)\"/\1/p" export_presets.cfg)"
  if [ "$preset" != "$project_version.0" ]; then
    echo "::error::export_presets.cfg application/$key is '$preset', expected '$project_version.0'"; exit 1
  fi
done
if [[ "${GITHUB_REF:-}" == refs/tags/v* ]]; then
  tag="${GITHUB_REF#refs/tags/}"
  if [ "$tag" != "v$project_version" ]; then
    echo "::error::Tag $tag does not match the project version v$project_version"; exit 1
  fi
fi
echo "VALIDATION PASSED"
