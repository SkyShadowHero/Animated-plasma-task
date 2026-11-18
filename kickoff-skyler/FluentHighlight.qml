/* SPDX-FileCopyrightText: 2026 SkyShadowHero <skyler@example.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

/**
 * Drop-in replacement for PlasmaExtras.Highlight used as a delegate background.
 *
 * It keeps the same `hovered` / `pressed` / `active` API, so call sites do not
 * need to branch on the style. When `useFluentStyle` is off it simply forwards
 * to PlasmaExtras.Highlight; when it is on it paints a WinUI state layer — a
 * translucent rounded rectangle whose alpha animates between rest / hover /
 * pressed / selected instead of snapping.
 */
Item {
    id: root

    property bool hovered: false
    property bool pressed: false
    property bool selected: false
    property bool active: true
    property real radius: FluentStyle.radiusControl
    // Optional opaque fill for the selected state. Left transparent, the
    // selection stays a plain state layer; the sidebar sets it to a solid card
    // so the selected category reads as "here", not as "dimmed".
    property color selectedColor: "transparent"
    // Small chrome buttons (header configure/pin, footer power) use one ink
    // state layer for every interaction instead of mixing a white pressed card
    // with a translucent hover wash. Keeps them visually uniform.
    property bool flatStates: false

    Loader {
        anchors.fill: parent
        sourceComponent: (Plasmoid.configuration?.useFluentStyle ?? false) ? fluentLayer : themeHighlight
    }

    Component {
        id: fluentLayer

        Rectangle {
            anchors.fill: parent
            radius: root.radius

            // Selection is a pale surface (a white card on light, a lifted
            // white on dark) and hover is a weaker version of it. A press is a
            // different wash altogether — a dark layer — so clicking a row
            // darkens it in BOTH schemes instead of brightening it.
            // `selected` wins over hover: call sites also report the current
            // row as hovered, and letting hover win drew it at 60% strength.
            readonly property real wash: root.selectedColor.a
            readonly property real level: root.selected ? 1 : (root.hovered ? FluentStyle.washHover : 0)

            // Flat mode: one translucent ink layer for hover / press / checked,
            // no white card — used by the small header/footer icon buttons.
            // Regular mode keeps the strong press surface for list rows.
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

    Component {
        id: themeHighlight

        PlasmaExtras.Highlight {
            hovered: root.hovered || root.selected
            pressed: root.pressed
            active: root.active
        }
    }
}
