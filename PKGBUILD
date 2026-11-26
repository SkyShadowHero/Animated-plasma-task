# Maintainer: SkyShadowHero <a1233456333@163.com>
pkgname=plasma6-applets-animated-taskmanager
_pkgname=Animated-plasma-task
pkgver=1.1.7
pkgrel=1
pkgdesc="Forked KDE Plasma 6 plasmoids with press / entry / minimize animations."
arch=('x86_64')
url="https://github.com/SkyShadowHero/Animated-plasma-task"
license=('GPL-2.0')
depends=(
    # plasma runtime: shell, applet container, private QML modules
    # (kicker, mpris, sessions, taskmanager), libnotificationmanager
    'plasma-workspace'
    'plasma5support'
    'libplasma'
    'plasma-activities'
    'plasma-activities-stats'
    'libksysguard'
    # KF6
    'kservice'
    'ki18n'
    'knotifications'
    'kiconthemes'
    'ksvg'
    'kio'
    'krunner'
    'kdeclarative'
    'kcoreaddons'
    'kconfig'
    'kwindowsystem'
    'kglobalaccel'
    'kcmutils'
    'kitemmodels'
    # QML-only dependencies of the applets
    'kirigami'
    'kirigami-addons'
    'kpipewire'
    'plasma-pa'
    'qt6-declarative'
)
makedepends=(
    'cmake'
    'extra-cmake-modules'
)
source=(
    "${_pkgname}-${pkgver}.tar.gz::https://github.com/SkyShadowHero/Animated-plasma-task/archive/refs/tags/${pkgver}.tar.gz"
)
# The tag archive changes with every release; run `updpkgsums` once the
# ${pkgver} tag exists upstream to replace SKIP with the real checksum.
sha256sums=('SKIP')

build() {
    cmake -B build -S "${_pkgname}-${pkgver}" \
        -DCMAKE_BUILD_TYPE=None \
        -DCMAKE_INSTALL_PREFIX=/usr
    cmake --build build
}

package() {
    DESTDIR="$pkgdir" cmake --install build
}
