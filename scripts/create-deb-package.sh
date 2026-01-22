#!/bin/bash
# Create Debian package for Bear with multilib support (x86 on x64)
# This script builds a .deb package for Ubuntu/Debian systems

set -e

VERSION="${1:-0.0.0}"
TARGET_TRIPLE="${2:-x86_64-unknown-linux-gnu}"

echo "================================================"
echo "Creating Bear Debian Package (with multilib)"
echo "Version: $VERSION"
echo "Target: $TARGET_TRIPLE"
echo "================================================"

# Determine architecture for .deb package
case "$TARGET_TRIPLE" in
    x86_64*|*x86-64*)
        DEB_ARCH="amd64"
        MULTILIB_SUPPORT=true
        ;;
    aarch64*|*arm64*)
        DEB_ARCH="arm64"
        MULTILIB_SUPPORT=false
        ;;
    armv7*|*armhf*)
        DEB_ARCH="armhf"
        MULTILIB_SUPPORT=false
        ;;
    i686*|*i386*)
        DEB_ARCH="i386"
        MULTILIB_SUPPORT=false
        ;;
    *)
        echo "Warning: Unknown architecture for $TARGET_TRIPLE, using amd64"
        DEB_ARCH="amd64"
        MULTILIB_SUPPORT=false
        ;;
esac

echo "Debian Architecture: $DEB_ARCH"
echo "Multilib Support: $MULTILIB_SUPPORT"

# Determine directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BEAR_DIR="$PROJECT_ROOT/Bear"
DEBIAN_DIR="$SCRIPT_DIR/debian"
BUILD_DIR="$PROJECT_ROOT/build/deb"
DIST_DIR="$PROJECT_ROOT/dist"

# Package name and directory
PKG_NAME="bear_${VERSION}_${DEB_ARCH}"
PKG_DIR="$BUILD_DIR/$PKG_NAME"

# Clean and create build directory
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"
mkdir -p "$DIST_DIR"

echo "✓ Created build directory"

# Create directory structure
mkdir -p "$PKG_DIR/usr/lib/libexec/bear"
mkdir -p "$PKG_DIR/DEBIAN"

# For x64 with multilib support, create architecture-specific directories
if [ "$MULTILIB_SUPPORT" = true ]; then
    mkdir -p "$PKG_DIR/usr/lib/libexec/bear/x86_64-linux-gnu"
    mkdir -p "$PKG_DIR/usr/lib/libexec/bear/i386-linux-gnu"
    echo "✓ Created multilib directory structure (x86_64 + i386)"
fi

echo "✓ Created package directory structure"

# Determine the actual target directory
# Strip .2.17 suffix if present (e.g., x86_64-unknown-linux-gnu.2.17 -> x86_64-unknown-linux-gnu)
ACTUAL_TARGET="${TARGET_TRIPLE%.2.17}"
TARGET_DIR="$BEAR_DIR/target/$ACTUAL_TARGET/release"

# Copy main binaries
if [ -f "$TARGET_DIR/bear" ]; then
    cp "$TARGET_DIR/bear" "$PKG_DIR/usr/lib/libexec/bear/"
    echo "✓ Copied bear binary ($ACTUAL_TARGET)"
else
    echo "Error: bear binary not found at $TARGET_DIR/bear"
    exit 1
fi

# Copy wrapper if exists
if [ -f "$TARGET_DIR/wrapper" ]; then
    cp "$TARGET_DIR/wrapper" "$PKG_DIR/usr/lib/libexec/bear/"
    echo "✓ Copied wrapper binary"
fi

# Copy shared libraries
if compgen -G "$TARGET_DIR/*.so" > /dev/null; then
    cp "$TARGET_DIR"/*.so "$PKG_DIR/usr/lib/libexec/bear/x86_64-linux-gnu/" 2>/dev/null || true
    echo "✓ Copied shared libraries"
fi

# For x64 multilib: build and copy i686 (32-bit) preload libraries
if [ "$MULTILIB_SUPPORT" = true ]; then
    echo ""
    echo "Building i686 (32-bit) preload libraries for multilib support..."

    # Check if i686 target is installed
    if ! rustup target list --installed | grep -q "i686-unknown-linux-gnu"; then
        echo "Installing i686-unknown-linux-gnu Rust target..."
        rustup target add i686-unknown-linux-gnu
    fi

    # Build i686 preload library
    cd "$BEAR_DIR"

    # Only build the intercept library for i686 (not the full bear binary)
    if [ -d "intercept" ]; then
        echo "Building intercept library for i686..."
        cargo zigbuild --release --target i686-unknown-linux-gnu -p intercept 2>/dev/null || \
        cargo build --release --target i686-unknown-linux-gnu -p intercept || {
            echo "Warning: Failed to build i686 intercept library"
            echo "Continuing without 32-bit support..."
        }

        # Copy i686 libraries if build succeeded
        if [ -d "target/i686-unknown-linux-gnu/release" ]; then
            if compgen -G "target/i686-unknown-linux-gnu/release/*.so" > /dev/null; then
                cp target/i686-unknown-linux-gnu/release/*.so "$PKG_DIR/usr/lib/libexec/bear/i386-linux-gnu/" 2>/dev/null || true
                echo "✓ Copied i686 (32-bit) preload libraries"
            fi
        fi
    else
        echo "Warning: intercept package not found, skipping i686 build"
    fi

    cd "$PROJECT_ROOT"
fi

# Copy architecture-specific library directories (if they exist from other builds)
for libdir in x86_64-linux-gnu aarch64-linux-gnu arm-linux-gnueabihf i386-linux-gnu; do
    if [ -d "$BEAR_DIR/target/release/$libdir" ] && compgen -G "$BEAR_DIR/target/release/$libdir/*.so" > /dev/null 2>&1; then
        mkdir -p "$PKG_DIR/usr/lib/libexec/bear/$libdir"
        cp "$BEAR_DIR/target/release/$libdir"/*.so "$PKG_DIR/usr/lib/libexec/bear/$libdir/" 2>/dev/null || true
        echo "✓ Copied libraries for $libdir"
    fi
done

# Copy documentation
if [ -f "$BEAR_DIR/README.md" ]; then
    mkdir -p "$PKG_DIR/usr/share/doc/bear"
    cp "$BEAR_DIR/README.md" "$PKG_DIR/usr/share/doc/bear/"
    echo "✓ Copied README.md"
fi

if [ -f "$BEAR_DIR/LICENSE" ]; then
    mkdir -p "$PKG_DIR/usr/share/doc/bear"
    cp "$BEAR_DIR/LICENSE" "$PKG_DIR/usr/share/doc/bear/copyright"
    echo "✓ Copied LICENSE"
fi

# Create control file
cat "$DEBIAN_DIR/control.template" | \
    sed "s/VERSION_PLACEHOLDER/$VERSION/g" | \
    sed "s/ARCH_PLACEHOLDER/$DEB_ARCH/g" > "$PKG_DIR/DEBIAN/control"

# Add multilib dependencies for x64 packages
if [ "$MULTILIB_SUPPORT" = true ]; then
    # Add i386 architecture support dependencies
    echo "Depends: libc6, libc6:i386" >> "$PKG_DIR/DEBIAN/control"
    echo "✓ Added multilib dependencies to control file"
fi

echo "✓ Created control file"

# Calculate installed size (in KB)
INSTALLED_SIZE=$(du -sk "$PKG_DIR" | cut -f1)
echo "Installed-Size: $INSTALLED_SIZE" >> "$PKG_DIR/DEBIAN/control"

# Copy postinst and prerm scripts
cp "$DEBIAN_DIR/postinst" "$PKG_DIR/DEBIAN/"
cp "$DEBIAN_DIR/prerm" "$PKG_DIR/DEBIAN/"
chmod 755 "$PKG_DIR/DEBIAN/postinst"
chmod 755 "$PKG_DIR/DEBIAN/prerm"

echo "✓ Copied maintainer scripts"

# Set permissions
find "$PKG_DIR/usr/lib/libexec/bear" -type f -name "bear" -exec chmod 755 {} \;
find "$PKG_DIR/usr/lib/libexec/bear" -type f -name "wrapper" -exec chmod 755 {} \;
find "$PKG_DIR/usr/lib/libexec/bear" -type f -name "*.so" -exec chmod 644 {} \;

echo "✓ Set file permissions"

# Display package contents
echo ""
echo "Package contents:"
echo "----------------"
find "$PKG_DIR/usr/lib/libexec/bear" -type f | sed "s|$PKG_DIR||" | sort

# Build the package
echo ""
echo "Building .deb package..."
cd "$BUILD_DIR"

if command -v dpkg-deb &> /dev/null; then
    dpkg-deb --build --root-owner-group "$PKG_NAME"
else
    echo "Warning: dpkg-deb not found, using fakeroot"
    fakeroot dpkg-deb --build "$PKG_NAME"
fi

if [ $? -eq 0 ]; then
    # Move to dist directory
    DEB_FILE="${PKG_NAME}.deb"
    DIST_FILE="$DIST_DIR/${TARGET_TRIPLE}.deb"

    mv "$DEB_FILE" "$DIST_FILE"

    echo ""
    echo "✓ Debian package created successfully!"
    echo "Location: $DIST_FILE"

    # Display package information
    echo ""
    echo "Package Details:"
    dpkg-deb --info "$DIST_FILE" || file "$DIST_FILE"

    echo ""
    echo "Package Contents:"
    dpkg-deb --contents "$DIST_FILE"

    if [ "$MULTILIB_SUPPORT" = true ]; then
        echo ""
        echo "Multilib Support:"
        echo "  ✓ x86_64 (64-bit) libraries included"
        echo "  ✓ i386 (32-bit) libraries included"
        echo "  Note: This package supports intercepting both 64-bit and 32-bit builds"
    fi

    echo ""
    echo "================================================"
    echo "Debian package creation completed!"
    echo "================================================"
else
    echo "Error: Failed to build .deb package"
    exit 1
fi
