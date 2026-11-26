<div align="center">English | <a href="READMECN.md">中文</a></div>

# Animated Plasma Task Plugins

<div align="center">
    <img src="demo.gif" alt="Animated Plasma Task Demo" />
</div>

Forked KDE Plasma 6 plasmoids with press / entry / minimize animations.

## Plugins

- **Icons-Only Task Manager (SkyAnimation)** — `org.kde.plasma.icontasks.skyler`
  - press scale
  - entry slide-in
  - minimize bounce
  - exit slide-out
  - reappear pop-up
  - entry bump
  - reorder move
  - hover animation
  - icon scale
  - 5-speed animation
  - background page-change bounce
  - custom decorations: highlight background, indicator bar
- **Task Manager (SkyAnimation)** — `org.kde.plasma.taskmanager.skyler`
  - window bar showing icons and text
  - same animation set as the icons-only variant
  - hover animation
  - icon scale
  - 5-speed animation
  - background page-change bounce
  - custom decorations: highlight background, indicator bar
- **Application Launcher (SkyAnimation)** — `org.kde.plasma.kickoff.skyler`
  - press scale
  - hover animation
  - custom decorations: highlight background

## Installation note

This project contains a compiled C++ part (`.so`), so it **cannot** be installed
through Plasma's *Get New Widgets* (KDE Store).

Use either a prebuilt package from the
[Releases page](https://github.com/SkyShadowHero/Animated-plasma-task/releases)
(`.deb` / `.rpm` / `.pkg.tar.zst`), or build from source as described below.

Prebuilt `.deb` (Ubuntu / Kubuntu 26.04+):

```bash
sudo apt install ./plasma6-applets-animated-taskmanager-*.deb
kquitapp6 plasmashell && plasmashell --replace
```

## Build dependencies

Building requires Qt 6 / KDE Frameworks 6 / Plasma 6 development files. On a
full Plasma 6 desktop most of these are already installed.

**Arch Linux / CachyOS**

```bash
sudo pacman -S base-devel cmake extra-cmake-modules gettext \
  qt6-base qt6-declarative \
  ki18n knotifications kservice kwindowsystem kconfig kio kitemmodels \
  libplasma plasma-activities plasma-activities-stats libksysguard \
  plasma-workspace
```

**Ubuntu / Kubuntu 26.04+**

```bash
sudo apt install build-essential cmake extra-cmake-modules gettext \
  qt6-base-dev qt6-declarative-dev \
  libkf6i18n-dev libkf6notifications-dev libkf6service-dev \
  libkf6windowsystem-dev libkf6config-dev libkf6kio-dev libkf6itemmodels-dev \
  libplasma-dev libplasmaactivities-dev libplasmaactivitiesstats-dev \
  libksysguard-dev plasma-workspace-dev
```

**Fedora 43+**

```bash
sudo dnf install gcc-c++ cmake extra-cmake-modules gettext \
  qt6-qtbase-devel qt6-qtdeclarative-devel \
  kf6-ki18n-devel kf6-knotifications-devel kf6-kservice-devel \
  kf6-kwindowsystem-devel kf6-kconfig-devel kf6-kio-devel kf6-kitemmodels-devel \
  libplasma-devel plasma-activities-devel plasma-activities-stats-devel \
  libksysguard-devel plasma-workspace-devel
```

> Versions vary by distro: the source is developed against Plasma 6.6–6.8 /
> KF6 6.24+. Older Plasma 6 releases may fail to compile.

## Build & Install

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)
sudo make install
```

## Uninstall

```bash
sudo make uninstall
```

Restart plasmashell:
```bash
plasmashell --replace &
```

Right-click panel → Add Widgets.

## Credits

Based on KDE Plasma plasmoids by Eike Hein, Martin Graesslin, and Mikel Johnson.

## License

Code: GPL-2.0  
Animations: CC-BY 4.0 SkyShadowHero
