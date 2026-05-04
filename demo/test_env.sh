#!/bin/bash
set -e
# Test the build environment without performing a build
# Usage: run from your Flutter project root

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

echo "Testing build environment..."
dart run flutter_build_all:build_all --test

echo "Done."
