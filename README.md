<div align="center">English | <a href="READMECN.md">中文</a></div>

# Animated Plasma Task Plugins

Forked KDE Plasma 6 plasmoids with press / entry / minimize animations.

## Plugins

| Plugin | ID | Animations |
|--------|-----|------------|
| Icons-Only Task Manager (SkyAnimation) | `org.kde.plasma.icontasks.skyler` | press scale · entry slide-in · minimize bounce · exit slide-out · reappear pop-up · entry bump · reorder move |
| Task Manager (SkyAnimation) | `org.kde.plasma.taskmanager.skyler` | press scale · entry slide-in · minimize bounce · exit slide-out · reappear pop-up · entry bump · reorder move |
| Application Launcher (SkyAnimation) | `org.kde.plasma.kickoff.skyler` | press scale |

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

Code: GPL-2.0-or-later  
Animations: CC-BY 4.0 SkyShadowHero
