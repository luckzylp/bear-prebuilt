# Bear v4+ Multi-Platform Deployment

This repository contains scripts and GitHub Actions workflows to build platform-specific installers for Bear (compilation database generation tool) with custom installation paths.

## 🎯 Overview

Automated build system for Bear with platform-specific configurations, aligned
with the installation layout described in Bear's upstream
[`INSTALL.md`](https://github.com/rizsotto/Bear/blob/main/INSTALL.md).

- **Windows**: NSIS installer with fixed installation path
- **Linux**: Debian packages for amd64 (with multilib), arm64, armhf, and i386
- **macOS**: Native .pkg installer (wrapper mode)

Bear v3+ is implemented in Rust and configures its runtime wrapper/preload
lookup directory at **build time** through the `INTERCEPT_LIBDIR` env var — see
`bear/build.rs`. The `patch-build-rs-*.sh` scripts in this repo predated that
rewrite and are no longer invoked by CI; runtime paths are baked in via
`INTERCEPT_LIBDIR=$LIB` on glibc Linux and `INTERCEPT_LIBDIR=lib` elsewhere.

## 🚀 Build Process

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

**macOS (2 targets - wrapper mode)**:
- `x86_64-apple-darwin` → `bear-<version>-x86_64-apple-darwin-wrapper.dmg`
- `aarch64-apple-darwin` → `bear-<version>-aarch64-apple-darwin-wrapper.dmg`

**Default `INTERCEPT_LIBDIR` per target** (matches Bear's `INSTALL.md`):
- x86_64 Linux: `lib/x86_64-linux-gnu`
- aarch64 Linux: `lib/aarch64-linux-gnu`
- armv7 Linux: `lib/arm-linux-gnueabihf`
- i686 Linux: `lib/i386-linux-gnu`
- macOS / Windows: `lib`

## 📋 Manual Build Instructions

### Prerequisites

**All Platforms**:
- Rust toolchain (via rustup)
- Git

**Platform-Specific**:
- **Windows**: NSIS (Nullsoft Scriptable Install System)
- **Linux**: dpkg-dev, fakeroot
- **macOS**: pkgbuild (built-in)
- **Cross-compilation**: Zig 0.15.2, cargo-zigbuild

### Build Steps

1. **Clone the repository**:
```bash
git clone <this-repo>
cd bear-prebuilt
git submodule update --init --recursive
```

2. **Build Bear** (set `INTERCEPT_LIBDIR` per target, as described in
   Bear's `INSTALL.md`):
```bash
cd Bear

# glibc Linux — defer the library directory to the dynamic linker
INTERCEPT_LIBDIR='$LIB' cargo zigbuild --release --target <target-triple>

# macOS / Windows / non-glibc — concrete directory
INTERCEPT_LIBDIR=lib cargo zigbuild --release --target <target-triple>   # macOS
cargo build --release --target <target-triple>                            # Windows (MSVC)
```

3. **(Optional) Generate shell completions** (Bear's `INSTALL.md` step 3):
```bash
target/release/generate-completions target/<target-triple>/release/completions
```

4. **Create installer**:
```bash
cd ..

# Windows
pwsh scripts/create-windows-installer.ps1 -Version "4.0.2" -TargetTriple "x86_64-pc-windows-msvc"

# Linux (Debian)
bash scripts/create-deb-package.sh "4.1.4" "x86_64-unknown-linux-gnu"

# macOS (wrapper mode)
bash scripts/create-macos-dmg.sh "4.0.2" "x86_64-apple-darwin"
```

5. **Find installers** in `dist/` directory:
- Windows: `dist/x86_64-pc-windows-msvc-installer.exe`
- Linux: `dist/x86_64-unknown-linux-gnu.deb`
- macOS: `dist/bear-4.0.2-x86_64-apple-darwin-wrapper.dmg`

## 📦 Installation

### Windows
```cmd
# Run installer (requires administrator)
bear-<version>-windows-installer.exe

# Verify installation
bear --version
```

### Linux (Debian/Ubuntu)
```bash
# Install package
sudo dpkg -i bear_<version>_amd64.deb

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
open bear-<version>-x86_64-apple-darwin-wrapper.dmg

# Run the installer (from mounted volume)
sudo "/Volumes/Bear <version>/Bear.app/Contents/MacOS/install.sh"

# OR simply double-click Bear.app and enter your password

# Verify installation
bear --version

# Uninstall (manual)
sudo rm -rf /usr/lib/libexec/bear
sudo rm /usr/local/bin/bear
```

## 🗂️ Repository Structure

```
bear-prebuilt/
├── .github/
│   └── workflows/
│       └── bear-build.yml            # Main CI/CD workflow
├── Bear/                             # Bear submodule
├── scripts/
│   ├── patch-build-rs-windows.sh     # Legacy: no-op since Bear v3 (Rust rewrite)
│   ├── patch-build-rs-linux.sh       # Legacy: no-op since Bear v3 (Rust rewrite)
│   ├── patch-build-rs-macos.sh       # Legacy: no-op since Bear v3 (Rust rewrite)
│   ├── create-windows-installer.ps1  # Windows NSIS installer builder
│   ├── create-deb-package.sh         # Debian package builder (PREFIX=/usr, INTERCEPT_LIBDIR=lib/<multiarch>)
│   ├── create-macos-dmg.sh           # macOS .dmg builder (wrapper mode)
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

> The `patch-build-rs-*.sh` scripts are kept for historical reference. The
> upstream `Bear/bear/build.rs` no longer contains `DEFAULT_WRAPPER_PATH` or
> `DEFAULT_PRELOAD_PATH` constants — runtime lookup is configured through the
> `INTERCEPT_LIBDIR` env var at build time. CI sets this variable instead of
> running the patches.

## 🔍 Key Features

### ✅ Windows
- Fixed installation directory (`C:\Program Files\Bear\`)
- Professional NSIS installer with uninstaller
- Registered in Windows Add/Remove Programs

### ✅ Linux
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

### ✅ macOS (Wrapper Mode)
- Native .dmg disk image format
- Package name includes `-wrapper` identifier
- Interactive installation via Bear.app
- Automatic symbolic link creation in `/usr/local/bin/`
- Compatible with both Intel and Apple Silicon

### ✅ CI/CD Automation
- Manual trigger (`workflow_dispatch`) on the latest upstream Bear release tag
- Parallel builds for all 12 platform targets (8 Linux + 2 Windows + 2 macOS)
- Automatic GitHub Release creation
- Comprehensive build artifacts including shell completions

## 🛠️ Troubleshooting

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
**Solution**: Verify `/usr/lib/libexec/bear/bear-wrapper` exists and is executable

## 📄 License

Bear is licensed under GPLv3. See the Bear repository for full license information.

## 🔗 Links

- **Bear Official Repository**: https://github.com/rizsotto/Bear
- **Build Releases**: Check GitHub Releases for prebuilt installers

## 🤝 Contributing

Contributions are welcome! Please ensure:
1. Platform-specific patches are tested locally
2. CI/CD workflow changes don't break existing builds
3. Documentation is updated for any new features

---

**Note**: macOS builds use wrapper mode by default and are packaged as DMG disk images with the `-wrapper` suffix in filenames.
