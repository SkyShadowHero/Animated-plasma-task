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
 * and only the KDE SVG frame (`widgets/lineedit`) is replaced by a WinUI
 * TextBox: a rounded filled layer with no outline, and a 2px accent underline
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

        // Fully rounded, like the Windows 11 search box on the start menu.
        radius: height / 2
        // WinUI TextBox at rest: a filled layer one step above the surface,
        // with no outline at all. The only stroke it ever shows is the accent
        // underline while focused.
        color: root.activeFocus ? FluentStyle.fieldFillFocus : FluentStyle.fieldFill
        border.width: 0

        Behavior on color {
            ColorAnimation {
                duration: FluentStyle.durationFast
                easing.type: FluentStyle.easingSoft
            }
        }

        // WinUI TextBox focus underline: grows out of the centre on focus.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            height: 2
            radius: 1
            color: FluentStyle.accent
            width: parent.width * 0.9 * (root.activeFocus ? 1 : 0)
            Behavior on width {
                NumberAnimation {
                    duration: FluentStyle.durationNormal
                    easing.type: FluentStyle.easingStandard
                }
            }
        }
    }
}
