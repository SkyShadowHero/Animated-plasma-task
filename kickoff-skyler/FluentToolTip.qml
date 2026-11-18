/* SPDX-FileCopyrightText: 2026 SkyShadowHero <skyler@example.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates as T

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

/**
 * Drop-in replacement for PlasmaExtras/PC3.ToolTip with readable contrast.
 *
 * PC3.ToolTip forces `Kirigami.Theme.colorSet: Tooltip; inherit: false` on its
 * label. Several Plasma themes (notably the Win11 one) define the Tooltip
 * colour set with pale grey text on a pale background, so the label is nearly
 * invisible — and because `inherit` is false it cannot be overridden from the
 * outside. This component keeps the same geometry/visibility API but draws
 * the text with the opaque window text colour and the card with an opaque
 * surface, so the label is legible in both light and dark schemes.
 */
T.ToolTip {
    id: control

    x: parent ? Math.round((parent.width - implicitWidth) / 2) : 0
    // A little breathing room between the card and its anchor.
    y: -implicitHeight - Math.round(Kirigami.Units.smallSpacing * 1.5)

    delay: Kirigami.Units.toolTipDelay
    timeout: -1
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent | T.Popup.CloseOnReleaseOutsideParent

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    // Even, comfortable padding so the text no longer crowds the card edges.
    readonly property int tooltipPadding: Math.round(Kirigami.Units.gridUnit * 0.5)
    topPadding: tooltipPadding
    bottomPadding: tooltipPadding
    leftPadding: tooltipPadding
    rightPadding: tooltipPadding

    contentItem: Text {
        id: label
        // Plain Text, not a Kirigami Label: nothing here re-applies the
        // Tooltip colour set, so `color` is guaranteed to be the real colour.
        readonly property int maxTextLength: Kirigami.Units.gridUnit * 14

        text: control.text.replace(/&(?=\S)/g, "")
        font: control.font
        color: FluentStyle.textPrimary
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter

        onLineLaidOut: (line) => {
            if (line.implicitWidth > maxTextLength) {
                line.width = maxTextLength
            }
        }
    }

    background: Rectangle {
        implicitWidth: Kirigami.Units.gridUnit
        implicitHeight: Kirigami.Units.gridUnit
        radius: FluentStyle.radiusControl
        // Opaque card: never blend with what is behind the popup, otherwise
        // the text loses contrast again on a frosted/translucent surface.
        color: FluentStyle.dark ? Qt.rgba(0.16, 0.16, 0.17, 1) : Qt.rgba(1, 1, 1, 1)
        border.width: 1
        border.color: FluentStyle.divider
    }
}
