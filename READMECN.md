<div align="center"><a href="README.md">English</a> | 中文</div>

# Animated Plasma Task 插件

基于 KDE Plasma 6 的 Fork 插件，添加了按压 / 入场 / 最小化动画。

## 插件列表

| 插件 | ID | 动画 |
|------|-----|------|
| 图标任务管理器 (SkyAnimation) | `org.kde.plasma.icontasks.skyler` | 按压缩放 · 入场滑入 · 最小化弹跳 · 退出滑出 · 重显弹出 · 入场上弹 · 重排移动 |
| 任务管理器 (SkyAnimation) | `org.kde.plasma.taskmanager.skyler` | 按压缩放 · 入场滑入 · 最小化弹跳 · 退出滑出 · 重显弹出 · 入场上弹 · 重排移动 |
| 应用启动器 (SkyAnimation) | `org.kde.plasma.kickoff.skyler` | 按压缩放 |

## 安装

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

代码: GPL-2.0-or-later  
动画: CC-BY 4.0 SkyShadowHero
