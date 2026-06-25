#!/bin/bash
# Create macOS DMG package for Bear (wrapper mode).
#
# Bear v3+ is implemented in Rust. The actual build products are:
#   - bear-driver       (Rust binary, the entry point)
#   - bear-wrapper      (Rust binary, sibling of bear-driver)
#   - libexec.dylib     (cdylib from intercept-preload)
#
# The `bear` user-facing command is generated at install time by
# `install.sh` (generated below) as a shell script that execs
# bear-driver by absolute path. See Bear/INSTALL.md and
# bear/src/installation.rs for the layout this script implements.

set -e

VERSION="${1:-0.0.0}"
TARGET_TRIPLE="${2:-x86_64-apple-darwin}"

echo "================================================"
echo "Creating Bear macOS DMG Package (wrapper mode)"
echo "Version: $VERSION"
echo "Target: $TARGET_TRIPLE"
echo "================================================"

case "$TARGET_TRIPLE" in
x86_64-apple-darwin) ARCH="x86_64" ;;
aarch64-apple-darwin) ARCH="arm64" ;;
*)
	echo "Warning: Unknown architecture for $TARGET_TRIPLE, using x86_64"
	ARCH="x86_64"
	;;
esac

echo "Architecture: $ARCH"

# --- paths -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BEAR_DIR="$PROJECT_ROOT/Bear"
BUILD_DIR="$PROJECT_ROOT/build/macos"
DIST_DIR="$PROJECT_ROOT/dist"

DMG_STAGING="$BUILD_DIR/dmg-staging"
APP_DIR="$DMG_STAGING/Bear.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Bear's on-disk layout (matches the install layout in Bear/scripts/install.sh)
BEAR_INSTALL_DIR="$RESOURCES_DIR/usr/libexec/bear"
BEAR_BIN_DIR="$BEAR_INSTALL_DIR/bin"
BEAR_LIB_DIR="$BEAR_INSTALL_DIR/lib"
BEAR_BIN_LINK_DIR="$RESOURCES_DIR/usr/local/bin"

rm -rf "$BUILD_DIR"
mkdir -p "$DMG_STAGING" "$MACOS_DIR" "$RESOURCES_DIR" \
	"$BEAR_BIN_DIR" "$BEAR_LIB_DIR" "$BEAR_BIN_LINK_DIR" \
	"$DIST_DIR"
echo "✓ Created staging directories"

# --- target dir --------------------------------------------------------------
ACTUAL_TARGET="${TARGET_TRIPLE%.2.17}"
TARGET_DIR="$BEAR_DIR/target/$ACTUAL_TARGET/release"
if [ ! -d "$TARGET_DIR" ]; then
	TARGET_DIR="$BEAR_DIR/target/release"
fi

for art in bear-driver bear-wrapper libexec.dylib; do
	if [ ! -f "$TARGET_DIR/$art" ]; then
		echo "Error: required artifact '$art' not found at $TARGET_DIR/$art"
		echo "Did the cargo zigbuild for target '$TARGET_TRIPLE' complete successfully?"
		exit 1
	fi
done
echo "✓ Found required artifacts in $TARGET_DIR"

# --- stage binaries ----------------------------------------------------------
install -m 0755 "$TARGET_DIR/bear-driver" "$BEAR_BIN_DIR/bear-driver"
install -m 0755 "$TARGET_DIR/bear-wrapper" "$BEAR_BIN_DIR/bear-wrapper"
install -m 0644 "$TARGET_DIR/libexec.dylib" "$BEAR_LIB_DIR/libexec.dylib"
echo "✓ Staged bear-driver, bear-wrapper, libexec.dylib"

# --- documentation -----------------------------------------------------------
# Per Bear/INSTALL.md the on-disk layout is
# $PREFIX/share/doc/bear/{README.md, COPYING}. We stage all of the
# upstream docs in the DMG's Resources/share/doc/bear/ tree so the
# embedded install.sh can copy them to /usr/local/share/doc/bear/.
DOC_STAGE="$RESOURCES_DIR/usr/local/share/doc/bear"
mkdir -p "$DOC_STAGE"
for f in README.md INSTALL.md CONTRIBUTING.md RELEASE.md; do
	if [ -f "$BEAR_DIR/$f" ]; then
		install -m 0644 "$BEAR_DIR/$f" "$DOC_STAGE/$f"
	fi
done
if [ -f "$BEAR_DIR/CODE_OF_CONDUCT.md" ]; then
	install -m 0644 "$BEAR_DIR/CODE_OF_CONDUCT.md" "$DOC_STAGE/CODE_OF_CONDUCT.md"
fi
if [ -f "$BEAR_DIR/COPYING" ]; then
	install -m 0644 "$BEAR_DIR/COPYING" "$DOC_STAGE/COPYING"
elif [ -f "$BEAR_DIR/LICENSE" ]; then
	install -m 0644 "$BEAR_DIR/LICENSE" "$DOC_STAGE/COPYING"
fi
# Top-level copies for the DMG's Finder preview.
[ -f "$BEAR_DIR/README.md" ] && install -m 0644 "$BEAR_DIR/README.md" "$RESOURCES_DIR/README.md"
[ -f "$BEAR_DIR/COPYING" ] && install -m 0644 "$BEAR_DIR/COPYING" "$RESOURCES_DIR/COPYING" \
	|| [ -f "$BEAR_DIR/LICENSE" ] && install -m 0644 "$BEAR_DIR/LICENSE" "$RESOURCES_DIR/COPYING"

# man page(s)
if [ -d "$BEAR_DIR/man" ]; then
	mkdir -p "$RESOURCES_DIR/usr/share/man/man1"
	for manfile in "$BEAR_DIR/man"/*.1 "$BEAR_DIR/man"/*/*.1; do
		[ -f "$manfile" ] || continue
		install -m 0644 "$manfile" "$RESOURCES_DIR/usr/share/man/man1/$(basename "$manfile")"
	done
	if compgen -G "$RESOURCES_DIR/usr/share/man/man1"/*.1 >/dev/null; then
		gzip -9nf "$RESOURCES_DIR/usr/share/man/man1"/*.1 2>/dev/null || true
	fi
fi

# shell completions
COMPL_SRC="$TARGET_DIR/completions"
if [ -d "$COMPL_SRC" ]; then
	COMPL_DST="$RESOURCES_DIR/completions"
	mkdir -p "$COMPL_DST"
	[ -f "$COMPL_SRC/bear.bash" ] && install -m 0644 "$COMPL_SRC/bear.bash" "$COMPL_DST/bear.bash"
	[ -f "$COMPL_SRC/_bear" ] && install -m 0644 "$COMPL_SRC/_bear" "$COMPL_DST/_bear"
	[ -f "$COMPL_SRC/bear.fish" ] && install -m 0644 "$COMPL_SRC/bear.fish" "$COMPL_DST/bear.fish"
	[ -f "$COMPL_SRC/bear.elv" ] && install -m 0644 "$COMPL_SRC/bear.elv" "$COMPL_DST/bear.elv"
fi

# --- generate install.sh inside Bear.app -------------------------------------
# Layout: copies bear-driver/wrapper/libexec.dylib into /usr/libexec/bear/,
# generates /usr/local/bin/bear, installs man pages, completions.
cat >"$MACOS_DIR/install.sh" <<'INSTALL_EOF'
#!/bin/bash
# Bear installer (generated by bear-prebuilt).
set -e

INSTALL_ROOT="/usr/libexec/bear"
BIN_LINK="/usr/local/bin/bear"
MAN_DIR="/usr/local/share/man/man1"
DOC_DIR="/usr/local/share/doc/bear"
COMPL_DIR_BASH="/usr/local/share/bash-completion/completions"
COMPL_DIR_ZSH="/usr/local/share/zsh/site-functions"
COMPL_DIR_FISH="/usr/local/share/fish/vendor_completions.d"
COMPL_DIR_ELV="/usr/local/share/elvish/lib"

RESOURCES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../Resources" && pwd)"

if [ "$EUID" -ne 0 ]; then
	echo "Please run with sudo: sudo $0" >&2
	exit 1
fi

echo "Installing Bear to $INSTALL_ROOT..."

# bear-driver and bear-wrapper
mkdir -p "$INSTALL_ROOT/bin"
install -m 0755 "$RESOURCES_DIR/usr/libexec/bear/bin/bear-driver" "$INSTALL_ROOT/bin/bear-driver"
install -m 0755 "$RESOURCES_DIR/usr/libexec/bear/bin/bear-wrapper" "$INSTALL_ROOT/bin/bear-wrapper"

# preload library
mkdir -p "$INSTALL_ROOT/lib"
install -m 0755 "$RESOURCES_DIR/usr/libexec/bear/lib/libexec.dylib" "$INSTALL_ROOT/lib/libexec.dylib"

# bear entry script
mkdir -p "$(dirname "$BIN_LINK")"
cat >"$BIN_LINK" <<'BEAR_ENTRY'
#!/bin/sh
exec "/usr/libexec/bear/bin/bear-driver" "$@"
BEAR_ENTRY
chmod 0755 "$BIN_LINK"

# man pages
if compgen -G "$RESOURCES_DIR/usr/share/man/man1"/*.gz >/dev/null 2>&1; then
	mkdir -p "$MAN_DIR"
	install -m 0644 "$RESOURCES_DIR/usr/share/man/man1"/*.gz "$MAN_DIR/" 2>/dev/null || true
	if command -v makewhatis >/dev/null 2>&1; then
		makewhatis "$MAN_DIR" 2>/dev/null || true
	fi
fi

# completions (if shipped)
if [ -d "$RESOURCES_DIR/completions" ]; then
	[ -f "$RESOURCES_DIR/completions/bear.bash" ] && mkdir -p "$COMPL_DIR_BASH" && install -m 0644 "$RESOURCES_DIR/completions/bear.bash" "$COMPL_DIR_BASH/bear"
	[ -f "$RESOURCES_DIR/completions/_bear" ] && mkdir -p "$COMPL_DIR_ZSH" && install -m 0644 "$RESOURCES_DIR/completions/_bear" "$COMPL_DIR_ZSH/_bear"
	[ -f "$RESOURCES_DIR/completions/bear.fish" ] && mkdir -p "$COMPL_DIR_FISH" && install -m 0644 "$RESOURCES_DIR/completions/bear.fish" "$COMPL_DIR_FISH/bear.fish"
	[ -f "$RESOURCES_DIR/completions/bear.elv" ] && mkdir -p "$COMPL_DIR_ELV" && install -m 0644 "$RESOURCES_DIR/completions/bear.elv" "$COMPL_DIR_ELV/bear.elv"
fi

# documentation (per Bear/INSTALL.md share/doc/bear/)
if [ -d "$RESOURCES_DIR/usr/local/share/doc/bear" ]; then
	mkdir -p "$DOC_DIR"
	for f in "$RESOURCES_DIR/usr/local/share/doc/bear"/*; do
		[ -f "$f" ] || continue
		install -m 0644 "$f" "$DOC_DIR/$(basename "$f")"
	done
fi

echo ""
echo "✓ Bear installed to $INSTALL_ROOT"
echo "✓ Symlink created: $BIN_LINK"
echo ""
echo "Open a new terminal and run: bear --version"
INSTALL_EOF
chmod 0755 "$MACOS_DIR/install.sh"
echo "✓ Generated Bear.app/Contents/MacOS/install.sh"

# --- Info.plist --------------------------------------------------------------
cat >"$CONTENTS_DIR/Info.plist" <<PLIST_EOF
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
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST_EOF
echo "✓ Created Info.plist"

# --- README ------------------------------------------------------------------
cat >"$DMG_STAGING/README.txt" <<README_EOF
Bear $VERSION (Wrapper Mode)

INSTALLATION
============

1. Double-click Bear.app to run the installation script
   (you will be prompted for your administrator password).

   OR

2. Open Terminal and run:
     cd "/Volumes/Bear $VERSION"
     sudo ./Bear.app/Contents/MacOS/install.sh

INSTALLATION LAYOUT
===================

  /usr/libexec/bear/
  ├── bin/
  │   ├── bear-driver
  │   └── bear-wrapper
  └── lib/
      └── libexec.dylib

  /usr/local/bin/bear          (shell script -> bear-driver)

VERIFICATION
============

After installation, open a new terminal and run:
  bear --version

UNINSTALLATION
==============

  sudo rm -rf /usr/libexec/bear
  sudo rm /usr/local/bin/bear

  sudo rm -f /usr/local/share/man/man1/bear.1.gz
  sudo rm -f /usr/local/share/bash-completion/completions/bear
  sudo rm -f /usr/local/share/zsh/site-functions/_bear
  sudo rm -f /usr/local/share/fish/vendor_completions.d/bear.fish
  sudo rm -f /usr/local/share/elvish/lib/bear.elv

More info: https://github.com/rizsotto/Bear
README_EOF

# --- DMG ---------------------------------------------------------------------
echo ""
echo "Creating DMG..."

DMG_NAME="bear-${VERSION}-${TARGET_TRIPLE}-wrapper.dmg"
DMG_FILE="$DIST_DIR/$DMG_NAME"
DMG_TEMP="$BUILD_DIR/bear-temp.dmg"
rm -f "$DMG_FILE" "$DMG_TEMP"

if command -v hdiutil >/dev/null 2>&1; then
	hdiutil create -volname "Bear $VERSION" -srcfolder "$DMG_STAGING" -ov -format UDRW "$DMG_TEMP"

	MOUNT_DIR="/Volumes/Bear $VERSION"
	hdiutil attach "$DMG_TEMP" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

	if command -v osascript >/dev/null 2>&1; then
		osascript <<APPLESCRIPT_EOF
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
	fi

	hdiutil detach "$MOUNT_DIR" -force -quiet
	hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FILE"
	rm -f "$DMG_TEMP"
else
	echo "Warning: hdiutil not found (not on macOS). Falling back to .tar.gz."
	tar czf "$DIST_DIR/$DMG_NAME.tar.gz" -C "$DMG_STAGING" .
	DMG_FILE="$DIST_DIR/$DMG_NAME.tar.gz"
fi

echo ""
echo "✓ macOS DMG created: $DMG_FILE"
echo "  Architecture: $ARCH"
echo "================================================"
