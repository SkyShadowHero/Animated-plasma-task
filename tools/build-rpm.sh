#!/usr/bin/env bash
# Build an RPM package of the SkyAnimation Plasma 6 applets.
#
# RPM must be built on an RPM-based distro (Fedora/RHEL/openSUSE) because
# rpmbuild resolves BuildRequires from the local RPM database. Use a container:
#
#   distrobox create --name f42 --image fedora:42
#   distrobox enter f42
#   cd /path/to/Animated-plasma-task
#   tools/build-rpm.sh
#
# Like the other scripts this builds from the LOCAL working tree instead of a
# GitHub tag, and reads the version from CMakeLists.txt.
#
# Usage (from anywhere):
#   tools/build-rpm.sh                 # build into <project root>/build-rpm
#   BUILD_DIR=/path tools/build-rpm.sh # custom build directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build-rpm}"
_pkgname="Animated-plasma-task"

# --- version from CMakeLists.txt --------------------------------------------
version="$(sed -n 's/^project([^ ]* VERSION \([0-9.]*\)).*/\1/p' "${PROJECT_ROOT}/CMakeLists.txt" | head -1)"
if [[ -z "$version" ]]; then
    echo "ERROR: cannot read VERSION from CMakeLists.txt" >&2
    exit 1
fi

# --- sanity checks ----------------------------------------------------------
command -v rpmbuild >/dev/null 2>&1 || {
    echo "ERROR: rpmbuild not found. Run this on Fedora/RHEL/openSUSE" >&2
    echo "       (or: distrobox enter f42; sudo dnf install rpm-build)." >&2
    exit 1
}

# RPM build needs the standard ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS} tree.
# We build in an isolated BUILD_DIR instead, so rpmbuild's topdir is redirected.
for sub in BUILD RPMS SOURCES SPECS SRPMS; do
    mkdir -p "${BUILD_DIR}/${sub}"
done

# --- source tarball ----------------------------------------------------------
# Top-level dir must match the spec's %autosetup: Animated-plasma-task-<version>
tarball="${BUILD_DIR}/SOURCES/${_pkgname}-${version}.tar.gz"
tar -czf "$tarball" \
    --transform="s|^|${_pkgname}-${version}/|" \
    --exclude="./.git" \
    --exclude="./build" \
    --exclude="./build-*" \
    --exclude="./.workbuddy" \
    --exclude="./tools" \
    -C "$PROJECT_ROOT" .
echo "Source tarball: $(basename "$tarball")"

# --- local spec --------------------------------------------------------------
# Point Source0 at the local tarball, and pin Version to the CMake version.
spec="${BUILD_DIR}/SPECS/plasma6-applets-animated-taskmanager.spec"
cp "${PROJECT_ROOT}/plasma6-applets-animated-taskmanager.spec" "$spec"
sed -i "s|^Version:.*|Version:        ${version}|" "$spec"
sed -i "s|^Source0:.*|Source0:        ${_pkgname}-${version}.tar.gz|" "$spec"

# --- build -------------------------------------------------------------------
# --define '_topdir ...' keeps everything inside BUILD_DIR; --nodeps lets it
# build even if the container lacks every BuildRequires package installed.
rpmbuild -bb \
    --define "_topdir ${BUILD_DIR}" \
    --nodeps \
    "$spec"

echo
echo "RPM package:"
find "${BUILD_DIR}/RPMS" -name '*.rpm' -exec ls -lh {} +
