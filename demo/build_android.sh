#!/bin/bash
set -e
# Build Android APK
# Usage: run from your Flutter project root

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

echo "Building Android..."
dart run flutter_build_all:build_all --target "android" --l10n=off

echo "Done."
