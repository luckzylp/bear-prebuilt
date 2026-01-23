# Bear v4+ Multi-Platform Deployment

This repository contains scripts and GitHub Actions workflows to build platform-specific installers for Bear (compilation database generation tool) with custom installation paths.

## 🎯 Overview

Automated build system for Bear with platform-specific configurations:

- **Windows**: NSIS installer with fixed installation path
- **Linux**: Debian packages with multilib support (x64 includes both 64-bit and 32-bit libraries)
- **macOS**: Native .pkg installer (wrapper mode)

## 📦 Installation Paths

| Platform | Installation Path | Mode | Package Format |
|----------|------------------|------|----------------|
| **Windows** | `C:\Program Files\Bear\` | Standard | `.exe` installer |
| **Linux** | `/usr/lib/libexec/bear/` | Standard | `.deb` package |
| **macOS** | `/usr/lib/libexec/bear/` | **Wrapper** | `.dmg` disk image |

## 🔧 Platform-Specific Configurations

### Windows (MSVC)
- **Installation Path**: `C:\Program Files\Bear\` (fixed, cannot be modified)
- **Build.rs Modification**: `DEFAULT_WRAPPER_PATH = "C:/Program Files/Bear"`
- **Installer Features**:
  - NSIS-based installer
  - Uninstaller included
  - Registered in Windows Add/Remove Programs
  - Requires administrator privileges

### Linux (Ubuntu/Debian)
- **Installation Path**: `/usr/lib/libexec/bear/`
- **Build.rs Modifications**:
  - `DEFAULT_WRAPPER_PATH = "/usr/lib/libexec/bear"`
  - `DEFAULT_PRELOAD_PATH = "/usr/lib/libexec/bear/$LIB"`
- **Multilib Support (x64 only)**:
  - x86_64 libraries: `/usr/lib/libexec/bear/x86_64-linux-gnu/`
  - i386 libraries: `/usr/lib/libexec/bear/i386-linux-gnu/`
  - Supports intercepting both 64-bit and 32-bit compiler invocations
- **Post-installation**: Creates symlink `/usr/bin/bear` → `/usr/lib/libexec/bear/bear`

### macOS (Darwin) - Wrapper Mode
- **Installation Path**: `/usr/lib/libexec/bear/`
- **Mode**: Wrapper (default for macOS)
- **Package Format**: DMG disk image
- **Package Naming**: Includes `-wrapper` suffix (e.g., `bear-4.0.2-x86_64-apple-darwin-wrapper.dmg`)
- **Build.rs Modifications**:
  - `DEFAULT_WRAPPER_PATH = "/usr/lib/libexec/bear"`
  - `DEFAULT_PRELOAD_PATH = "/usr/lib/libexec/bear/$LIB"`
- **Installation Method**: 
  1. Mount DMG by double-clicking
  2. Run Bear.app installer (requires sudo password)
  3. Automatic symbolic link creation in `/usr/local/bin/`

## 🚀 Build Process

### Automated Builds (GitHub Actions)

The repository automatically:
1. Checks for new Bear releases every 30 minutes
2. Builds all platform targets when a new release is detected
3. Creates platform-specific installers
4. Publishes to GitHub Releases

### Supported Build Targets

**Linux (8 targets)**:
- `x86_64-unknown-linux-gnu` (glibc high) - **with multilib**
- `x86_64-unknown-linux-gnu.2.17` (glibc 2.17) - **with multilib**
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

2. **Apply platform patches**:
```bash
# Windows
bash scripts/patch-build-rs-windows.sh

# Linux
bash scripts/patch-build-rs-linux.sh

# macOS
bash scripts/patch-build-rs-macos.sh
```

3. **Build Bear**:
```bash
cd Bear

# Linux/macOS (with zigbuild)
cargo zigbuild --release --target <target-triple>

# Windows (native)
cargo build --release --target <target-triple>
```

4. **Create installer**:
```bash
cd ..

# Windows
pwsh scripts/create-windows-installer.ps1 -Version "4.0.2" -TargetTriple "x86_64-pc-windows-msvc"

# Linux (with multilib for x64)
bash scripts/create-deb-package.sh "4.0.2" "x86_64-unknown-linux-gnu"

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
│       └── bear-auto-build.yml       # Main CI/CD workflow
├── Bear/                             # Bear submodule
├── scripts/
│   ├── patch-build-rs-windows.sh     # Windows build.rs patcher
│   ├── patch-build-rs-linux.sh       # Linux build.rs patcher
│   ├── patch-build-rs-macos.sh       # macOS build.rs patcher
│   ├── create-windows-installer.ps1  # Windows NSIS installer builder
│   ├── create-deb-package.sh         # Debian package builder (with multilib)
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

## 🔍 Key Features

### ✅ Windows
- Fixed installation directory (`C:\Program Files\Bear\`)
- Professional NSIS installer with uninstaller
- Registered in Windows Add/Remove Programs

### ✅ Linux (x64 with Multilib)
- Supports both 64-bit and 32-bit builds simultaneously
- Architecture-specific library directories using `$LIB` expansion
- Automatic symbolic link creation in `/usr/bin/`
- Full Debian package compliance

### ✅ macOS (Wrapper Mode)
- Native .dmg disk image format
- Package name includes `-wrapper` identifier
- Interactive installation via Bear.app
- Automatic symbolic link creation in `/usr/local/bin/`
- Compatible with both Intel and Apple Silicon

### ✅ CI/CD Automation
- Automatic detection of new Bear releases
- Parallel builds for all 14 platform targets
- Automatic GitHub Release creation
- Comprehensive build artifacts

## 🛠️ Troubleshooting

### Windows
**Issue**: Installation fails with permission error  
**Solution**: Run installer as Administrator

### Linux
**Issue**: 32-bit builds not intercepted on x64  
**Solution**: Ensure both x86_64 and i386 libraries are present in `/usr/lib/libexec/bear/`

**Issue**: Missing dependencies  
**Solution**: Run `sudo apt-get install -f` to fix dependencies

### macOS
**Issue**: "bear" cannot be opened because the developer cannot be verified  
**Solution**: System Preferences → Security & Privacy → Allow Bear.app, or right-click → Open

**Issue**: Installation script fails  
**Solution**: Ensure you run with sudo: `sudo /Volumes/Bear\ <version>/Bear.app/Contents/MacOS/install.sh`

**Issue**: Wrapper not found  
**Solution**: Verify `/usr/lib/libexec/bear/wrapper` exists and is executable

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
