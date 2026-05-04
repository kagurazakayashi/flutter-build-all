#!/bin/bash
set -e
# Build Web with embedded fonts and custom base href
# Usage: run from your Flutter project root
# Modify --web-base-href to match your deployment path

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

echo "Building Web..."
dart run flutter_build_all:build_all --target "web" --web-embed-fonts=on --web-base-href "/" --l10n=off

echo "Done."
