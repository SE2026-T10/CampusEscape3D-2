#!/usr/bin/env bash
# Exports the Windows x64 release build with the "Windows Desktop" preset and
# packs it into dist/CampusEscape3D-<version>-windows-x64.zip.
# Run tools/ci/validate.sh first (it imports the project). Logs go to ci-logs/.
set -euo pipefail
: "${GODOT:?Set GODOT to the Godot executable}"
mkdir -p ci-logs

version="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
name="CampusEscape3D-${version}-windows-x64"
rm -rf build dist
mkdir -p build dist

set +e
timeout 900 "$GODOT" --headless --path . --export-release "Windows Desktop" build/CampusEscape3D.exe > ci-logs/export.log 2>&1
status=$?
set -e
if [ "$status" -ne 0 ]; then echo "::error::Export failed (exit $status)"; tail -n 60 ci-logs/export.log; exit 1; fi
if grep -E "^ERROR|SCRIPT ERROR" ci-logs/export.log; then echo "::error::Errors during export (ci-logs/export.log)"; exit 1; fi

# The build must contain a Windows executable and a pack with the game in it,
# and none of the tests or tools.
[ -s build/CampusEscape3D.exe ] || { echo "::error::No executable exported"; exit 1; }
[ -s build/CampusEscape3D.pck ] || { echo "::error::No .pck exported"; exit 1; }
head -c 2 build/CampusEscape3D.exe | grep -q "MZ" || { echo "::error::The executable is not a Windows program"; exit 1; }
# (The pack's file index stores paths without "res://"; exported scenes appear as <path>.remap.)
for needed in project.binary scenes/ui/main_menu.tscn.remap scenes/level/library_graybox.tscn.remap \
              scenes/level/expanded_library.tscn.remap \
              scenes/npc/guard.tscn.remap scenes/player/player.tscn.remap; do
  grep -aq "$needed" build/CampusEscape3D.pck || { echo "::error::$needed is missing from the pack"; exit 1; }
done
if grep -aqE "(^|[^a-z_])(tests|tools)/[a-z_]+\.gd" build/CampusEscape3D.pck; then
  echo "::error::Tests or tools were exported into the pack"; exit 1
fi

{
  echo "Campus Escape 3D $version (Windows x64)"
  echo "Commit: ${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
  echo "Built: $(date -u +%Y-%m-%dT%H:%M:%SZ) with $("$GODOT" --headless --version | tail -n 1)"
  echo
  echo "Run CampusEscape3D.exe (keep CampusEscape3D.pck next to it)."
  echo "Controls: WASD move, Shift sprint, C/Ctrl crouch, E use, mouse look, Esc pause."
} > build/README.txt

mkdir -p "dist/$name"
cp build/CampusEscape3D.exe build/CampusEscape3D.pck build/README.txt "dist/$name/"
(cd dist && zip -q -r "$name.zip" "$name")
ls -l build "dist/$name.zip"
echo "EXPORT PASSED: dist/$name.zip"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "name=$name" >> "$GITHUB_OUTPUT"
  echo "version=$version" >> "$GITHUB_OUTPUT"
fi
