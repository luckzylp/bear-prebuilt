#!/bin/bash
# Patch build.rs for Linux deployment
# This script modifies the default wrapper and preload paths for Linux installation

set -e

BUILD_RS_PATH="Bear/bear/build.rs"

echo "================================================"
echo "Patching build.rs for Linux deployment"
echo "================================================"

if [ ! -f "${BUILD_RS_PATH}" ]; then
    echo "Error: build.rs not found at ${BUILD_RS_PATH}"
    exit 1
fi

# Backup original file
cp "${BUILD_RS_PATH}" "${BUILD_RS_PATH}.bak"
echo "✓ Backed up original build.rs"

# Apply Linux-specific patches
# Change 1: const DEFAULT_WRAPPER_PATH: &str = "/usr/local/libexec/bear";
# To:       const DEFAULT_WRAPPER_PATH: &str = "/usr/$LIB/bear";
#
# Change 2: const DEFAULT_PRELOAD_PATH: &str = "/usr/local/libexec/bear/$LIB";
# To:       const DEFAULT_PRELOAD_PATH: &str = "/usr/$LIB/bear";

# Use sed with backup extension (works on both Linux and macOS)
if sed --version &>/dev/null; then
    # GNU sed (Linux)
    sed -i \
      -e 's|/usr/local/libexec/bear|/usr/$LIB/bear|g' \
      "${BUILD_RS_PATH}"
else
    # BSD sed (macOS)
    sed -i '' \
      -e 's|/usr/local/libexec/bear|/usr/$LIB/bear|g' \
      "${BUILD_RS_PATH}"
fi

echo "✓ Applied Linux patches"

# Verify the changes
echo ""
echo "Changes applied:"
echo "----------------"
grep "DEFAULT_WRAPPER_PATH\|DEFAULT_PRELOAD_PATH" "${BUILD_RS_PATH}" || true

echo ""
echo "✓ Linux patch completed successfully!"
