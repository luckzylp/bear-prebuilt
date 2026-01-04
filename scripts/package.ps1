#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

$TAG = $args[0]
$TARGET = $args[1]

$ROOT = (Get-Location)
$BEAR_DIR = Join-Path $ROOT "bear"
$OUT = Join-Path $ROOT "dist"

# Remove .2.17 suffix for glibc 2.17 targets when finding the binary
$BUILD_TARGET = $TARGET -replace '\.2\.17$', ''
$RELEASE_DIR = Join-Path $BEAR_DIR "target\$BUILD_TARGET\release"
Get-ChildItem $RELEASE_DIR

New-Item -ItemType Directory -Force -Path (Join-Path $OUT "bin") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OUT "libexec\bear") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OUT "man\man1") | Out-Null

# Install bear binary
Copy-Item (Join-Path $RELEASE_DIR "bear.exe") (Join-Path $OUT "bin\bear.exe")

# Install wrapper if exists
$WRAPPER = Join-Path $RELEASE_DIR "wrapper.exe"
if (Test-Path $WRAPPER)
{
    Copy-Item $WRAPPER (Join-Path $OUT "libexec\bear\wrapper.exe")
}

# Install man page if exists
$MANPAGE = Join-Path $BEAR_DIR "man\bear.1"
if (Test-Path $MANPAGE)
{
    Copy-Item $MANPAGE (Join-Path $OUT "man\man1\bear.1")
}

$ARCHIVE = "bear-${TAG}-${TARGET}.tar.gz"
$ARCHIVE_PATH = Join-Path $OUT $ARCHIVE

tar -czf $ARCHIVE_PATH -C $OUT "bin" "libexec" "man"
Remove-Item -Recurse -Force (Join-Path $OUT "bin")
Remove-Item -Recurse -Force (Join-Path $OUT "libexec")
Remove-Item -Recurse -Force (Join-Path $OUT "man")
