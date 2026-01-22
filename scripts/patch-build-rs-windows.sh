#!/bin/bash
# Patch build.rs for Windows deployment
# This script modifies the default wrapper path for Windows installation

set -e

BUILD_RS_PATH="Bear/bear/build.rs"

echo "================================================"
echo "Patching build.rs for Windows deployment"
echo "================================================"

if [ ! -f "${BUILD_RS_PATH}" ]; then
    echo "Error: build.rs not found at ${BUILD_RS_PATH}"
    exit 1
fi

# Backup original file
cp "${BUILD_RS_PATH}" "${BUILD_RS_PATH}.bak"
echo "✓ Backed up original build.rs"

# Apply Windows-specific patch
# Change: const DEFAULT_WRAPPER_PATH: &str = "/usr/local/libexec/bear";
# To:     const DEFAULT_WRAPPER_PATH: &str = "C:/Program Files/Bear";
sed -i 's|/usr/local/libexec/bear|C:/Program Files/Bear|g' "${BUILD_RS_PATH}"

echo "✓ Applied Windows patches"

# Verify the changes
echo ""
echo "Changes applied:"
echo "----------------"
grep "DEFAULT_WRAPPER_PATH" "${BUILD_RS_PATH}" || true

echo ""
echo "✓ Windows patch completed successfully!"
