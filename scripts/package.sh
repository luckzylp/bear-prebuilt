#!/usr/bin/env bash
set -e
set -u
set -o pipefail

TAG="$1"
TARGET="$2"

ROOT="$(pwd)"
BEAR_DIR="${ROOT}/bear"
OUT="${ROOT}/dist"

# Remove .2.17 suffix for glibc 2.17 targets when finding the binary
BUILD_TARGET="${TARGET%.2.17}"
RELEASE_DIR="${BEAR_DIR}/target/${BUILD_TARGET}/release"
ls "${RELEASE_DIR}" -al

mkdir -p "${OUT}/bin"
mkdir -p "${OUT}/libexec/bear"
mkdir -p "${OUT}/man/man1"

# Install bear binary
cp "${RELEASE_DIR}/bear" "${OUT}/bin/"

# Install wrapper if exists
if [[ -f "${RELEASE_DIR}/wrapper" ]]; then
  cp "${RELEASE_DIR}/wrapper" "${OUT}/libexec/bear/"
fi

# Install libexec.so if exists
if [[ -f "${RELEASE_DIR}/libexec.so" ]]; then
  cp "${RELEASE_DIR}/libexec.so" "${OUT}/libexec/bear/"
fi

# Install man page if exists
if [[ -f "${BEAR_DIR}/man/bear.1" ]]; then
  cp "${BEAR_DIR}/man/bear.1" "${OUT}/man/man1/"
fi

ARCHIVE="bear-${TAG}-${TARGET}.tar.gz"

tar -czf "${OUT}/${ARCHIVE}" -C "${OUT}" "bin" "libexec" "man"
rm -rf "${OUT}/bin" "${OUT}/libexec" "${OUT}/man"
