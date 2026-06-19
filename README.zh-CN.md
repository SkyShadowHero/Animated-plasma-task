# SkyAnimation Plasma 插件

基于 KDE Plasma 6 的 Fork 插件，添加了按压 / 入场 / 最小化动画。

## 插件列表

| 插件 | ID | 动画 |
|------|-----|------|
| 图标任务管理器 (SkyAnimation) | `org.kde.plasma.icontasks.skyler` | 按压缩放 · 入场滑入 · 最小化弹跳 |
| 应用启动器 (SkyAnimation) | `org.kde.plasma.kickoff.skyler` | 按压缩放 |

## 构建安装

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)
sudo make install
```

面板右键 → 添加部件 → 搜索 **SkyAnimation**。

## 许可证

GPL-2.0-or-later
