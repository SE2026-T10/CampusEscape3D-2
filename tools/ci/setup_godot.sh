#!/usr/bin/env bash
# Downloads the official Godot build and the Windows x64 export templates,
# checks both against the SHA-512 sums published with the release, and
# installs the templates where Godot looks for them.
#
#   GODOT_VERSION  default 4.7.2 (the "-stable" release)
#   GODOT_DIR      default ~/godot (cache this folder between CI runs)
#
# Prints the path of the Godot executable on the last line and, on GitHub
# Actions, also writes GODOT=<path> to $GITHUB_ENV.
set -euo pipefail

VERSION="${GODOT_VERSION:-4.7.2}"
DIR="${GODOT_DIR:-$HOME/godot}"
BASE="https://github.com/godotengine/godot-builds/releases/download/${VERSION}-stable"
EDITOR_ZIP="Godot_v${VERSION}-stable_linux.x86_64.zip"
EDITOR_BIN="$DIR/Godot_v${VERSION}-stable_linux.x86_64"
TEMPLATES_TPZ="Godot_v${VERSION}-stable_export_templates.tpz"
TEMPLATE_FILES=(version.txt windows_release_x86_64.exe windows_debug_x86_64.exe
                windows_release_x86_64_console.exe windows_debug_x86_64_console.exe)
TEMPLATE_CACHE="$DIR/templates"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${VERSION}.stable"

mkdir -p "$DIR" "$TEMPLATE_CACHE" "$TEMPLATE_DIR"
curl -fsSL --retry 3 -o "$DIR/SHA512-SUMS.txt" "$BASE/SHA512-SUMS.txt"

verify() {  # verify <file name in the sums list> <local path>
  local expected
  expected="$(awk -v f="$1" '$2 == f { print $1 }' "$DIR/SHA512-SUMS.txt")"
  if [ -z "$expected" ]; then echo "No published checksum for $1" >&2; exit 1; fi
  echo "$expected  $2" | sha512sum -c - >&2
}

if [ ! -x "$EDITOR_BIN" ]; then
  echo "Downloading $EDITOR_ZIP" >&2
  curl -fsSL --retry 3 -o "$DIR/$EDITOR_ZIP" "$BASE/$EDITOR_ZIP"
  verify "$EDITOR_ZIP" "$DIR/$EDITOR_ZIP"
  unzip -o -q "$DIR/$EDITOR_ZIP" -d "$DIR"
  rm "$DIR/$EDITOR_ZIP"
  chmod +x "$EDITOR_BIN"
fi

missing=0
for f in "${TEMPLATE_FILES[@]}"; do [ -s "$TEMPLATE_CACHE/$f" ] || missing=1; done
if [ "$missing" = 1 ]; then
  echo "Downloading $TEMPLATES_TPZ (about 1.3 GB; only the Windows x64 templates are kept)" >&2
  tmp="$(mktemp -d)"
  curl -fsSL --retry 3 -o "$tmp/$TEMPLATES_TPZ" "$BASE/$TEMPLATES_TPZ"
  verify "$TEMPLATES_TPZ" "$tmp/$TEMPLATES_TPZ"
  for f in "${TEMPLATE_FILES[@]}"; do
    unzip -o -q -j "$tmp/$TEMPLATES_TPZ" "templates/$f" -d "$TEMPLATE_CACHE"
  done
  rm -rf "$tmp"
fi
cp "$TEMPLATE_CACHE"/* "$TEMPLATE_DIR"/
if [ "$(cat "$TEMPLATE_DIR/version.txt")" != "${VERSION}.stable" ]; then
  echo "Export templates are for $(cat "$TEMPLATE_DIR/version.txt"), not ${VERSION}.stable" >&2; exit 1
fi

"$EDITOR_BIN" --headless --version >&2
if [ -n "${GITHUB_ENV:-}" ]; then echo "GODOT=$EDITOR_BIN" >> "$GITHUB_ENV"; fi
echo "$EDITOR_BIN"
