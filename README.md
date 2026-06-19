# SkyAnimation Plasma Plugins

Forked KDE Plasma 6 plasmoids with press / entry / minimize animations.

## Plugins

| Plugin | ID | Animations |
|--------|-----|------------|
| Icons-Only Task Manager (SkyAnimation) | `org.kde.plasma.icontasks.skyler` | press scale · entry slide-in · minimize bounce |
| Application Launcher (SkyAnimation) | `org.kde.plasma.kickoff.skyler` | press scale |

## Requirements (Arch / CachyOS)

```bash
sudo pacman -S --needed cmake extra-cmake-modules qt6-declarative \
    kf6-plasma kf6-kio kf6-notifications kf6-service kf6-windowsystem \
    plasma-activities plasma-activities-stats libksysguard libnotificationmanager
```

## Build & Install

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)
sudo make install
rm -rf ~/.cache/plasma* ~/.cache/kpackage*
systemctl restart --user plasma-plasmashell
```

Right-click panel → Add Widgets → search **SkyAnimation**.

## Rebuild after changes

```bash
cd build && make -j$(nproc) && sudo make install
systemctl restart --user plasma-plasmashell
```

## License

GPL-2.0-or-later

---

# SkyAnimation Plasma 插件

基于 KDE Plasma 6 的 Fork 插件，添加了按压 / 入场 / 最小化动画。

## 插件列表

| 插件 | ID | 动画 |
|------|-----|------|
| 图标任务管理器 (SkyAnimation) | `org.kde.plasma.icontasks.skyler` | 按压缩放 · 入场滑入 · 最小化弹跳 |
| 应用启动器 (SkyAnimation) | `org.kde.plasma.kickoff.skyler` | 按压缩放 |

## 依赖 (Arch / CachyOS)

```bash
sudo pacman -S --needed cmake extra-cmake-modules qt6-declarative \
    kf6-plasma kf6-kio kf6-notifications kf6-service kf6-windowsystem \
    plasma-activities plasma-activities-stats libksysguard libnotificationmanager
```

## 构建安装

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)
sudo make install
rm -rf ~/.cache/plasma* ~/.cache/kpackage*
systemctl restart --user plasma-plasmashell
```

面板右键 → 添加部件 → 搜索 **SkyAnimation**。

## 修改后重新构建

```bash
cd build && make -j$(nproc) && sudo make install
systemctl restart --user plasma-plasmashell
```

## 许可证

GPL-2.0-or-later
