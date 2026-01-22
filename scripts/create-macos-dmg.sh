#!/bin/bash
# Create macOS DMG package for Bear
# This script builds a .dmg disk image for macOS systems

set -e

VERSION="${1:-0.0.0}"
TARGET_TRIPLE="${2:-x86_64-apple-darwin}"

echo "================================================"
echo "Creating Bear macOS DMG Package"
echo "Version: $VERSION"
echo "Target: $TARGET_TRIPLE"
echo "================================================"

# Determine architecture
case "$TARGET_TRIPLE" in
    x86_64-apple-darwin)
        ARCH="x86_64"
        ;;
    aarch64-apple-darwin)
        ARCH="arm64"
        ;;
    *)
        echo "Warning: Unknown architecture for $TARGET_TRIPLE, using x86_64"
        ARCH="x86_64"
        ;;
esac

echo "Architecture: $ARCH"
echo "Mode: wrapper (default for macOS)"

# Determine directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BEAR_DIR="$PROJECT_ROOT/Bear"
BUILD_DIR="$PROJECT_ROOT/build/macos"
DIST_DIR="$PROJECT_ROOT/dist"

# DMG specific directories
DMG_STAGING="$BUILD_DIR/dmg-staging"
APP_DIR="$DMG_STAGING/Bear.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$DMG_STAGING"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$DIST_DIR"

echo "✓ Created build directory structure"

# Create Bear installation directory structure
BEAR_INSTALL_DIR="$RESOURCES_DIR/usr/lib/libexec/bear"
mkdir -p "$BEAR_INSTALL_DIR"

echo "✓ Created Bear installation directory"

# Determine the actual target directory
# Strip .2.17 suffix if present (though macOS targets don't typically have this)
ACTUAL_TARGET="${TARGET_TRIPLE%.2.17}"
TARGET_DIR="$BEAR_DIR/target/$ACTUAL_TARGET/release"

# Copy binaries
if [ -f "$TARGET_DIR/bear" ]; then
    cp "$TARGET_DIR/bear" "$BEAR_INSTALL_DIR/"
    echo "✓ Copied bear binary ($ACTUAL_TARGET)"
else
    echo "Error: bear binary not found at $TARGET_DIR/bear"
    exit 1
fi

# Copy wrapper if exists
if [ -f "$TARGET_DIR/wrapper" ]; then
    cp "$TARGET_DIR/wrapper" "$BEAR_INSTALL_DIR/"
    echo "✓ Copied wrapper binary"
fi

# Copy shared libraries (dylib on macOS)
if compgen -G "$TARGET_DIR/*.dylib" > /dev/null 2>/dev/null; then
    cp "$TARGET_DIR"/*.dylib "$BEAR_INSTALL_DIR/" 2>/dev/null || true
    echo "✓ Copied shared libraries"
fi

# Copy architecture-specific library directories if they exist
for libdir in x86_64 arm64; do
    if [ -d "$TARGET_DIR/$libdir" ] && compgen -G "$TARGET_DIR/$libdir/*.dylib" > /dev/null 2>&1; then
        mkdir -p "$BEAR_INSTALL_DIR/$libdir"
        cp "$TARGET_DIR/$libdir"/*.dylib "$BEAR_INSTALL_DIR/$libdir/" || true
        echo "✓ Copied libraries for $libdir"
    fi
done

# Copy documentation
if [ -f "$BEAR_DIR/README.md" ]; then
    cp "$BEAR_DIR/README.md" "$RESOURCES_DIR/"
    echo "✓ Copied README.md"
fi

if [ -f "$BEAR_DIR/LICENSE" ]; then
    cp "$BEAR_DIR/LICENSE" "$RESOURCES_DIR/"
    echo "✓ Copied LICENSE"
fi

# Copy man pages from Bear repository
if [ -d "$BEAR_DIR/man" ]; then
    echo ""
    echo "Copying man pages..."
    mkdir -p "$RESOURCES_DIR/usr/share/man/man1"

    # Copy all man pages from Bear/man directory
    MAN_COUNT=0
    for manfile in "$BEAR_DIR/man"/*.1 "$BEAR_DIR/man"/*/*.1; do
        if [ -f "$manfile" ]; then
            cp "$manfile" "$RESOURCES_DIR/usr/share/man/man1/"
            MAN_COUNT=$((MAN_COUNT + 1))
        fi
    done

    if [ $MAN_COUNT -gt 0 ]; then
        # Compress man pages (macOS standard)
        gzip -9 "$RESOURCES_DIR/usr/share/man/man1"/*.1 2>/dev/null || true
        echo "✓ Copied and compressed $MAN_COUNT man page(s)"
    else
        echo "Warning: No man pages found in $BEAR_DIR/man"
    fi
else
    echo "Warning: man directory not found at $BEAR_DIR/man"
fi

# Set permissions
chmod 755 "$BEAR_INSTALL_DIR/bear"
if [ -f "$BEAR_INSTALL_DIR/wrapper" ]; then
    chmod 755 "$BEAR_INSTALL_DIR/wrapper"
fi
find "$BEAR_INSTALL_DIR" -type f -name "*.dylib" -exec chmod 644 {} \;

echo "✓ Set file permissions"

# Create installation script
cat > "$MACOS_DIR/install.sh" << 'INSTALL_SCRIPT_EOF'
#!/bin/bash
# Bear Installation Script

set -e

INSTALL_DIR="/usr/lib/libexec/bear"
RESOURCES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../Resources" && pwd)"
SOURCE_DIR="$RESOURCES_DIR/usr/lib/libexec/bear"

echo "Installing Bear to $INSTALL_DIR..."

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo or as root"
    exit 1
fi

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Copy files
echo "Copying files..."
cp -R "$SOURCE_DIR"/* "$INSTALL_DIR/"

# Set permissions
chmod 755 "$INSTALL_DIR/bear"
if [ -f "$INSTALL_DIR/wrapper" ]; then
    chmod 755 "$INSTALL_DIR/wrapper"
fi
find "$INSTALL_DIR" -type f -name "*.dylib" -exec chmod 644 {} \;

# Create symbolic link
mkdir -p /usr/local/bin
if [ -L /usr/local/bin/bear ]; then
    rm /usr/local/bin/bear
fi
ln -s "$INSTALL_DIR/bear" /usr/local/bin/bear

# Install man pages if available
if [ -d "$RESOURCES_DIR/usr/share/man/man1" ]; then
    echo "Installing man pages..."
    mkdir -p /usr/local/share/man/man1
    cp "$RESOURCES_DIR/usr/share/man/man1"/*.gz /usr/local/share/man/man1/ 2>/dev/null || true

    # Update man database if makewhatis is available
    if command -v makewhatis >/dev/null 2>&1; then
        makewhatis /usr/local/share/man 2>/dev/null || true
    fi
fi

echo ""
echo "✓ Bear installed successfully!"
echo "✓ Installed to: $INSTALL_DIR"
echo "✓ Symlink created: /usr/local/bin/bear"
if [ -d "$RESOURCES_DIR/usr/share/man/man1" ]; then
    echo "✓ Man pages installed: /usr/local/share/man/man1"
fi
echo ""
echo "You can now run 'bear' from the command line."
echo "View help with: man bear"
INSTALL_SCRIPT_EOF

chmod 755 "$MACOS_DIR/install.sh"
echo "✓ Created installation script"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>install.sh</string>
    <key>CFBundleIdentifier</key>
    <string>org.bear-project.bear</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Bear</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST_EOF

echo "✓ Created Info.plist"

# Create README file for DMG
cat > "$DMG_STAGING/README.txt" << README_EOF
Bear $VERSION (Wrapper Mode)

INSTALLATION INSTRUCTIONS
=========================

1. Double-click Bear.app to run the installation script
   (You will be prompted for your administrator password)

OR

2. Open Terminal and run:
   cd "/Volumes/Bear $VERSION"
   sudo ./Bear.app/Contents/MacOS/install.sh

INSTALLATION DETAILS
====================

Installation Path: /usr/lib/libexec/bear/
Symlink: /usr/local/bin/bear -> /usr/lib/libexec/bear/bear
Mode: Wrapper (default for macOS)

VERIFICATION
============

After installation, open a new terminal and run:
  bear --version

UNINSTALLATION
==============

To uninstall Bear:
  sudo rm -rf /usr/lib/libexec/bear
  sudo rm /usr/local/bin/bear

For more information, visit:
https://github.com/rizsotto/Bear
README_EOF

echo "✓ Created README.txt"

# Display package contents
echo ""
echo "Package contents:"
echo "----------------"
find "$DMG_STAGING" -type f | sed "s|$DMG_STAGING||" | sort

# Create DMG
echo ""
echo "Creating DMG disk image..."

DMG_NAME="bear-${VERSION}-${TARGET_TRIPLE}-wrapper.dmg"
DMG_FILE="$DIST_DIR/$DMG_NAME"
DMG_TEMP="$BUILD_DIR/bear-temp.dmg"

# Remove old DMG if exists
rm -f "$DMG_FILE" "$DMG_TEMP"

# Check if running on macOS (hdiutil available)
if command -v hdiutil &> /dev/null; then
    echo "Using macOS hdiutil to create DMG..."

    # Create temporary DMG
    hdiutil create -volname "Bear $VERSION" \
        -srcfolder "$DMG_STAGING" \
        -ov -format UDRW \
        "$DMG_TEMP"

    echo "✓ Created temporary DMG"

    # Mount the temporary DMG
    MOUNT_DIR="/Volumes/Bear $VERSION"
    hdiutil attach "$DMG_TEMP" -mountpoint "$MOUNT_DIR"

    echo "✓ Mounted temporary DMG"

    # Add symlink to Applications (optional, for convenience)
    # Note: This won't actually install Bear, just provides easy access to the installer
    ln -s /Applications "$MOUNT_DIR/Applications" 2>/dev/null || true

    # Set DMG background and icon positions (if running on macOS with GUI)
    if command -v osascript &> /dev/null; then
        echo "Configuring DMG appearance..."
        osascript << APPLESCRIPT_EOF
tell application "Finder"
    tell disk "Bear $VERSION"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        set position of item "Bear.app" of container window to {150, 150}
        set position of item "README.txt" of container window to {350, 150}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT_EOF
        echo "✓ Configured DMG appearance"
    else
        echo "Note: Running in non-GUI environment, skipping DMG appearance configuration"
    fi

    # Unmount
    hdiutil detach "$MOUNT_DIR" -force

    echo "✓ Unmounted DMG"

    # Convert to compressed read-only DMG
    hdiutil convert "$DMG_TEMP" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "$DMG_FILE"

    echo "✓ Compressed DMG"

    # Clean up temporary DMG
    rm -f "$DMG_TEMP"
else
    # Not on macOS - create a tar.gz archive instead
    echo "Warning: hdiutil not found (not running on macOS)"
    echo "Creating tar.gz archive as fallback..."

    cd "$BUILD_DIR"
    tar czf "$DMG_FILE.tar.gz" -C dmg-staging .

    # Rename to keep .dmg extension for compatibility
    mv "$DMG_FILE.tar.gz" "${DMG_FILE%.dmg}.tar.gz"
    DMG_FILE="${DMG_FILE%.dmg}.tar.gz"

    echo "✓ Created tar.gz archive (use on macOS to extract and create proper DMG)"
fi

if [ -f "$DMG_FILE" ]; then
    echo ""
    echo "✓ macOS DMG package created successfully!"
    echo "Location: $DMG_FILE"

    # Display DMG information
    echo ""
    echo "DMG Details:"
    echo "  Name: $DMG_NAME"
    DMG_SIZE=$(du -h "$DMG_FILE" | cut -f1)
    echo "  Size: $DMG_SIZE"
    echo "  Architecture: $ARCH"
    echo "  Mode: wrapper (default for macOS)"
    echo "  Format: UDZO (compressed)"

    echo ""
    echo "Installation Instructions:"
    echo "  1. Double-click the DMG to mount it"
    echo "  2. Double-click Bear.app to install"
    echo "  3. Enter your administrator password when prompted"

    echo ""
    echo "================================================"
    echo "macOS DMG creation completed (wrapper mode)!"
    echo "================================================"
else
    echo "Error: Failed to create DMG package"
    exit 1
fi
