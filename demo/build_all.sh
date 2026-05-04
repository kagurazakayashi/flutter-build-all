#!/bin/bash
set -e
# Build all available platforms with default options
# Usage: run from your Flutter project root

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

echo "Building all platforms..."
dart run flutter_build_all:build_all

echo "Done."
