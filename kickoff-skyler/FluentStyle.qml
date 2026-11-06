/* SPDX-FileCopyrightText: 2026 SkyShadowHero <skyler@example.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import org.kde.kirigami as Kirigami

/**
 * Design tokens for the optional Fluent (Windows 11 / WinUI 3) styling of the
 * launcher popup.
 *
 * Everything here is theme-derived, so the style keeps following the system
 * light/dark colour scheme instead of hardcoding white/black. The switch that
 * turns the style on lives in main.xml (`useFluentStyle`); this singleton only
 * holds values, because applet configuration is not reachable from a singleton
 * (see KickoffSingleton.qml for the same restriction).
 */
QtObject {
    id: root

    // ── Colour scheme ────────────────────────────────────────────────────
    // Same test the panel highlight uses: the app palette's window colour,
    // i.e. kdeglobals [Colors:Window] BackgroundNormal.
    readonly property bool dark: Kirigami.Theme.backgroundColor.hsvValue < 0.5

    // ── Geometry (WinUI 3 corner radii: 8 for surfaces, 4 for controls) ──
    readonly property int radiusOverlay: 8
    // Fluent 2 ships 4px controls, but at this popup's scale 4 reads as a
    // square corner; 6 keeps every control visibly rounded and consistent.
    readonly property int radiusControl: 6
    // Everything pill-shaped (indicators, badges) ignores this in practice,
    // it just has to be larger than half the tallest element it is applied to.
    readonly property int radiusPill: 999
    readonly property real strokeWidth: 1

    // ── Spacing (4px grid, the WinUI stack) ──────────────────────────────
    readonly property int spacingXSmall: 4
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 16
    readonly property int spacingXLarge: 24

    // ── Sizes ────────────────────────────────────────────────────────────
    // WinUI control height is 32 (Compact 24, comfortable 40). A search box
    // sits at 36 because it carries an icon plus a clear button.
    readonly property int controlHeight: 32
    readonly property int searchFieldHeight: 36
    readonly property int listItemHeight: 36
    // NavigationView selection indicator: 3px wide, 16px tall, fully rounded.
    readonly property int navigationIndicatorWidth: 3
    readonly property int navigationIndicatorHeight: 16
    // WinUI nav items carry a 20px glyph; 22 here keeps the rows roomy while
    // still fitting four more categories in the same sidebar height.
    readonly property int navigationIconSize: 22
    // Vertical padding of a navigation row: 22px glyph + 2*9 = 40px rows,
    // which is the Windows 11 start-menu rhythm without the oversized feel.
    readonly property int navigationItemPadding: 9
    // Padding around a 16px glyph inside an icon-only button (28x28 total).
    readonly property int iconButtonPadding: 6

    // ── Motion ───────────────────────────────────────────────────────────
    // Fluent 2 durations: fast for state layers, normal for controls, slow
    // for surfaces/travelling indicators.
    readonly property int durationFast: 100
    readonly property int durationNormal: 167
    readonly property int durationSlow: 250
    // cubic-bezier(0.0, 0.0, 0.0, 1.0) — the standard Fluent "decelerate".
    readonly property int easingStandard: Easing.OutCubic
    // cubic-bezier(0.33, 0.0, 0.67, 1.0) is symmetric, good for hover fades.
    readonly property int easingSoft: Easing.OutQuad

    // ── State layers ─────────────────────────────────────────────────────
    // WinUI paints interaction states as a translucent black/white layer on
    // top of the surface rather than as a separate accent colour.
    readonly property real alphaHover: 0.06
    readonly property real alphaPressed: 0.10
    readonly property real alphaSelected: 0.08
    readonly property real alphaStroke: 0.09
    readonly property real alphaSecondaryText: 0.68

    // Base colour of the state layer: white on dark surfaces, black on light.
    readonly property color layer: dark ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1)

    // Selected / hovered / pressed item: one translucent wash, never a card.
    // On light it is a *dark* wash (a few percent of black), on dark a light
    // one — the same "state layer" WinUI paints over its surface. A white block
    // read as a separate panel pasted on the popup; a low-alpha ink tint keeps
    // everything one surface and stays readable in both schemes.
    readonly property real selectionAlpha: dark ? 0.14 : 0.085
    readonly property color selectionSurface: withAlpha(layer, selectionAlpha)

    // Strength of that wash for hover / press, as a fraction of the selection.
    // Hover is most of the way there (the row you are about to pick should
    // already look picked); a press goes *above* 1, i.e. darker ink, so the row
    // visibly sinks under the click instead of flashing lighter.
    readonly property real washHover: 0.6
    readonly property real washPressed: 1.55

    // ── Palette ──────────────────────────────────────────────────────────
    readonly property color surface: Kirigami.Theme.backgroundColor
    readonly property color textPrimary: Kirigami.Theme.textColor
    readonly property color textSecondary: withAlpha(Kirigami.Theme.textColor, alphaSecondaryText)
    // Not Kirigami.Theme.highlightColor: inside the popup that one is the
    // *Plasma style's* selection colour (the Win11 style ships #0078D4), so it
    // ignored the accent picked in System Settings and did not match the
    // panel's indicators. KdeAccent resolves kdeglobals the same way the task
    // manager does; it falls back to Kirigami's colour if nothing is readable.
    readonly property color accent: KdeAccent.accent
    readonly property color onAccent: Kirigami.Theme.highlightedTextColor
    readonly property color stroke: withAlpha(layer, alphaStroke)
    // Hairline separating two regions (e.g. the tab bar from the content). A
    // touch stronger than a control outline, or it disappears on the frosted
    // popup background.
    readonly property color divider: withAlpha(layer, dark ? 0.16 : 0.11)
    readonly property color focusRing: withAlpha(accent, 0.55)

    // Filled controls (the search box). WinUI's TextBox sits one step *above*
    // the surface, not below it: a pale fill that lifts off the background.
    // A black wash over the frosted popup just looked dirty grey.
    readonly property color fieldFill: withAlpha(Qt.rgba(1, 1, 1, 1), dark ? 0.07 : 0.5)
    readonly property color fieldFillFocus: withAlpha(Qt.rgba(1, 1, 1, 1), dark ? 0.11 : 0.68)

    /** Returns `c` with the given alpha, keeping its hue. */
    function withAlpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    /** A state-layer colour for the given interaction alpha. */
    function stateColor(a: real): color {
        return withAlpha(layer, a);
    }
}
