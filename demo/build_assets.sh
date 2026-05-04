#!/bin/bash
set -e
# Build assets only: l10n and app icons (no platform build)
# Usage: run from your Flutter project root
# Requires: icon source files in ico/ directory (ico/iconf.png, ico/iconb.png)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Building assets..."
cd "$PROJECT_DIR"
flutter gen-l10n

cd "$PROJECT_DIR/flutter-icon-creator"
dart run flutter_icon_creator:flutter_icon_creator -f "$PROJECT_DIR" -i "$PROJECT_DIR/ico/iconf.png" -b "$PROJECT_DIR/ico/iconb.png"

echo "Done."
