# Bear Multi-Platform Prebuilt

This repository contains scripts and a GitHub Actions workflow that build
platform-specific installers for [Bear](https://github.com/rizsotto/Bear)
(compilation database generation tool) from upstream source.

## Overview

Automated build system for Bear with platform-specific packaging, aligned
with the installation layout described in Bear's upstream
[`INSTALL.md`](https://github.com/rizsotto/Bear/blob/main/INSTALL.md).

- **Windows**: NSIS installer (`bear-driver.exe`, `bear-wrapper.exe`, `bear.cmd` shim)
- **Linux**: Debian packages for amd64 (with multilib), arm64, armhf, and i386
- **macOS**: DMG installer (wrapper mode, `Bear.app` with `install.sh`)

Bear v3+ is implemented in Rust. Runtime wrapper/preload lookup paths are
configured at **build time** through the `INTERCEPT_LIBDIR` env var (see
`crates/intercept-supervisor/build.rs` and
`crates/intercept-supervisor/src/installation.rs` in the Bear source). CI
sets `INTERCEPT_LIBDIR` to concrete Debian multiarch subpaths on glibc
Linux and `lib` elsewhere.

## Build Process

### Supported Build Targets

**Linux (8 targets)**:
- `x86_64-unknown-linux-gnu` (glibc high) — **with multilib**
- `x86_64-unknown-linux-gnu.2.17` (glibc 2.17) — **with multilib**
- `aarch64-unknown-linux-gnu` (glibc high)
- `aarch64-unknown-linux-gnu.2.17` (glibc 2.17)
- `armv7-unknown-linux-gnueabihf` (glibc high)
- `armv7-unknown-linux-gnueabihf.2.17` (glibc 2.17)
- `i686-unknown-linux-gnu` (glibc high)
- `i686-unknown-linux-gnu.2.17` (glibc 2.17)

**Windows (2 targets)**:
- `x86_64-pc-windows-msvc`
- `aarch64-pc-windows-msvc`

**macOS (2 targets, wrapper mode)**:
- `x86_64-apple-darwin`
- `aarch64-apple-darwin`

**`INTERCEPT_LIBDIR` per target** (matches Bear's `INSTALL.md`):
- x86_64 Linux: `lib/x86_64-linux-gnu`
- aarch64 Linux: `lib/aarch64-linux-gnu`
- armv7 Linux: `lib/arm-linux-gnueabihf`
- i686 Linux: `lib/i386-linux-gnu`
- macOS / Windows: `lib`

## Manual Build Instructions

### Prerequisites

**All Platforms**:
- Rust toolchain (1.85+, via rustup)
- Git

**Platform-Specific**:
- **Windows**: NSIS (Nullsoft Scriptable Install System)
- **Linux**: dpkg-dev, fakeroot
- **macOS**: hdiutil (built-in)
- **Cross-compilation**: Zig 0.15.2, cargo-zigbuild (`cargo install cargo-zigbuild --locked`)

### Build Steps

1. **Clone both repositories**:
```bash
git clone <this-repo> bear-prebuilt
cd bear-prebuilt
git clone https://github.com/rizsotto/Bear.git Bear
cd Bear
git checkout <version-tag>   # e.g. 4.2.2
cd ..
```

2. **Build Bear** (set `INTERCEPT_LIBDIR` per target, as described in
   Bear's `INSTALL.md`):
```bash
cd Bear

# glibc Linux — concrete multiarch subpath
INTERCEPT_LIBDIR=lib/x86_64-linux-gnu cargo zigbuild --release --target x86_64-unknown-linux-gnu

# macOS — concrete directory
INTERCEPT_LIBDIR=lib cargo zigbuild --release --target x86_64-apple-darwin

# Windows (MSVC, no Zig needed)
cargo build --release --target x86_64-pc-windows-msvc
```

3. **(Optional) Generate shell completions** (Bear's `INSTALL.md` step 3):
```bash
target/<target-triple>/release/generate-completions target/<target-triple>/release/completions
```

4. **Create installer**:
```bash
cd ..

# Windows
pwsh scripts/create-windows-installer.ps1 -Version "4.2.2" -TargetTriple "x86_64-pc-windows-msvc"

# Linux (Debian)
bash scripts/create-deb-package.sh "4.2.2" "x86_64-unknown-linux-gnu"

# macOS (wrapper mode)
bash scripts/create-macos-dmg.sh "4.2.2" "x86_64-apple-darwin"
```

5. **Find installers** in `dist/` directory.

## Installation

### Windows
```cmd
# Run installer (requires administrator)
bear-<version>-<triple>-installer.exe

# Verify installation
bear --version
```

### Linux (Debian/Ubuntu)
```bash
# Install package
sudo dpkg -i bear_<version>_<arch>-<variant>.deb

# Fix dependencies if needed
sudo apt-get install -f

# Verify installation
bear --version

# Uninstall
sudo dpkg -r bear
```

### macOS
```bash
# Mount the DMG
open bear-<version>-<triple>-wrapper.dmg

# Run the installer (from mounted volume)
sudo "/Volumes/Bear <version>/Bear.app/Contents/MacOS/install.sh"

# OR simply double-click Bear.app and enter your password

# Verify installation
bear --version

# Uninstall (manual)
sudo rm -rf /usr/libexec/bear
sudo rm /usr/local/bin/bear
```

## Repository Structure

```
bear-prebuilt/
├── .github/
│   └── workflows/
│       └── bear-build.yml            # Main CI/CD workflow
├── Bear/                             # Bear source (checked out by CI, not a submodule)
├── scripts/
│   ├── create-windows-installer.ps1  # Windows NSIS installer builder
│   ├── create-deb-package.sh         # Debian package builder
│   ├── create-macos-dmg.sh           # macOS DMG builder (wrapper mode)
│   ├── nsis/
│   │   └── bear-installer.nsi        # NSIS installer script
│   └── debian/
│       ├── control.template          # Debian package metadata
│       ├── postinst                  # Post-installation script
│       └── prerm                     # Pre-removal script
├── dist/                             # Build artifacts (generated)
├── build/                            # Build workspace (generated)
└── README.md                         # This file
```

> Bear is **not** a git submodule. CI checks out the upstream Bear
> repository at the latest release tag. For local builds, clone Bear
> into the `Bear/` directory manually.

## Key Features

### Windows
- Fixed installation directory (`C:\Program Files\Bear\`)
- Professional NSIS installer with uninstaller
- Registered in Windows Add/Remove Programs

### Linux
- Layout follows `Bear/INSTALL.md` with the **Debian multiarch
  `INTERCEPT_LIBDIR`** baked in at compile time. Each architecture's
  `bear-driver` resolves `../$INTERCEPT_LIBDIR/libexec.so` to the
  matching multiarch subdirectory:
  - amd64: `/usr/libexec/bear/lib/x86_64-linux-gnu/libexec.so`
  - arm64: `/usr/libexec/bear/lib/aarch64-linux-gnu/libexec.so`
  - armhf: `/usr/libexec/bear/lib/arm-linux-gnueabihf/libexec.so`
  - i386:  `/usr/libexec/bear/lib/i386-linux-gnu/libexec.so`
- **Multilib (amd64 only)**: ships a 32-bit `libexec.so` alongside
  the 64-bit one at `/usr/libexec/bear/lib/i386-linux-gnu/libexec.so`
  for users who run 32-bit tooling and need to inject the preload
  manually (e.g. `LD_PRELOAD=.../lib/i386-linux-gnu/libexec.so ...`).
  No 32-bit `bear-driver`/`bear-wrapper`/`bear32` entry is shipped —
  the 64-bit entry remains the single host-bits command. The `.deb`
  Recommends `libc6-i386` and Suggests `gcc-multilib` so apt pulls
  the 32-bit runtime when the user wants to use the preload.
- Per-target .deb files for glibc high and glibc 2.17 across
  amd64, arm64, armhf, and i386

### macOS (Wrapper Mode)
- DMG disk image format
- Package name includes `-wrapper` identifier
- Interactive installation via Bear.app
- Automatic symbolic link creation in `/usr/local/bin/`
- Compatible with both Intel and Apple Silicon

### CI/CD Automation
- Manual trigger (`workflow_dispatch`) on the latest upstream Bear release tag
- Parallel builds for all 12 platform targets (8 Linux + 2 Windows + 2 macOS)
- Automatic GitHub Release creation
- Comprehensive build artifacts including shell completions

## Troubleshooting

### Windows
**Issue**: Installation fails with permission error
**Solution**: Run installer as Administrator

### Linux
**Issue**: Missing dependencies
**Solution**: Run `sudo apt-get install -f` to fix dependencies

**Issue**: `bear` not found after install
**Solution**: `/usr/bin/bear` is a generated shell script that execs
`/usr/libexec/bear/bin/bear-driver`. Make sure both files are present
and executable (`dpkg -L bear | grep bear`).

### macOS
**Issue**: "bear" cannot be opened because the developer cannot be verified
**Solution**: System Preferences → Security & Privacy → Allow Bear.app, or right-click → Open

**Issue**: Installation script fails
**Solution**: Ensure you run with sudo: `sudo /Volumes/Bear\ <version>/Bear.app/Contents/MacOS/install.sh`

**Issue**: Wrapper not found
**Solution**: Verify `/usr/libexec/bear/bin/bear-wrapper` exists and is executable

## License

Bear is licensed under GPLv3. See the Bear repository for full license information.

## Links

- **Bear Official Repository**: https://github.com/rizsotto/Bear
- **Build Releases**: Check GitHub Releases for prebuilt installers

## Contributing

Contributions are welcome! Please ensure:
1. CI/CD workflow changes don't break existing builds
2. Multilib (amd64) deb packaging remains functional
3. Documentation is updated for any new features
