pkgname=plasma6-applets-animated-taskmanager
_pkgname=Animated-plasma-task
pkgver=1.0.4
pkgrel=1
pkgdesc="Forked KDE Plasma 6 plasmoids with press / entry / minimize animations."
arch=('x86_64')
url="https://github.com/SkyShadowHero/skyler-plasma-taskmanager"
license=('GPL-2.0-or-later')
depends=(
    'plasma-workspace'
    'kservice'
    'kirigami'
    'kiconthemes'
    'ksvg'
    'kio'
    'krunner'
    'kdeclarative'
    'qt6-declarative'
    'kcoreaddons'
    'kconfig'
    'kwindowsystem'
    'kglobalaccel'
    'kcmutils'
    'libplasma'
    'plasma-activities-stats'
)
makedepends=(
    'cmake'
    'extra-cmake-modules'
)
source=(
    "${_pkgname}-${pkgver}.tar.gz::https://github.com/SkyShadowHero/skyler-plasma-taskmanager/archive/refs/tags/${pkgver}.tar.gz"
)

sha256sums=('1d2e2c6f2a26280d94558a9079a90b4fec14bab4150a575acd37341d12bb9011')

build() {
    cmake -B build -S "${_pkgname}-${pkgver}" \
        -DCMAKE_BUILD_TYPE=None \
        -DCMAKE_INSTALL_PREFIX=/usr 
    cmake --build build
}

package() {
    DESTDIR="$pkgdir" cmake --install build
}
