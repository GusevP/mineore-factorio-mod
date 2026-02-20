#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

VERSION=$(grep -o '"version": *"[^"]*"' info.json | grep -o '[0-9][0-9.]*' || true)
if [[ -z "$VERSION" ]]; then
  echo "Error: Could not extract version from info.json" >&2
  exit 1
fi
MOD_NAME="mineore"
FOLDER="${MOD_NAME}_${VERSION}"
ZIPFILE="${FOLDER}.zip"

echo "Packaging ${FOLDER}..."

# Clean up any previous build artifacts
rm -rf "$FOLDER" "$ZIPFILE"

# Create the mod directory structure
mkdir -p "$FOLDER"

# Copy mod files
cp info.json control.lua data.lua settings.lua changelog.txt thumbnail.png "$FOLDER/"
cp -r scripts prototypes locale graphics "$FOLDER/"

# Create the zip
zip -r "$ZIPFILE" "$FOLDER" -x "*.DS_Store" > /dev/null

# Clean up temp directory
rm -rf "$FOLDER"

SIZE=$(wc -c < "$ZIPFILE" | tr -d ' ')
echo "Created ${ZIPFILE} (${SIZE} bytes)"
