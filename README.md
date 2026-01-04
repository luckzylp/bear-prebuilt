# Bear Prebuilt Binaries

Automated prebuilt binaries for **rizsotto/Bear**.

## Features

- Auto-detect upstream Bear releases
- cargo + zigbuild
- Linux:
  - glibc (high)
  - glibc 2.17 (CentOS 7 compatible)
  - x86 / x86_64 multilib
- Windows: x86_64 / aarch64
- macOS: x86_64 / arm64

## Release Tags
# Bear Prebuilt Binaries

Automated prebuilt binaries for **rizsotto/Bear**.

## Features

- Auto-detect upstream Bear releases
- cargo + zigbuild
- Linux:
  - glibc (high)
  - glibc 2.17 (CentOS 7 compatible)
  - x86 / x86_64 multilib
- Windows: x86_64 / aarch64
- macOS: x86_64 / arm64

## Release Tags

bear-vX.Y.Z

## Notes

### 32-bit Linux
To run 32-bit binaries on 64-bit Linux:

```bash
sudo dpkg --add-architecture i386
sudo apt install libc6:i386
