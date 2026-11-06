/*
    SPDX-FileCopyrightText: 2014 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2020 Carl Schwan <carl@carlschwan.eu>
    SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.components as KirigamiComponents
import org.kde.coreaddons as KCoreAddons
import org.kde.kcmutils as KCM
import org.kde.config as KConfig
import org.kde.plasma.plasmoid

PlasmaExtras.PlasmoidHeading {
    id: root

    // The themed heading frame is the last piece of KDE decoration left in the
    // popup: `header-center` is a translucent dark plate, so it paints a grey
    // band over the card and a hairline along its bottom edge.
    //
    // It cannot be removed — `backgroundMetrics`, whose margins feed this
    // control's insets, lives inside it — so it is made invisible. `visible`
    // alone is not enough: the item binds that property itself
    // (`fromCurrentImageSet === …`), and its late re-evaluation wins over an
    // external Binding. Nothing binds `opacity`, so that is what is used here.
    Binding {
        target: root.background
        property: "opacity"
        value: 0
        when: root.background !== null && Plasmoid.configuration.useFluentStyle
        restoreMode: Binding.RestoreBinding
    }
    Binding {
        target: root.background
        property: "visible"
        value: false
        when: root.background !== null && Plasmoid.configuration.useFluentStyle
        restoreMode: Binding.RestoreBinding
    }
    Component.onCompleted: {
        if (Plasmoid.configuration.useFluentStyle && root.background) {
            root.background.opacity = 0;
            root.background.visible = false;
        }
    }

    // Fluent: a hairline under the search field, matching the one above the tab
    // bar. The themed frame used to paint this and is now hidden, so it is
    // drawn by hand — with x/y/width rather than anchors, because the item is
    // declared in the padded contentItem and only reparented by `parent:`, so an
    // anchor to `root` resolves before that and never applies.
    Rectangle {
        parent: root
        visible: Plasmoid.configuration.useFluentStyle
        x: FluentStyle.spacingMedium
        y: root.height - height
        width: Math.max(0, root.width - 2 * FluentStyle.spacingMedium)
        height: FluentStyle.strokeWidth
        color: FluentStyle.divider
        z: 3
    }

    property alias searchText: searchField.text
    property Item configureButton: configureButton
    property Item pinButton: pinButton
    property Item avatar: avatar
    property real preferredNameAndIconWidth: 0

    readonly property bool fluent: Plasmoid.configuration?.useFluentStyle ?? false

    // The themed heading derived its padding from the dialog frame's margins;
    // with the frame gone the search field sat flush against the popup edge, so
    // Fluent states its own breathing room instead.
    contentHeight: layoutContainer.height + (fluent
        ? FluentStyle.spacingLarge * 2
        : kickoff.backgroundMetrics.topPadding + kickoff.backgroundMetrics.bottomPadding)

    KCoreAddons.KUser {
        id: kuser
    }

    spacing: kickoff.backgroundMetrics.spacing

    function tabSetFocus(event, invertedTarget, normalTarget) {
        // Set input focus depending on whether layout order matches focus chain order
        // normalTarget is optional
        const reason = event.key == Qt.Key_Tab ? Qt.TabFocusReason : Qt.BacktabFocusReason
        if (kickoff.paneSwap) {
            invertedTarget.forceActiveFocus(reason)
        } else if (normalTarget !== undefined) {
            normalTarget.forceActiveFocus(reason)
        } else {
            event.accepted = false
        }
    }

    contentItem: Item {
        Item {
            id: layoutContainer

            height: Math.max(searchField.implicitHeight, configureButton.implicitHeight)
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: kickoff.backgroundMetrics.leftPadding
                right: parent.right
                rightMargin: kickoff.backgroundMetrics.rightPadding
            }

            Keys.forwardTo: searchField.activeFocus ? null : searchField

            RowLayout {
                id: nameAndIcon
                spacing: root.spacing
                anchors.left: parent.left
                LayoutMirroring.enabled: kickoff.sideBarOnRight
                height: parent.height
                width: root.preferredNameAndIconWidth - layoutContainer.anchors.leftMargin

                KirigamiComponents.AvatarButton {
                    id: avatar
                    visible: KConfig.KAuthorized.authorizeControlModule("kcm_users")

                    Layout.fillHeight: true
                    Layout.minimumWidth: height
                    Layout.maximumWidth: height

                    text: i18nc("@action:button icon-only, for tooltip/Accessible", "Open user settings") // qmllint disable unqualified
                    name: kuser.fullName

                    // The icon property emits two signals in a row during which it
                    // changes to an empty URL and probably back to the same
                    // static file path, so we need QtQuick.Image not to cache it.
                    cache: false
                    source: kuser.faceIconUrl

                    Keys.onTabPressed: event => {
                        root.tabSetFocus(event, kickoff.firstCentralPane);
                    }
                    Keys.onBacktabPressed: event => {
                        root.tabSetFocus(event, nextItemInFocusChain());
                    }
                    Keys.onLeftPressed: event => {
                        if (kickoff.sideBarOnRight) {
                            searchField.forceActiveFocus(Application.layoutDirection == Qt.RightToLeft ? Qt.TabFocusReason : Qt.BacktabFocusReason)
                        }
                    }
                    Keys.onRightPressed: event => {
                        if (!kickoff.sideBarOnRight) {
                            searchField.forceActiveFocus(Application.layoutDirection == Qt.RightToLeft ? Qt.BacktabFocusReason : Qt.TabFocusReason)
                        }
                    }
                    Keys.onDownPressed: event => {
                        if (kickoff.sideBar) {
                            kickoff.sideBar.forceActiveFocus(Qt.TabFocusReason)
                        } else {
                            kickoff.contentArea.forceActiveFocus(Qt.TabFocusReason)
                        }
                    }

                    onClicked: KCM.KCMLauncher.openSystemSettings("kcm_users")
                }

                MouseArea {
                    id: nameAndInfoMouseArea
                    hoverEnabled: true

                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    Kirigami.Heading {
                        id: nameLabel
                        anchors.fill: parent
                        opacity: parent.containsMouse ? 0 : 1
                        color: Kirigami.Theme.textColor
                        level: 4
                        text: kuser.fullName
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        horizontalAlignment: kickoff.paneSwap ? Text.AlignRight : Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Kirigami.Units.longDuration
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    Kirigami.Heading {
                        id: infoLabel
                        anchors.fill: parent
                        level: 5
                        opacity: parent.containsMouse ? 1 : 0
                        color: Kirigami.Theme.textColor
                        text: kuser.os !== "" ? `${kuser.loginName}@${kuser.host} (${kuser.os})` : `${kuser.loginName}@${kuser.host}`
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        horizontalAlignment: kickoff.paneSwap ? Text.AlignRight : Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Kirigami.Units.longDuration
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    PC3.ToolTip.text: infoLabel.text
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    PC3.ToolTip.visible: infoLabel.truncated && containsMouse
                }
            }
            RowLayout {
                id: rowLayout
                spacing: root.spacing
                height: parent.height
                anchors {
                    left: nameAndIcon.right
                    right: parent.right
                }
                LayoutMirroring.enabled: kickoff.sideBarOnRight
                Keys.onDownPressed: event => {
                    kickoff.contentArea.forceActiveFocus(Qt.TabFocusReason);
                }

                FluentSearchField {
                    id: searchField
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    Layout.fillWidth: true
                    Layout.leftMargin: kickoff.backgroundMetrics.leftPadding
                    focus: true

                    Binding {
                        target: kickoff
                        property: "searchField"
                        value: searchField
                        // there's only one header ever, so don't waste resources
                        restoreMode: Binding.RestoreNone
                    }
                    Connections {
                        target: kickoff
                        function onExpandedChanged() {
                            if (!kickoff.expanded) {
                                searchField.clear()
                            }
                        }
                    }
                    onTextEdited: {
                        searchField.forceActiveFocus(Qt.ShortcutFocusReason)
                    }
                    Keys.priority: Keys.AfterItem
                    Keys.forwardTo: {
                        if (kickoff.contentArea === null) {
                            return []
                        }
                        if (kickoff.contentArea instanceof ListOfGridsView) {
                            // forward to grid inside of list, or down will skip the whole grid'
                            return [kickoff.contentArea.view.currentItem?.view, kickoff.contentArea.view]
                        }
                        return kickoff.contentArea.view
                    }

                    Keys.onTabPressed: event => {
                        tabSetFocus(event, nextItemInFocusChain(false));
                    }
                    Keys.onBacktabPressed: event => {
                        tabSetFocus(event, nextItemInFocusChain());
                    }
                    Keys.onLeftPressed: event => {
                        if (activeFocus) {
                            (sideBarOnRight ? configureButton : avatar).forceActiveFocus(
                                Application.layoutDirection === Qt.RightToLeft ? Qt.TabFocusReason : Qt.BacktabFocusReason)
                        }
                    }
                    Keys.onRightPressed: event => {
                        if (activeFocus) {
                            (sideBarOnRight ? avatar : configureButton).forceActiveFocus(
                                Application.layoutDirection === Qt.RightToLeft ? Qt.BacktabFocusReason : Qt.TabFocusReason)
                        }
                    }
                }

                PC3.ToolButton {
                    id: configureButton
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    visible: Plasmoid.internalAction("configure").enabled
                    icon.name: "configure"
                    text: Plasmoid.internalAction("configure").text
                    display: PC3.ToolButton.IconOnly

                    // Fluent icon button: rounded state layer instead of the
                    // theme's square button frame. The padding has to be set
                    // by hand because the Plasma ToolButton derives it from its
                    // own KSvg background, which is replaced here.
                    leftPadding: FluentStyle.iconButtonPadding
                    rightPadding: FluentStyle.iconButtonPadding
                    topPadding: FluentStyle.iconButtonPadding
                    bottomPadding: FluentStyle.iconButtonPadding
                    background: FluentHighlight {
                        hovered: configureButton.hovered
                        pressed: configureButton.down
                        radius: FluentStyle.radiusControl
                    }

                    PC3.ToolTip.text: text
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    PC3.ToolTip.visible: hovered
                    Keys.onTabPressed: event => {
                        tabSetFocus(event, nextItemInFocusChain(false));
                    }
                    Keys.onBacktabPressed: event => {
                        tabSetFocus(event, nextItemInFocusChain());
                    }
                    Keys.onLeftPressed: event => {
                        (kickoff.sideBarOnRight ? pinButton : searchField).forceActiveFocus(
                            Application.layoutDirection == Qt.RightToLeft ? Qt.TabFocusReason : Qt.BacktabFocusReason)
                    }
                    Keys.onRightPressed: event => {
                        (kickoff.sideBarOnRight ? searchField : pinButton).forceActiveFocus(
                            Application.layoutDirection == Qt.RightToLeft ? Qt.BacktabFocusReason : Qt.TabFocusReason)
                    }
                    onClicked: plasmoid.internalAction("configure").trigger()
                }
                PC3.ToolButton {
                    id: pinButton
                    checkable: true
                    checked: Plasmoid.configuration.pin
                    icon.name: "window-pin"
                    text: i18nc("@action:button Pin widget open if it loses focus, icon-only button, for tooltip/Accessible", "Keep Open") // qmllint disable unqualified
                    display: PC3.ToolButton.IconOnly
                    leftPadding: FluentStyle.iconButtonPadding
                    rightPadding: FluentStyle.iconButtonPadding
                    topPadding: FluentStyle.iconButtonPadding
                    bottomPadding: FluentStyle.iconButtonPadding
                    background: FluentHighlight {
                        hovered: pinButton.hovered
                        pressed: pinButton.down
                        // Checked is a real toggle state here, so it keeps the
                        // selected alpha instead of only a hover layer.
                        selected: pinButton.checked
                        radius: FluentStyle.radiusControl
                    }
                    PC3.ToolTip.text: text
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    PC3.ToolTip.visible: hovered
                    Binding {
                        target: kickoff
                        property: "hideOnWindowDeactivate"
                        value: !Plasmoid.configuration.pin
                        // there should be no other bindings, so don't waste resources
                        restoreMode: Binding.RestoreNone
                    }
                    Keys.onTabPressed: event => {
                        tabSetFocus(event, nextItemInFocusChain(false), kickoff.firstCentralPane || nextItemInFocusChain());
                    }
                    Keys.onBacktabPressed: event => {
                        tabSetFocus(event, nameAndIcon.nextItemInFocusChain(false), nextItemInFocusChain(false));
                    }
                    Keys.onLeftPressed: event => {
                        if (!kickoff.sideBarOnRight) {
                            nextItemInFocusChain(false).forceActiveFocus(Application.layoutDirection == Qt.RightToLeft ? Qt.TabFocusReason : Qt.BacktabFocusReason)
                        }
                    }
                    Keys.onRightPressed: event => {
                        if (kickoff.sideBarOnRight) {
                            nextItemInFocusChain(false).forceActiveFocus(Application.layoutDirection == Qt.RightToLeft ? Qt.BacktabFocusReason : Qt.TabFocusReason)
                        }
                    }
                    onToggled: Plasmoid.configuration.pin = checked
                }
            }
        }
    }
}
