#!/bin/bash
set -e
# Build desktop platforms only (windows + linux + macos)
# Usage: run from your Flutter project root

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

echo "Building desktop platforms..."
dart run flutter_build_all:build_all --target "windows,linux,macos" --l10n=off

echo "Done."
