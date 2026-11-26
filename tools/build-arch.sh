#!/usr/bin/env bash
# Build an Arch Linux package (.pkg.tar.zst) of the SkyAnimation Plasma 6 applets.
#
# Unlike the stock PKGBUILD, this does NOT download from a GitHub tag — it
# builds from the LOCAL working tree, so you can ship a release before the tag
# is pushed. The version is read from CMakeLists.txt so it can never drift.
#
# Run on Arch Linux / CachyOS (makepkg + fakeroot required).
#
# Usage (from anywhere):
#   tools/build-arch.sh                 # build into <project root>/build-arch
#   BUILD_DIR=/path tools/build-arch.sh # custom build directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build-arch}"
_pkgname="Animated-plasma-task"

# --- version from CMakeLists.txt --------------------------------------------
version="$(sed -n 's/^project([^ ]* VERSION \([0-9.]*\)).*/\1/p' "${PROJECT_ROOT}/CMakeLists.txt" | head -1)"
if [[ -z "$version" ]]; then
    echo "ERROR: cannot read VERSION from CMakeLists.txt" >&2
    exit 1
fi

# --- sanity checks ----------------------------------------------------------
for tool in makepkg fakeroot tar; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "ERROR: '$tool' not found. Run this on Arch Linux (pacman -S fakeroot)." >&2
        exit 1
    }
done

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- source tarball ----------------------------------------------------------
# Top-level dir must be ${_pkgname}-${version}, matching PKGBUILD's build().
tarball="${BUILD_DIR}/${_pkgname}-${version}.tar.gz"
tar -czf "$tarball" \
    --transform="s|^|${_pkgname}-${version}/|" \
    --exclude="./.git" \
    --exclude="./build" \
    --exclude="./build-*" \
    --exclude="./.workbuddy" \
    --exclude="./tools" \
    -C "$PROJECT_ROOT" .
echo "Source tarball: $(basename "$tarball")"

# --- local PKGBUILD ----------------------------------------------------------
# Point source at the local tarball and pin pkgver to the CMake version.
cp "${PROJECT_ROOT}/PKGBUILD" "${BUILD_DIR}/PKGBUILD"
sed -i "/^source=(/,/^)/c\\source=(\"${_pkgname}-${version}.tar.gz\")" "${BUILD_DIR}/PKGBUILD"
sed -i "s/^pkgver=.*/pkgver=${version}/" "${BUILD_DIR}/PKGBUILD"

# --- build -------------------------------------------------------------------
cd "$BUILD_DIR"
makepkg --clean --force

echo
echo "Arch package:"
ls -lh "$BUILD_DIR"/*.pkg.tar.zst
