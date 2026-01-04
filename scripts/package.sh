#!/usr/bin/env bash
set -euo pipefail

TAG="$1"
TARGET="$2"

BIN="target/${TARGET}/release/bear"
OUT="dist"

mkdir -p "$OUT"

if [[ "$TARGET" == *windows* ]]; then
  BIN="${BIN}.exe"
fi

ARCHIVE="bear-${TAG}-${TARGET}.tar.gz"

tar -czf "${OUT}/${ARCHIVE}" -C "$(dirname "$BIN")" "$(basename "$BIN")"
