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
  - custom decorations: highlight background, indicator bar
- **Application Launcher (SkyAnimation)** — `org.kde.plasma.kickoff.skyler`
  - press scale
  - hover animation
  - custom decorations: highlight background

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
