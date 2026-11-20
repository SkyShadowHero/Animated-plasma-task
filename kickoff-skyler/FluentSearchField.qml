/* SPDX-FileCopyrightText: 2026 SkyShadowHero <skyler@example.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

/**
 * PlasmaExtras.SearchField with a Fluent background.
 *
 * Everything that makes the field useful is inherited — search icon, clear
 * action, Ctrl+F focus sequence, translated placeholder, accessible roles —
 * and only the KDE SVG frame (`widgets/lineedit`) is replaced by a Win11
 * capsule: a filled layer with a hairline outline, and a 2px accent underline
 * that grows out of the centre on focus.
 *
 * The background has to expose a `margins` object: TextField reads
 * background.margins.* to compute its own padding, so a plain Rectangle would
 * collapse the field's height and let the icon overlap the text.
 */
PlasmaExtras.SearchField {
    id: root

    readonly property int __padding: 5

    readonly property bool fluent: Plasmoid.configuration?.useFluentStyle ?? false

    // ActionTextField reports the focus shortcut it registered ("Ctrl+F") by
    // floating it through the attached PC3.ToolTip while the field is hovered
    // and empty. That tooltip is painted with the Tooltip colour group, i.e.
    // the pale-on-pale smudge this style produces, so Fluent mirrors its text
    // into FluentToolTip and keeps the theme one out of the way. The text is
    // read, not re-bound: the base type already binds it to the shortcut, and
    // binding it again here would only fight that.
    readonly property string shortcutHint: PlasmaComponents3.ToolTip.text

    PlasmaComponents3.ToolTip.visible: !root.fluent && root.shortcutHint.length > 0
                                        && root.text.length === 0 && root.hovered

    FluentToolTip {
        parent: root
        // Below the field rather than above it: the search field sits at the
        // very top of the popup, so there is nothing to hover over up there.
        y: root.height + Math.round(Kirigami.Units.smallSpacing * 1.5)

        visible: root.fluent && root.hovered && root.text.length === 0 && root.shortcutHint.length > 0
        text: root.shortcutHint
    }

    background: Rectangle {
        id: bg

        property var margins: QtObject {
            property int left: 8
            property int right: 8
            property int top: root.__padding
            property int bottom: root.__padding
        }

        implicitWidth: Kirigami.Units.gridUnit * 8
        implicitHeight: FluentStyle.searchFieldHeight

        // A pill, like the Windows 11 search box: the field is 32px tall, so
        // the radius is half of it. `radiusControl` (6) read as a rounded
        // rectangle; the Start menu's own field is a capsule.
        radius: height / 2
        // WinUI TextBox at rest: a filled layer one step above the surface,
        // held in by a hairline stroke so its edge reads against the card.
        // Hover lifts the fill and strengthens the edge; focus adds the accent
        // underline, which is the only heavier line in the control.
        color: root.activeFocus || root.hovered ? FluentStyle.fieldFillFocus : FluentStyle.fieldFill
        border.width: FluentStyle.strokeWidth
        border.color: root.activeFocus || root.hovered
            ? FluentStyle.withAlpha(FluentStyle.layer, FluentStyle.dark ? 0.22 : 0.16)
            : FluentStyle.stroke

        Behavior on color {
            ColorAnimation {
                duration: FluentStyle.durationFast
                easing.type: FluentStyle.easingSoft
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: FluentStyle.durationFast
                easing.type: FluentStyle.easingSoft
            }
        }

        // Focus underline. On a pill the line has to stop where the bottom
        // curve turns, or it runs out past the silhouette — the inset is the
        // horizontal travel of the corner arc at this height, which leaves the
        // bar ~21px short of the full width instead of the 10% it used to lose.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            height: 2
            radius: 1
            color: FluentStyle.accent
            width: (parent.width - Math.round(bg.radius * 1.3)) * (root.activeFocus ? 1 : 0)
            Behavior on width {
                NumberAnimation {
                    duration: FluentStyle.durationNormal
                    easing.type: FluentStyle.easingStandard
                }
            }
        }
    }
}
