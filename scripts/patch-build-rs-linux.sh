#!/bin/bash
# Patch build.rs for Linux deployment
# This script is a no-op since we use the default paths from Bear's official build guide
# Default paths: /usr/local/libexec/bear for wrapper and /usr/local/libexec/bear/$LIB for preload

set -e

BUILD_RS_PATH="Bear/bear/build.rs"

echo "================================================"
echo "Using default paths from Bear build guide"
echo "================================================"
echo ""
echo "Default paths (as per install.md):"
echo "  - Wrapper: /usr/local/libexec/bear"
echo "  - Preload: /usr/local/libexec/bear/\$LIB"
echo ""
echo "No patching required - using official defaults."
