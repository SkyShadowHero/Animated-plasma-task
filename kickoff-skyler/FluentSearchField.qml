/* SPDX-FileCopyrightText: 2026 SkyShadowHero <skyler@example.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.extras as PlasmaExtras
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
