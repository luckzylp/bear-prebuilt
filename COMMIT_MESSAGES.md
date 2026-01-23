# Git Commit Messages for Bear Multi-Platform Deployment

## Main Feature Commit

```bash
git add .
git commit -m "feat: add platform-specific installers with custom installation paths

Implement comprehensive multi-platform deployment system for Bear with
custom installation paths, multilib support, and platform-specific
packaging formats.

Features:
- Windows: NSIS installer with fixed installation path
- Linux: Debian packages with x64 multilib support
- macOS: DMG disk images with wrapper mode identifier
- Platform-specific build.rs patches via sed commands
- Automated CI/CD pipeline for all 14 targets

BREAKING CHANGES:
- Installation paths changed from /usr/local to platform-specific locations
- macOS packages now use DMG format instead of PKG

Closes #XXX"
```

---

## Detailed Breakdown (Alternative: Multiple Commits)

If you prefer to commit in logical groups:

### 1. Platform Patch Scripts

```bash
git add scripts/patch-build-rs-*.sh
git commit -m "feat(build): add platform-specific build.rs patch scripts

Add sed-based patch scripts to modify Bear's build.rs file with
custom installation paths for each platform:

- patch-build-rs-windows.sh: Set DEFAULT_WRAPPER_PATH to 'C:/Program Files/Bear'
- patch-build-rs-linux.sh: Set paths to '/usr/lib/libexec/bear'
- patch-build-rs-macos.sh: Set paths to '/usr/lib/libexec/bear'

All scripts create backups (.bak) before modification and verify changes.

Related to: Windows installer, Debian packages, macOS DMG"
```

### 2. Windows Installer

```bash
git add scripts/create-windows-installer.ps1 scripts/nsis/
git commit -m "feat(windows): add NSIS installer with fixed installation path

Implement Windows installer using NSIS with the following features:
- Fixed installation directory: C:\Program Files\Bear (non-modifiable)
- Automatic PATH environment variable configuration
- Uninstaller with complete cleanup
- Windows Add/Remove Programs integration
- Administrator privilege enforcement

Files:
- scripts/nsis/bear-installer.nsi: NSIS installer script
- scripts/create-windows-installer.ps1: PowerShell build script

The installer automatically adds Bear to the system PATH and creates
proper registry entries for Windows integration."
```

### 3. Linux Debian Packages with Multilib

```bash
git add scripts/create-deb-package.sh scripts/debian/
git commit -m "feat(linux): add Debian packages with x64 multilib support

Implement Debian package builder with special x64 multilib support:

Features:
- Installation path: /usr/lib/libexec/bear/
- x64 packages include both x86_64 and i386 preload libraries
- Automatic i686 library compilation for 32-bit support
- Architecture-specific library directories (x86_64-linux-gnu, i386-linux-gnu)
- Symbolic link creation in /usr/bin/bear
- Full Debian package compliance (control, postinst, prerm)

This enables x64 systems to intercept both 64-bit and 32-bit compiler
invocations using the \$LIB path variable expansion.

Files:
- scripts/create-deb-package.sh: Main package builder
- scripts/debian/control.template: Package metadata template
- scripts/debian/postinst: Post-installation script
- scripts/debian/prerm: Pre-removal script"
```

### 4. macOS DMG Packages

```bash
git add scripts/create-macos-dmg.sh
git commit -m "feat(macos): add DMG disk image packages with wrapper mode

Implement macOS DMG package builder with wrapper mode identifier:

Features:
- DMG disk image format (UDZO compressed)
- Package naming: bear-<version>-<arch>-wrapper.dmg
- Bear.app installer with embedded installation script
- Installation path: /usr/lib/libexec/bear/
- Automatic symbolic link to /usr/local/bin/bear
- User-friendly mount and install workflow
- README.txt with installation instructions
- Support for both Intel (x86_64) and Apple Silicon (arm64)

The DMG includes a clickable Bear.app that runs the installation
script with sudo privileges, providing a native macOS installation
experience."
```

### 5. GitHub Actions Workflow

```bash
git add .github/workflows/bear-auto-build.yml
git commit -m "feat(ci): update CI/CD workflow for platform-specific installers

Update GitHub Actions workflow to build platform-specific installers:

Changes:
- Add platform-specific patch application step (before build)
- Install packaging tools (NSIS, dpkg-dev, pkgbuild)
- Replace generic packaging with platform-specific scripts:
  * Windows: create-windows-installer.ps1 → .exe installer
  * Linux: create-deb-package.sh → .deb packages with multilib
  * macOS: create-macos-dmg.sh → .dmg disk images
- Update Bear submodule path to 'Bear' (uppercase)
- Enhance release notes with installation paths and features
- Mark legacy packaging steps as continue-on-error

All 14 platform targets now generate proper installers instead of
simple binary archives."
```

### 6. Documentation

```bash
git add README.md
git commit -m "docs: update documentation for new deployment system

Update README with comprehensive documentation for the new multi-platform
deployment system:

Changes:
- Document platform-specific installation paths
- Add macOS DMG installation instructions
- Document Linux x64 multilib support
- Update package format table (macOS: PKG → DMG)
- Add detailed build instructions for each platform
- Document Windows fixed installation path requirement
- Add troubleshooting sections for all platforms
- Update repository structure diagram
- Add wrapper mode identifier explanation for macOS

The documentation now clearly explains the installation paths,
multilib support, and platform-specific features."
```

### 7. Version Configuration

```bash
git add last_built_tag
git commit -m "chore: set current Bear version to 4.0.2

Update last_built_tag to track current Bear version 4.0.2.
This file is used by CI/CD to determine if a new build is needed."
```

---

## Single Comprehensive Commit (Recommended)

```bash
git add .
git commit -m "feat: implement multi-platform deployment with custom paths

Implement comprehensive multi-platform deployment system for Bear with
platform-specific installation paths, installers, and multilib support.

## Platform-Specific Changes

### Windows (MSVC)
- Add NSIS installer with fixed path: C:\Program Files\Bear
- Automatic PATH environment variable configuration
- Full uninstaller with registry cleanup
- Files: scripts/nsis/bear-installer.nsi, scripts/create-windows-installer.ps1

### Linux (Debian/Ubuntu)
- Add .deb package builder with x64 multilib support
- Installation path: /usr/lib/libexec/bear
- x64 packages include both x86_64 and i386 preload libraries
- Support for intercepting 32-bit and 64-bit builds on x64 systems
- Files: scripts/create-deb-package.sh, scripts/debian/*

### macOS (Darwin)
- Add DMG disk image packages (wrapper mode)
- Installation path: /usr/lib/libexec/bear
- Package naming includes '-wrapper' identifier
- User-friendly Bear.app installer with sudo support
- File: scripts/create-macos-dmg.sh

## Build System Changes

### Platform Patch Scripts
- Add sed-based build.rs patching for each platform
- Automatic backup creation before modification
- Files: scripts/patch-build-rs-{windows,linux,macos}.sh

### CI/CD Workflow
- Update GitHub Actions to use platform-specific installers
- Add tool installation steps (NSIS, dpkg-dev)
- Update Bear submodule path to 'Bear' (uppercase)
- Enhanced release notes with installation details

## Documentation
- Update README with installation paths and instructions
- Add multilib support documentation for Linux x64
- Add DMG installation guide for macOS
- Document Windows fixed installation path requirement

## Version Management
- Set current Bear version to 4.0.2 in last_built_tag

## Modified Build.rs Paths

Windows:
- DEFAULT_WRAPPER_PATH: /usr/local/libexec/bear → C:/Program Files/Bear

Linux:
- DEFAULT_WRAPPER_PATH: /usr/local/libexec/bear → /usr/lib/libexec/bear
- DEFAULT_PRELOAD_PATH: /usr/local/libexec/bear/\$LIB → /usr/lib/libexec/bear/\$LIB

macOS:
- DEFAULT_WRAPPER_PATH: /usr/local/libexec/bear → /usr/lib/libexec/bear
- DEFAULT_PRELOAD_PATH: /usr/local/libexec/bear/\$LIB → /usr/lib/libexec/bear/\$LIB

## Package Outputs

- Windows: .exe installers (NSIS)
- Linux: .deb packages (with multilib for x64)
- macOS: .dmg disk images (wrapper mode identifier)

Total targets: 14 (8 Linux, 2 Windows, 2 macOS, 2 glibc variants)

Co-authored-by: Bear Development Team <bear@example.com>"
```

---

## Usage

Choose one of the approaches above:

### Option 1: Single Commit (Recommended for clean history)
```bash
# Copy the comprehensive commit message above
git add .
git commit
# Paste the message in your editor
```

### Option 2: Multiple Commits (Better for code review)
```bash
# Commit each component separately using the messages above
git add scripts/patch-build-rs-*.sh
git commit -m "..." # Use message from section 1

git add scripts/create-windows-installer.ps1 scripts/nsis/
git commit -m "..." # Use message from section 2

# ... continue for each section
```

### Option 3: Quick Commit
```bash
git add .
git commit -m "feat: add platform-specific installers (Windows/Linux/macOS)

- Windows: NSIS installer with fixed path + auto PATH
- Linux: .deb packages with x64 multilib support
- macOS: DMG disk images with wrapper mode
- CI/CD: Automated builds for 14 platform targets
- Docs: Updated with installation instructions"
```

---

## After Committing

```bash
# Push to remote
git push origin main

# Or push to a feature branch for review
git checkout -b feat/platform-installers
git push -u origin feat/platform-installers
```

---

**Recommendation**: Use the **Single Comprehensive Commit** for a clean, well-documented commit that explains all changes in context. This makes the project history easier to understand and reference later.
