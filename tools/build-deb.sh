#!/usr/bin/env bash
# Build an installable .deb of the SkyAnimation Plasma 6 applets.
#
# Run this INSIDE a Debian/Ubuntu-based container or machine that matches the
# target system (for Kubuntu 26.04 use the `k26` distrobox), because CPack's
# SHLIBDEPS resolves library dependencies from the local dpkg database.
#
# Usage (from anywhere):
#   tools/build-deb.sh                 # build in <project root>/build-deb
#   BUILD_DIR=/path tools/build-deb.sh # custom build directory
#
# Output: <build dir>/plasma6-applets-animated-taskmanager-<version>-Linux.deb
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build-deb}"

# --- sanity checks ---------------------------------------------------------
# CPack's SHLIBDEPS needs both `file` and `dpkg-shlibdeps`; without `file` it
# fails late with "CPackDeb: file utility is not available".
missing_tools=()
for tool in file dpkg-shlibdeps; do
    command -v "$tool" >/dev/null 2>&1 || missing_tools+=("$tool")
done
if ((${#missing_tools[@]})); then
    echo "ERROR: missing CPack DEB tools: ${missing_tools[*]}" >&2
    echo "       Install with: sudo apt install file dpkg-dev" >&2
    echo "       Run this on a Debian/Ubuntu system (Kubuntu 26.04: distrobox enter k26)" >&2
    exit 1
fi

missing=()
for pkg in build-essential cmake extra-cmake-modules gettext dpkg-dev \
           libkf6config-dev libkf6i18n-dev libkf6notifications-dev \
           libkf6service-dev libkf6windowsystem-dev libkf6kio-dev \
           libplasma-dev libplasmaactivities-dev libplasmaactivitiesstats-dev \
           libksysguard-dev plasma-workspace-dev; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        missing+=("$pkg")
    fi
done
if ((${#missing[@]})); then
    echo "ERROR: missing build dependencies:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    echo "Install them with:" >&2
    echo "  sudo apt install ${missing[*]}" >&2
    exit 1
fi

# Qt6 Quick lives in qt6-declarative-dev, not qt6-base-dev.
for pkg in qt6-base-dev qt6-declarative-dev; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "ERROR: missing $pkg (Qt6 Quick needs qt6-declarative-dev)" >&2
        exit 1
    fi
done

# --- configure & build -----------------------------------------------------
# Install prefix MUST be /usr so packaged files land in the right place.
# Clear the build dir to avoid inheriting a previous ~/.local prefix cache.
rm -rf "$BUILD_DIR"
cmake -S "$PROJECT_ROOT" -B "$BUILD_DIR" -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "$BUILD_DIR" --parallel "$(nproc)"

# --- package ---------------------------------------------------------------
(cd "$BUILD_DIR" && cpack -G DEB)

# --- relax pinned dependency versions --------------------------------------
# dpkg-shlibdeps emits exact pins for private ABI packages, e.g.
#   qt6-declarative-private-abi (= 6.10.2)
# A single .deb published in a GitHub release must not be tied to one Qt point
# release. Strip every parenthesised version constraint from the generated
# control file, keeping the package names so apt still pulls in the runtime
# libraries. This makes one binary usable across the Plasma 6 / Qt 6 family.
for deb in "$BUILD_DIR"/*.deb; do
    [[ -e "$deb" ]] || continue
    workdir="$(mktemp -d)"
    dpkg-deb -R "$deb" "$workdir"
    sed -i -E '/^Depends:/ s/ \([^)]*\)//g' "$workdir/DEBIAN/control"
    # Fail loudly if the rewrite missed anything, instead of shipping a deb
    # that is still pinned to one Ubuntu point release.
    if grep -qE '^Depends:.*\(' "$workdir/DEBIAN/control"; then
        echo "ERROR: version constraints remain in $deb" >&2
        rm -rf "$workdir"
        exit 1
    fi
    dpkg-deb -b "$workdir" "$deb" >/dev/null
    rm -rf "$workdir"
done
