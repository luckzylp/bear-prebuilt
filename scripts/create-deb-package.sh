#!/bin/bash
# Create Debian package for Bear.
#
# Bear v3+ is implemented in Rust. The actual build products are:
#   - bear-driver       (Rust binary, the entry point)
#   - bear-wrapper      (Rust binary, sibling of bear-driver)
#   - libexec.so        (cdylib from intercept-preload, relative to bear-driver)
#   - generate-completions (used to produce shell completions)
#
# The `bear` user-facing command is a generated shell script that execs
# bear-driver by absolute path. See Bear/INSTALL.md and
# bear/src/installation.rs.
#
# Layout (per Bear/INSTALL.md and Bear/scripts/install.sh)
# --------------------------------------------------------
# `INTERCEPT_LIBDIR` is the critical knob: bear-driver resolves
# libexec.so as `parent_dir.join(INTERCEPT_LIBDIR)`, where
# `parent_dir` is the parent of bear-driver's bin/ directory.
# We set it to the Debian multiarch subpath so the 64-bit bear-driver
# resolves `../$MULTIARCH_LIBDIR/libexec.so` to the 64-bit preload.
#
# Multilib (amd64 only)
# ---------------------
# A 32-bit libexec.so is installed alongside the 64-bit one — without
# shipping a 32-bit bear-driver. The 64-bit bear-driver remains the
# single host-bits entry point; the 32-bit preload is available for
# users who invoke 32-bit tooling directly with a manual
# `LD_PRELOAD=/usr/libexec/bear/lib/i386-linux-gnu/libexec.so …`.
#
#   /usr/
#   ├── bin/bear                                       (64-bit entry -> bear-driver)
#   └── libexec/bear/
#       ├── bin/{bear-driver, bear-wrapper}            (64-bit)
#       └── lib/
#           ├── x86_64-linux-gnu/libexec.so            (64-bit preload)
#           └── i386-linux-gnu/libexec.so              (32-bit preload, multilib only)

set -e

VERSION="${1:-0.0.0}"
TARGET_TRIPLE="${2:-x86_64-unknown-linux-gnu}"

echo "================================================"
echo "Creating Bear Debian Package"
echo "Version: $VERSION"
echo "Target: $TARGET_TRIPLE"
echo "================================================"

ACTUAL_TARGET="${TARGET_TRIPLE%.2.17}"

# --- arch mapping (target triple -> DEB arch + multiarch libdir) -----------
case "$ACTUAL_TARGET" in
x86_64-*linux-gnu*)
	DEB_ARCH="amd64"
	HOST_BITS=64
	MULTIARCH_LIBDIR="lib/x86_64-linux-gnu"
	;;
aarch64-*linux-gnu* | aarch64-*linux-musl*)
	DEB_ARCH="arm64"
	HOST_BITS=64
	MULTIARCH_LIBDIR="lib/aarch64-linux-gnu"
	;;
armv7-*linux-gnueabihf* | arm-*)
	DEB_ARCH="armhf"
	HOST_BITS=32
	MULTIARCH_LIBDIR="lib/arm-linux-gnueabihf"
	;;
i686-*linux-gnu*)
	DEB_ARCH="i386"
	HOST_BITS=32
	MULTIARCH_LIBDIR="lib/i386-linux-gnu"
	;;
*)
	echo "Warning: Unknown architecture for $TARGET_TRIPLE, falling back to amd64"
	DEB_ARCH="amd64"
	HOST_BITS=64
	MULTIARCH_LIBDIR="lib/x86_64-linux-gnu"
	;;
esac

echo "Debian Architecture: $DEB_ARCH  (${HOST_BITS}-bit)"
echo "Multiarch INTERCEPT_LIBDIR: $MULTIARCH_LIBDIR"

# --- paths -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BEAR_DIR="$PROJECT_ROOT/Bear"
DEBIAN_DIR="$SCRIPT_DIR/debian"
BUILD_DIR="$PROJECT_ROOT/build/deb"
DIST_DIR="$PROJECT_ROOT/dist"

PKG_NAME="bear_${VERSION}_${DEB_ARCH}"
PKG_DIR="$BUILD_DIR/$PKG_NAME"

rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR" "$DIST_DIR"
echo "✓ Created build directory"

# --- target dir --------------------------------------------------------------
TARGET_DIR="$BEAR_DIR/target/$ACTUAL_TARGET/release"
if [ ! -d "$TARGET_DIR" ]; then
	TARGET_DIR="$BEAR_DIR/target/release"
fi

# Validate primary artifacts (libexec.so is in TARGET_DIR root; the
# INTERCEPT_LIBDIR value is used at install time to choose the
# destination subdirectory, not where the build product is located).
for art in bear-driver bear-wrapper libexec.so; do
	if [ ! -f "$TARGET_DIR/$art" ]; then
		echo "Error: required artifact '$art' not found at $TARGET_DIR/$art"
		echo "Did the cargo build for target '$TARGET_TRIPLE' complete successfully?"
		exit 1
	fi
done
echo "✓ Found required artifacts in $TARGET_DIR"

# --- multilib detection ------------------------------------------------------
# Only fold in 32-bit companion artifacts when the host arch is amd64
# (we don't ship 32-bit packages with embedded 64-bit pieces, etc.).
MULTILIB_TARGET_DIR="$BEAR_DIR/target/i686-unknown-linux-gnu/release"
MULTILIB_OK=false
if [ "$DEB_ARCH" = "amd64" ] && [ -d "$MULTILIB_TARGET_DIR" ]; then
	if [ -f "$MULTILIB_TARGET_DIR/bear-driver" ] && [ -f "$MULTILIB_TARGET_DIR/libexec.so" ]; then
		MULTILIB_OK=true
		echo "✓ Found i686 multilib artifacts at $MULTILIB_TARGET_DIR"
	fi
fi
if [ "$MULTILIB_OK" = false ]; then
	echo "Note: no i686 multilib artifacts found (skipping 32-bit companion)"
fi

# --- layout (per Bear/INSTALL.md) -------------------------------------------
PREFIX="/usr"
BIN_DIR="$PKG_DIR$PREFIX/bin"
MAN_DIR="$PKG_DIR$PREFIX/share/man/man1"
DOC_DIR="$PKG_DIR$PREFIX/share/doc/bear"
COMPL_DIR="$PKG_DIR$PREFIX/share/bash-completion/completions"
COMPLETIONS_DST_DIRS=(
	"$COMPL_DIR"
	"$PKG_DIR$PREFIX/share/zsh/site-functions"
	"$PKG_DIR$PREFIX/share/fish/vendor_completions.d"
	"$PKG_DIR$PREFIX/share/elvish/lib"
)

# Host-bits tree (64-bit on amd64 systems): /usr/libexec/bear/{bin,lib/<multiarch>}/
PRIMARY_BIN_DIR="$PKG_DIR$PREFIX/libexec/bear/bin"
PRIMARY_LIB_DIR="$PKG_DIR$PREFIX/libexec/bear/$MULTIARCH_LIBDIR"

# Multilib (32-bit) tree: only the 32-bit libexec.so is installed, in
# the same /usr/libexec/bear/lib/ tree under the i386 multiarch
# subpath. We do NOT ship a 32-bit bear-driver or bear-wrapper — the
# 64-bit bear-driver is the single host-bits entry point.
MULTI_LIB_DIR="$PKG_DIR$PREFIX/libexec/bear/lib/i386-linux-gnu"

mkdir -p "$PRIMARY_BIN_DIR" "$PRIMARY_LIB_DIR" "$BIN_DIR" "$MAN_DIR" "$DOC_DIR" "${COMPLETIONS_DST_DIRS[@]}"
if [ "$MULTILIB_OK" = true ]; then
	mkdir -p "$MULTI_LIB_DIR"
fi
echo "✓ Created package directory structure (PREFIX=$PREFIX)"

# --- install primary tree ----------------------------------------------------
install -m 0755 "$TARGET_DIR/bear-driver" "$PRIMARY_BIN_DIR/bear-driver"
install -m 0755 "$TARGET_DIR/bear-wrapper" "$PRIMARY_BIN_DIR/bear-wrapper"
install -m 0644 "$TARGET_DIR/libexec.so" "$PRIMARY_LIB_DIR/libexec.so"
echo "✓ Installed ${HOST_BITS}-bit bear-driver, bear-wrapper, libexec.so"
echo "  -> $PREFIX/libexec/bear/bin/  and  $PREFIX/libexec/bear/$MULTIARCH_LIBDIR/"

# --- install multilib (32-bit preload library only) --------------------------
# Only the 32-bit libexec.so is installed — no 32-bit bear-driver or
# bear-wrapper, no /usr/bin/bear32 entry. The 32-bit preload lives at
# /usr/libexec/bear/lib/i386-linux-gnu/libexec.so for users who need
# to inject it manually (e.g. via LD_PRELOAD) when running 32-bit
# tooling.
if [ "$MULTILIB_OK" = true ]; then
	if [ ! -f "$MULTILIB_TARGET_DIR/libexec.so" ]; then
		echo "Warning: 32-bit libexec.so missing — disabling multilib"
		rmdir "$MULTI_LIB_DIR" 2>/dev/null || true
		MULTILIB_OK=false
	else
		install -m 0644 "$MULTILIB_TARGET_DIR/libexec.so" "$MULTI_LIB_DIR/libexec.so"
		echo "✓ Installed 32-bit libexec.so (multilib preload payload)"
		echo "  -> $PREFIX/libexec/bear/lib/i386-linux-gnu/libexec.so"
	fi
fi

# --- generate entry shell scripts --------------------------------------------
cat >"$BIN_DIR/bear" <<'EOF'
#!/bin/sh
# Generated by bear-prebuilt. PREFIX and the bear-driver install path
# are baked in literally so the script keeps working after being moved
# into a packaging chroot.
exec "/usr/libexec/bear/bin/bear-driver" "$@"
EOF
chmod 0755 "$BIN_DIR/bear"
echo "✓ Generated $PREFIX/bin/bear"

# --- shell completions -------------------------------------------------------
COMPL_SRC="$TARGET_DIR/completions"
if [ -d "$COMPL_SRC" ]; then
	[ -f "$COMPL_SRC/bear.bash" ] && install -m 0644 "$COMPL_SRC/bear.bash" "$COMPL_DIR/bear"
	[ -f "$COMPL_SRC/_bear" ] && install -m 0644 "$COMPL_SRC/_bear" "${COMPLETIONS_DST_DIRS[1]}/_bear"
	[ -f "$COMPL_SRC/bear.fish" ] && install -m 0644 "$COMPL_SRC/bear.fish" "${COMPLETIONS_DST_DIRS[2]}/bear.fish"
	[ -f "$COMPL_SRC/bear.elv" ] && install -m 0644 "$COMPL_SRC/bear.elv" "${COMPLETIONS_DST_DIRS[3]}/bear.elv"
	echo "✓ Installed shell completions"
else
	echo "Note: no completions directory at $COMPL_SRC (skipping)"
fi

# --- documentation -----------------------------------------------------------
# Per Bear/INSTALL.md: $PREFIX/share/doc/bear/{README.md, COPYING}.
# We also bundle the upstream INSTALL.md, CONTRIBUTING.md,
# CODE_OF_CONDUCT.md, and RELEASE.md (release notes / changelog) so
# users have a single place to find everything. For Debian policy
# compliance, the license file is also installed as `copyright` (the
# canonical Debian name), in addition to keeping the upstream
# `COPYING` name.
for f in README.md INSTALL.md CONTRIBUTING.md RELEASE.md; do
	if [ -f "$BEAR_DIR/$f" ]; then
		install -m 0644 "$BEAR_DIR/$f" "$DOC_DIR/$f"
	fi
done
if [ -f "$BEAR_DIR/CODE_OF_CONDUCT.md" ]; then
	install -m 0644 "$BEAR_DIR/CODE_OF_CONDUCT.md" "$DOC_DIR/CODE_OF_CONDUCT.md"
fi
if [ -f "$BEAR_DIR/COPYING" ]; then
	install -m 0644 "$BEAR_DIR/COPYING" "$DOC_DIR/COPYING"
	# Debian policy: /usr/share/doc/<pkg>/copyright is the canonical
	# license file path, so keep a second copy under that name too.
	install -m 0644 "$BEAR_DIR/COPYING" "$DOC_DIR/copyright"
elif [ -f "$BEAR_DIR/LICENSE" ]; then
	install -m 0644 "$BEAR_DIR/LICENSE" "$DOC_DIR/copyright"
fi

# --- man page ----------------------------------------------------------------
if [ -d "$BEAR_DIR/man" ]; then
	for manfile in "$BEAR_DIR/man"/*.1 "$BEAR_DIR/man"/*/*.1; do
		[ -f "$manfile" ] || continue
		install -m 0644 "$manfile" "$MAN_DIR/$(basename "$manfile")"
	done
	if compgen -G "$MAN_DIR"/*.1 >/dev/null; then
		gzip -9nf "$MAN_DIR"/*.1 2>/dev/null || true
	fi
fi

# --- DEBIAN control files ----------------------------------------------------
mkdir -p "$PKG_DIR/DEBIAN"

cat "$DEBIAN_DIR/control.template" |
	sed "s/VERSION_PLACEHOLDER/$VERSION/g" |
	sed "s/ARCH_PLACEHOLDER/$DEB_ARCH/g" >"$PKG_DIR/DEBIAN/control"

# Substitute the multiarch libdir placeholder.
if grep -q MULTIARCH_LIBDIR_PLACEHOLDER "$DEBIAN_DIR/control.template"; then
	sed -i "s|MULTIARCH_LIBDIR_PLACEHOLDER|$MULTIARCH_LIBDIR|g" "$PKG_DIR/DEBIAN/control"
fi

if [ "$MULTILIB_OK" = true ]; then
	cat >>"$PKG_DIR/DEBIAN/control" <<'EOF'
Recommends: libc6-i386
Suggests: gcc-multilib
EOF
	echo "✓ Added multilib Recommends/Suggests to control"
fi

INSTALLED_SIZE=$(du -sk "$PKG_DIR" | cut -f1)
echo "Installed-Size: $INSTALLED_SIZE" >>"$PKG_DIR/DEBIAN/control"
echo "✓ Created DEBIAN/control"

for s in postinst prerm; do
	if [ -f "$DEBIAN_DIR/$s" ]; then
		install -m 0755 "$DEBIAN_DIR/$s" "$PKG_DIR/DEBIAN/$s"
	fi
done

# --- build the .deb ----------------------------------------------------------
echo ""
echo "Building .deb package..."
cd "$BUILD_DIR"

if command -v dpkg-deb >/dev/null 2>&1; then
	dpkg-deb --build --root-owner-group "$PKG_NAME"
else
	fakeroot dpkg-deb --build "$PKG_NAME"
fi

DEB_FILE="${PKG_NAME}.deb"

case "$TARGET_TRIPLE" in
*.2.17) VARIANT_SUFFIX="glibc-2.17" ;;
*)      VARIANT_SUFFIX="glibc-high" ;;
esac

DIST_FILE="$DIST_DIR/bear-${VERSION}-${DEB_ARCH}-${VARIANT_SUFFIX}.deb"
mv "$DEB_FILE" "$DIST_FILE"

echo ""
echo "✓ Debian package created successfully!"
echo "Location: $DIST_FILE"
[ "$MULTILIB_OK" = true ] && echo "Note: package includes 32-bit libexec.so payload at /usr/libexec/bear/lib/i386-linux-gnu/libexec.so"

if command -v dpkg-deb >/dev/null 2>&1; then
	echo ""
	echo "Package Details:"
	dpkg-deb --info "$DIST_FILE"
	echo ""
	echo "Package Contents:"
	dpkg-deb --contents "$DIST_FILE"
fi

echo ""
echo "================================================"
echo "Debian package creation completed!"
echo "================================================"
