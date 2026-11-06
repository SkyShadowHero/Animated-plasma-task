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

    Loader {
        anchors.fill: parent
        sourceComponent: (Plasmoid.configuration?.useFluentStyle ?? false) ? fluentLayer : themeHighlight
    }

    Component {
        id: fluentLayer

        Rectangle {
            radius: root.radius

            // One wash for every state, only its strength changes: selection is
            // the baseline, hover is a fraction of it, and a press goes past it
            // (i.e. darker ink on light, brighter tint on dark) so the row sinks
            // under the click instead of flaring up. `selected` wins over hover:
            // call sites also report the current row as hovered, and letting
            // hover win drew the selection at 60% strength.
            readonly property real wash: root.selectedColor.a
            readonly property real level: root.pressed
                ? FluentStyle.washPressed
                : (root.selected ? 1 : (root.hovered ? FluentStyle.washHover : 0))

            color: wash > 0
                ? FluentStyle.withAlpha(root.selectedColor, wash * level)
                : FluentStyle.stateColor(root.pressed
                    ? FluentStyle.alphaPressed
                    : (root.hovered ? FluentStyle.alphaHover : 0))

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
