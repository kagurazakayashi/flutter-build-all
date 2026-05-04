#!/bin/bash
set -e
# Build all platforms in parallel
# Usage: run from your Flutter project root

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

echo "Building all platforms in parallel..."
dart run flutter_build_all:build_all --jobs 0 --l10n=off --analyze=off

echo "Done."
