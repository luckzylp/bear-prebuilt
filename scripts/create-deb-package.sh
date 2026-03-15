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
x86_64* | *x86-64*)
	DEB_ARCH="amd64"
	MULTILIB_SUPPORT=true
	;;
aarch64* | *arm64*)
	DEB_ARCH="arm64"
	MULTILIB_SUPPORT=false
	;;
armv7* | *armhf*)
	DEB_ARCH="armhf"
	MULTILIB_SUPPORT=false
	;;
i686* | *i386*)
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

# Determine the correct lib directory for this architecture per install.md
# For Debian: lib/x86_64-linux-gnu, lib/aarch64-linux-gnu, etc.
# Strip .2.17 suffix if present (e.g., x86_64-unknown-linux-gnu.2.17 -> x86_64-unknown-linux-gnu)
case "${TARGET_TRIPLE%.2.17}" in
x86_64* | *x86-64*)
	INSTALL_LIBDIR="lib/x86_64-linux-gnu"
	;;
aarch64* | *arm64*)
	INSTALL_LIBDIR="lib/aarch64-linux-gnu"
	;;
armv7* | *armhf*)
	INSTALL_LIBDIR="lib/arm-linux-gnueabihf"
	;;
i686* | *i386*)
	INSTALL_LIBDIR="lib/i386-linux-gnu"
	;;
*)
	# Default fallback
	INSTALL_LIBDIR="lib/x86_64-linux-gnu"
	;;
esac

echo "Using INSTALL_LIBDIR: $INSTALL_LIBDIR"

# Create directory structure per Bear's official install.md guide
# Default paths: /usr/${INSTALL_LIBDIR}/bear for wrapper, /usr/${INSTALL_LIBDIR}/bear for preload
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/${INSTALL_LIBDIR}/bear"
mkdir -p "$PKG_DIR/usr/share/man/man1"
mkdir -p "$PKG_DIR/DEBIAN"

# For x64 with multilib support, create architecture-specific directories
# Debian uses: lib/x86_64-linux-gnu and lib/i386-linux-gnu per install.md
if [ "$MULTILIB_SUPPORT" = true ]; then
	# mkdir -p "$PKG_DIR/usr/lib/x86_64-linux-gnu/bear"
	mkdir -p "$PKG_DIR/usr/lib/i386-linux-gnu/bear"
	echo "✓ Created multilib directory structure (lib/x86_64-linux-gnu + lib/i386-linux-gnu)"
fi

echo "✓ Created package directory structure"

# Determine the actual target directory
ACTUAL_TARGET="${TARGET_TRIPLE%.2.17}"
TARGET_DIR="$BEAR_DIR/target/$ACTUAL_TARGET/release"

# Copy main binaries per install.md
# bear -> /usr/bin/
# wrapper -> /usr/${INSTALL_LIBDIR}/bear/
if [ -f "$TARGET_DIR/bear" ]; then
	cp "$TARGET_DIR/bear" "$PKG_DIR/usr/bin/"
	echo "✓ Copied bear binary to /usr/bin/ ($ACTUAL_TARGET)"
else
	echo "Error: bear binary not found at $TARGET_DIR/bear"
	exit 1
fi

# Copy wrapper if exists
if [ -f "$TARGET_DIR/wrapper" ]; then
	cp "$TARGET_DIR/wrapper" "$PKG_DIR/usr/${INSTALL_LIBDIR}/bear/"
	echo "✓ Copied wrapper binary to /usr/${INSTALL_LIBDIR}/bear/"
fi

# Copy shared libraries (libexec.so) per install.md
# Path: /usr/${INSTALL_LIBDIR}/bear/$INSTALL_LIBDIR/
if compgen -G "$TARGET_DIR/*.so" >/dev/null; then
	mkdir -p "$PKG_DIR/usr/${INSTALL_LIBDIR}/bear/"
	cp "$TARGET_DIR"/*.so "$PKG_DIR/usr/${INSTALL_LIBDIR}/bear/" 2>/dev/null || true
	echo "✓ Copied shared libraries to /usr/${INSTALL_LIBDIR}/bear/"
fi

# For x64 multilib: copy i686 (32-bit) preload libraries
if [ "$MULTILIB_SUPPORT" = true ]; then
	echo ""
	echo "Copying i686 (32-bit) preload libraries for multilib support..."

	I686_TARGET_DIR="$BEAR_DIR/target/i686-unknown-linux-gnu/release"

	if [ -d "$I686_TARGET_DIR" ]; then
		if compgen -G "$I686_TARGET_DIR/*.so" >/dev/null; then
			cp "$I686_TARGET_DIR"/*.so "$PKG_DIR/usr/lib/i386-linux-gnu/bear/" 2>/dev/null || true
			echo "✓ Copied i686 (32-bit) preload libraries"
		else
			echo "Warning: No i686 libraries found at $I686_TARGET_DIR"
		fi
		# copy i386 wrapper
		# Copy wrapper if exists
        if [ -f "$I686_TARGET_DIR/wrapper" ]; then
           	cp "$I686_TARGET_DIR/wrapper" "$PKG_DIR/usr/lib/i386-linux-gnu/bear/"
            echo "✓ Copied wrapper binary to /usr/lib/i386-linux-gnu/bear/"
       	else
            echo "Warning: i686 `$I686_TARGET_DIR/wrapper` not found at $I686_TARGET_DIR"
        fi
	else
		echo "Warning: i686 build directory not found at $I686_TARGET_DIR"
	fi
fi

# Copy architecture-specific library directories (if they exist from other builds)
for libdir in x86_64-linux-gnu aarch64-linux-gnu arm-linux-gnueabihf i386-linux-gnu; do
	if [ -d "$BEAR_DIR/target/release/$libdir" ] && compgen -G "$BEAR_DIR/target/release/$libdir/*.so" >/dev/null 2>&1; then
		mkdir -p "$PKG_DIR/usr/${INSTALL_LIBDIR}/bear/lib/$libdir"
		cp "$BEAR_DIR/target/release/$libdir"/*.so "$PKG_DIR/usr/${INSTALL_LIBDIR}/bear/lib/$libdir/" 2>/dev/null || true
		echo "✓ Copied libraries for lib/$libdir"
	fi
done

# Copy documentation
if [ -f "$BEAR_DIR/README.md" ]; then
	mkdir -p "$PKG_DIR/usr/share/doc/bear"
	cp "$BEAR_DIR/README.md" "$PKG_DIR/usr/share/doc/bear/"
	echo "✓ Copied README.md"
fi
if [ -f "$BEAR_DIR/AGENTS.md" ]; then
	mkdir -p "$PKG_DIR/usr/share/doc/bear"
	cp "$BEAR_DIR/AGENTS.md" "$PKG_DIR/usr/share/doc/bear/"
	echo "✓ Copied AGENTS.md"
fi
if [ -f "$BEAR_DIR/CODE_OF_CONDUCT.md" ]; then
	mkdir -p "$PKG_DIR/usr/share/doc/bear"
	cp "$BEAR_DIR/CODE_OF_CONDUCT.md" "$PKG_DIR/usr/share/doc/bear/"
	echo "✓ Copied CODE_OF_CONDUCT.md"
fi
if [ -f "$BEAR_DIR/CONTRIBUTING.md" ]; then
	mkdir -p "$PKG_DIR/usr/share/doc/bear"
	cp "$BEAR_DIR/CONTRIBUTING.md" "$PKG_DIR/usr/share/doc/bear/"
	echo "✓ Copied CONTRIBUTING.md"
fi
if [ -f "$BEAR_DIR/INSTALL.md" ]; then
	mkdir -p "$PKG_DIR/usr/share/doc/bear"
	cp "$BEAR_DIR/INSTALL.md" "$PKG_DIR/usr/share/doc/bear/"
	echo "✓ Copied INSTALL.md"
fi

if [ -f "$BEAR_DIR/LICENSE" ]; then
	mkdir -p "$PKG_DIR/usr/share/doc/bear"
	cp "$BEAR_DIR/LICENSE" "$PKG_DIR/usr/share/doc/bear/copyright"
	echo "✓ Copied LICENSE"
fi

# Copy man pages from Bear repository per install.md
# install.md: sudo install -m 644 man/bear.1 /usr/share/man/man1/
if [ -d "$BEAR_DIR/man" ]; then
	echo ""
	echo "Copying man pages to /usr/share/man/man1..."
	mkdir -p "$PKG_DIR/usr/share/man/man1"

	# Copy all man pages from Bear/man directory
	MAN_COUNT=0
	for manfile in "$BEAR_DIR/man"/*.1 "$BEAR_DIR/man"/*/*.1; do
		if [ -f "$manfile" ]; then
			cp "$manfile" "$PKG_DIR/usr/share/man/man1/"
			MAN_COUNT=$((MAN_COUNT + 1))
		fi
	done

	if [ $MAN_COUNT -gt 0 ]; then
		# Compress man pages
		gzip -9 "$PKG_DIR/usr/share/man/man1"/*.1 2>/dev/null || true
		echo "✓ Copied and compressed $MAN_COUNT man page(s) to /usr/share/man/man1/"
	else
		echo "Warning: No man pages found in $BEAR_DIR/man"
	fi
else
	echo "Warning: man directory not found at $BEAR_DIR/man"
fi

# Create control file
cat "$DEBIAN_DIR/control.template" |
	sed "s/VERSION_PLACEHOLDER/$VERSION/g" |
	sed "s/ARCH_PLACEHOLDER/$DEB_ARCH/g" >"$PKG_DIR/DEBIAN/control"

# Add multilib dependencies for x64 packages
if [ "$MULTILIB_SUPPORT" = true ]; then
	# Add i386 architecture support dependencies
	echo "Depends: libc6, libc6:i386" >>"$PKG_DIR/DEBIAN/control"
	echo "✓ Added multilib dependencies to control file"
fi

echo "✓ Created control file"

# Calculate installed size (in KB)
INSTALLED_SIZE=$(du -sk "$PKG_DIR" | cut -f1)
echo "Installed-Size: $INSTALLED_SIZE" >>"$PKG_DIR/DEBIAN/control"

# Copy postinst and prerm scripts if they exist
if [ -f "$DEBIAN_DIR/postinst" ]; then
	cp "$DEBIAN_DIR/postinst" "$PKG_DIR/DEBIAN/"
	chmod 755 "$PKG_DIR/DEBIAN/postinst"
	echo "✓ Copied postinst script"
else
	echo "Warning: postinst script not found at $DEBIAN_DIR/postinst"
fi

if [ -f "$DEBIAN_DIR/prerm" ]; then
	cp "$DEBIAN_DIR/prerm" "$PKG_DIR/DEBIAN/"
	chmod 755 "$PKG_DIR/DEBIAN/prerm"
	echo "✓ Copied prerm script"
else
	echo "Warning: prerm script not found at $DEBIAN_DIR/prerm"
fi

# Build the package
echo ""
echo "Building .deb package..."
cd "$BUILD_DIR"

if command -v dpkg-deb &>/dev/null; then
	dpkg-deb --build --root-owner-group "$PKG_NAME"
else
	echo "Warning: dpkg-deb not found, using fakeroot"
	fakeroot dpkg-deb --build "$PKG_NAME"
fi

if [ $? -eq 0 ]; then
	# Move to dist directory
	DEB_FILE="${PKG_NAME}.deb"
	DIST_FILE="$DIST_DIR/bear-${VERSION}-${TARGET_TRIPLE}.deb"

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
