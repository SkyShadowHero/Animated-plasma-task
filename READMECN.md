<div align="center"><a href="README.md">English</a> | 中文</div>

# Animated Plasma Task 插件

<div align="center">
    <img src="demo.gif" alt="Animated Plasma Task 演示" />
</div>

基于 KDE Plasma 6 的 Fork 插件，添加了按压 / 入场 / 最小化动画。
~~我修复了Linux(kde)下无法使用Windows任务栏动画的bug~~

## 插件列表

- **图标任务管理器 (SkyAnimation)** — `org.kde.plasma.icontasks.skyler`
  - 按压缩放
  - 入场滑入
  - 最小化弹跳
  - 退出滑出
  - 重显弹出
  - 入场上弹
  - 重排移动
  - 悬停动画
  - 图标缩放
  - 五档动画速率
  - 后台换页提醒
  - 自定义装饰:高亮背景、指示条
- **任务管理器 (SkyAnimation)** — `org.kde.plasma.taskmanager.skyler`
  - 窗口栏显示图标和文字
  - 与图标版相同的全套动画
  - 悬停动画
  - 图标缩放
  - 五档动画速率
  - 后台换页提醒
  - 自定义装饰:高亮背景、指示条
- **应用启动器 (SkyAnimation)** — `org.kde.plasma.kickoff.skyler`
  - 按压缩放
  - 悬停动画
  - 自定义装饰:高亮背景

## 安装说明

本项目包含需要编译的 C++ 组件（`.so`），因此**不能**通过 Plasma 的“获取新小部件”（KDE Store）安装。

请用以下两种方式之一：从 [Releases 页面](https://github.com/SkyShadowHero/Animated-plasma-task/releases) 下载预编译包（`.deb` / `.rpm` / `.pkg.tar.zst`），或按下面的说明从源码编译。

预编译 `.deb`（Ubuntu / Kubuntu 26.04+）：

```bash
sudo apt install ./plasma6-applets-animated-taskmanager-*.deb
kquitapp6 plasmashell && plasmashell --replace
```

## 编译依赖

编译需要 Qt 6 / KDE Frameworks 6 / Plasma 6 的开发文件。完整的 Plasma 6 桌面环境通常已经装好了大部分。

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

> 各发行版版本不同：源码针对 Plasma 6.6–6.8 / KF6 6.24+ 开发，更旧的 Plasma 6 版本可能编译失败。

## 编译安装

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)
sudo make install
```

## 删除

```bash
sudo make uninstall
```

## 致谢

基于 KDE Plasma 原版插件，原作者 Eike Hein、Martin Graesslin、Mikel Johnson。

## 许可证

代码: GPL-2.0  
动画: CC-BY 4.0 SkyShadowHero
