#!/usr/bin/env bash
set -e
set -u
set -o pipefail

TAG="$1"
TARGET="$2"

ROOT="$(pwd)"
BEAR_DIR="${ROOT}/bear"
OUT="${ROOT}/dist"

BIN="${BEAR_DIR}/target/${TARGET}/release/bear"

if [[ "$TARGET" == *windows* ]]; then
  BIN="${BIN}.exe"
fi

mkdir -p "$OUT"

ARCHIVE="bear-${TAG}-${TARGET}.tar.gz"

tar -czf "${OUT}/${ARCHIVE}" -C "$(dirname "$BIN")" "$(basename "$BIN")"
