#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

$TAG = $args[0]
$TARGET = $args[1]

$ROOT = (Get-Location)
$BEAR_DIR = Join-Path $ROOT "bear"
$OUT = Join-Path $ROOT "dist"

$BIN = Join-Path $BEAR_DIR "target\$TARGET\release\bear.exe"

New-Item -ItemType Directory -Force -Path $OUT | Out-Null

$ARCHIVE = "bear-${TAG}-${TARGET}.tar.gz"
$ARCHIVE_PATH = Join-Path $OUT $ARCHIVE

tar -czf $ARCHIVE_PATH -C (Split-Path $BIN) (Split-Path $BIN -Leaf)
