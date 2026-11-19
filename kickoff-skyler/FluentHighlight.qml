/* SPDX-FileCopyrightText: 2026 SkyShadowHero <skyler@example.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick

/**
 * Drop-in replacement for PlasmaExtras.Highlight used anywhere a row needs a
 * state layer.
 *
 * It keeps the `hovered` / `pressed` / `selected` / `active` API of the theme
 * highlight, so call sites do not have to branch on the style — but it *always*
 * paints a WinUI state layer: a translucent rounded rectangle whose alpha
 * animates between rest / hover / pressed / selected instead of snapping.
 *
 * There is deliberately no PlasmaExtras.Highlight fallback any more. The theme
 * control is a FrameSvg — a coloured band with its own insets and (in dark
 * schemes) a black inner wash — so even one code path handing back to it made
 * a launcher row read as the classic Kicker item instead of a Fluent one. A
 * translucent ink layer also cannot go "too black" in dark mode the way the
 * themed highlight does, because the layer is white there.
 */
Item {
    id: root

    property bool hovered: false
    property bool pressed: false
    property bool selected: false
    // Kept for API compatibility: callers used to forward the list's
    // `activeFocus`; the Fluent layer does not need it.
    property bool active: true
    property real radius: FluentStyle.radiusControl
    // Optional opaque fill for the selected state. Left transparent, the
    // selection stays a plain state layer; the sidebar sets it to a solid card
    // so the selected category reads as "here", not as "dimmed".
    property color selectedColor: "transparent"
    // Inset of the painted layer inside the delegate. WinUI leaves a hair of
    // air around a row's wash; 0 fills the item exactly.
    property real inset: 0
    // Small chrome buttons (header configure/pin, footer power) use one ink
    // state layer for every interaction instead of mixing a white pressed card
    // with a translucent hover wash. Keeps them visually uniform.
    property bool flatStates: false

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.inset
        radius: root.radius

        // Selection is a pale surface (a white card on light, a lifted white on
        // dark) and hover is a weaker version of it. A press is a different
        // wash altogether, so clicking a row reads as a press in BOTH schemes.
        // `selected` wins over hover: call sites also report the current row as
        // hovered, and letting hover win drew it at 60% strength.
        readonly property real wash: root.selectedColor.a
        readonly property real level: root.selected ? 1 : (root.hovered ? FluentStyle.washHover : 0)

        // Flat mode: one translucent ink layer for hover / press / checked, no
        // white card — used by the small header/footer icon buttons. Regular
        // mode keeps the strong press surface for list rows.
        color: root.flatStates
            ? FluentStyle.stateColor(root.pressed
                ? FluentStyle.alphaPressed
                : (root.selected ? FluentStyle.alphaSelected : (root.hovered ? FluentStyle.alphaHover : 0)))
            : (root.pressed
                ? FluentStyle.pressedSurface
                : (wash > 0
                    ? FluentStyle.withAlpha(root.selectedColor, wash * level)
                    : FluentStyle.stateColor(root.hovered ? FluentStyle.alphaHover : 0)))

        // WinUI fades the state layer in ~100ms; no movement, no bounce.
        Behavior on color {
            ColorAnimation {
                duration: FluentStyle.durationFast
                easing.type: FluentStyle.easingSoft
            }
        }
    }
}
