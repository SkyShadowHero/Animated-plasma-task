/*
 *    SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
 *    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
 *
 *    SPDX-License-Identifier: GPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmaExtras.PlasmoidHeading {
    id: root

    // The theme's plasmoidheading frame paints a hairline along the popup edge
    // (above the tab bar). Its margins are what give this control its padding,
    // so it is hidden rather than replaced — through `opacity`, because the
    // frame binds `visible` itself and its late re-evaluation wins over an
    // external Binding.
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

    readonly property alias tabBar: tabBar
    property real preferredTabBarWidth: 0
    readonly property alias leaveButtons: leaveButtons

    // Fluent: one hairline separates the footer from the content above it. The
    // themed heading frame (which used to paint this) is hidden, so it is drawn
    // by hand — as a direct child of the control, because declared children
    // land in the padded contentItem, i.e. 16px too low.
    //
    // Positioned with x/y/width instead of anchors on purpose: the item is
    // declared in the contentItem and only reparented to the control by
    // `parent:`, so an anchor to `root` is resolved while the parent is still
    // the contentItem ("Cannot anchor to an item that isn't a parent or
    // sibling") and the line silently never appears.
    Rectangle {
        parent: root
        visible: Plasmoid.configuration.useFluentStyle
        x: FluentStyle.spacingMedium
        y: 0
        width: Math.max(0, root.width - 2 * FluentStyle.spacingMedium)
        height: FluentStyle.strokeWidth
        color: FluentStyle.divider
        z: 3
    }

    contentWidth: tabBar.implicitWidth + spacing
    contentHeight: leaveButtons.implicitHeight

    // We use an increased vertical padding to improve touch usability
    leftPadding: kickoff.backgroundMetrics.leftPadding
    rightPadding: kickoff.backgroundMetrics.rightPadding
    topPadding: Kirigami.Units.smallSpacing * 2
    bottomPadding: Kirigami.Units.smallSpacing * 2

    topInset: 0
    leftInset: 0
    rightInset: 0
    bottomInset: 0

    spacing: kickoff.backgroundMetrics.spacing
    position: PC3.ToolBar.Footer

    PC3.TabBar {
        id: tabBar

        property real tabWidth: Math.max(applicationsTab.implicitWidth, placesTab.implicitWidth)

        focus: true

        width: root.preferredTabBarWidth > 0 ? root.preferredTabBarWidth : undefined
        implicitWidth: contentWidth + leftPadding + rightPadding
        implicitHeight: contentHeight + topPadding + bottomPadding

        // This is needed to keep the separators horizontally aligned
        leftPadding: mirrored ? root.spacing : 0
        rightPadding: !mirrored ? root.spacing : 0

        anchors {
            top: parent.top
            left: parent.left
            bottom: parent.bottom
        }

        position: PC3.TabBar.Footer

        contentItem: ListView {
            id: tabBarListView
            focus: true
            model: tabBar.contentModel
            currentIndex: tabBar.currentIndex

            spacing: tabBar.spacing
            orientation: ListView.Horizontal
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.AutoFlickIfNeeded
            snapMode: ListView.SnapToItem

            // Fluent does its own travel (see fluentTabHighlight), so the
            // ListView must not animate the slot underneath it.
            highlightMoveDuration: Plasmoid.configuration.useFluentStyle ? 0 : Kirigami.Units.longDuration
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: tabBar.tabWidth
            preferredHighlightEnd: width - tabBar.tabWidth
            // Fluent swaps the KSvg "active tab" frame for a rounded pill plus an
            // accent underline; the ListView still animates it between tabs.
            highlight: Plasmoid.configuration.useFluentStyle ? fluentTabHighlight : themeTabHighlight

            Component {
                id: themeTabHighlight
                KSvg.FrameSvgItem {
                    anchors.top: tabBarListView.contentItem.top
                    anchors.bottom: tabBarListView.contentItem.bottom
                    anchors.topMargin: -root.topPadding
                    anchors.bottomMargin: -root.bottomPadding
                    imagePath: "widgets/tabbar"
                    prefix: tabBar.position === PC3.TabBar.Header ? "north-active-tab" : "south-active-tab"
                }
            }

            Component {
                id: fluentTabHighlight
                // Fluent does not fill the selected tab: only a short accent
                // bar marks it. A background would read as one more box on top
                // of an already flat surface.
                //
                // Travel is animated here instead of by the ListView (whose
                // slot moves instantly, see highlightMoveDuration), and it uses
                // the same motion as the sidebar pill: both ends of the bar
                // start on the previous tab, the leading end glides across
                // immediately, the trailing end waits a beat and then hurries
                // after it — so the bar stretches during the trip and settles
                // back to its normal length on arrival.
                Item {
                    id: fluentHighlight

                    anchors.top: tabBarListView.contentItem.top
                    anchors.bottom: tabBarListView.contentItem.bottom
                    anchors.topMargin: -root.topPadding + 3
                    anchors.bottomMargin: -root.bottomPadding + 3

                    // Fraction of the tab the underline covers.
                    readonly property real fullWidth: width * 0.75
                    readonly property real restLeft: (width - fullWidth) / 2

                    // Offsets of the two ends, in pixels, relative to the
                    // resting slot. Both start at the distance between the old
                    // and the new tab and run to zero, so the bar starts exactly
                    // where it was and ends exactly on its tab.
                    property real leadOffset: 0
                    property real trailOffset: 0
                    // 1 = travelling right (the right end leads), -1 = left.
                    property int dir: 1
                    // Deliberately NOT bound to tabBar.currentIndex: a binding
                    // is re-evaluated before this component's own change
                    // handler runs, so the first switch compared the new index
                    // with itself and skipped the animation. The value is
                    // maintained by the handler below and seeded once.
                    property int previousIndex: 0

                    Component.onCompleted: previousIndex = tabBar.currentIndex

                    Rectangle {
                        readonly property real leftEdge: fluentHighlight.restLeft
                            + (fluentHighlight.dir > 0
                                ? fluentHighlight.trailOffset
                                : fluentHighlight.leadOffset)
                        readonly property real rightEdge: fluentHighlight.restLeft
                            + fluentHighlight.fullWidth
                            + (fluentHighlight.dir > 0
                                ? fluentHighlight.leadOffset
                                : fluentHighlight.trailOffset)

                        x: leftEdge
                        width: Math.max(2, rightEdge - leftEdge)
                        height: 3
                        radius: height / 2
                        color: FluentStyle.accent
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                    }

                    Connections {
                        target: tabBar
                        function onCurrentIndexChanged(): void {
                            const step = tabBar.tabWidth + tabBar.spacing;
                            // Old position relative to the new one.
                            const delta = (fluentHighlight.previousIndex - tabBar.currentIndex) * step;
                            fluentHighlight.previousIndex = tabBar.currentIndex;
                            if (delta === 0 || !Plasmoid.configuration.useFluentStyle) {
                                return;
                            }
                            fluentHighlight.dir = delta < 0 ? 1 : -1;
                            fluentHighlight.leadOffset = delta;
                            fluentHighlight.trailOffset = delta;
                            slideAnimation.restart();
                        }
                    }

                    ParallelAnimation {
                        id: slideAnimation

                        // Leading end: one continuous glide on Compose's
                        // "fast-out-slow-in" curve, matching the sidebar pill.
                        NumberAnimation {
                            target: fluentHighlight
                            property: "leadOffset"
                            to: 0
                            duration: 470
                            easing.type: Easing.Bezier
                            easing.bezierCurve: [0.4, 0.0, 0.2, 1.0]
                        }
                        // Trailing end: held back for a beat (that is what
                        // stretches the bar), then it hurries to catch up and
                        // settles together with the leading end.
                        SequentialAnimation {
                            PauseAnimation {
                                duration: 70
                            }
                            NumberAnimation {
                                target: fluentHighlight
                                property: "trailOffset"
                                to: 0
                                duration: 400
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }
                }
            }
            keyNavigationEnabled: false
        }

        PC3.TabButton {
            id: applicationsTab
            focus: true
            width: tabBar.tabWidth
            anchors.top: tabBarListView.contentItem.top
            anchors.bottom: tabBarListView.contentItem.bottom
            anchors.topMargin: -root.topPadding
            anchors.bottomMargin: -root.bottomPadding
            icon.width: Kirigami.Units.iconSizes.smallMedium
            icon.height: Kirigami.Units.iconSizes.smallMedium
            icon.name: "applications-all-symbolic"
            text: i18nc("@title:tab kickoff sidebar tab", "Applications") // qmllint disable unqualified
            Keys.onBacktabPressed: event => {
                (kickoff.lastCentralPane || nextItemInFocusChain(false))
                    .forceActiveFocus(Qt.BacktabFocusReason)
            }
        }
        PC3.TabButton {
            id: placesTab
            width: tabBar.tabWidth
            anchors.top: tabBarListView.contentItem.top
            anchors.bottom: tabBarListView.contentItem.bottom
            anchors.topMargin: -root.topPadding
            anchors.bottomMargin: -root.bottomPadding
            icon.width: Kirigami.Units.iconSizes.smallMedium
            icon.height: Kirigami.Units.iconSizes.smallMedium
            icon.name: "compass"
            text: i18nc("@title:tab kickoff sidebar tab", "Places") //Explore? // qmllint disable unqualified
        }

        Connections {
            target: kickoff
            function onExpandedChanged() {
                if (!kickoff.expanded) {
                    tabBar.currentIndex = 0
                }
            }
        }

        Keys.onPressed: event => {
            const Key_Next = Application.layoutDirection === Qt.RightToLeft ? Qt.Key_Left : Qt.Key_Right
            const Key_Prev = Application.layoutDirection === Qt.RightToLeft ? Qt.Key_Right : Qt.Key_Left
            if (event.key === Key_Next) {
                if (currentIndex === count - 1) {
                    leaveButtons.nextItemInFocusChain().forceActiveFocus(Qt.TabFocusReason)
                } else {
                    incrementCurrentIndex()
                    currentItem.forceActiveFocus(Qt.TabFocusReason)
                }
                event.accepted = true
            } else if (event.key === Key_Prev && currentIndex > 0) {
                decrementCurrentIndex()
                currentItem.forceActiveFocus(Qt.BacktabFocusReason)
                event.accepted = true
            }
        }
        Keys.onUpPressed: event => {
            kickoff.firstCentralPane.forceActiveFocus(Qt.BacktabFocusReason);
        }
    }

    LeaveButtons {
        id: leaveButtons

        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
        }

        // available width for leaveButtons
        maximumWidth: root.availableWidth - tabBar.width - root.spacing

        Keys.onUpPressed: event => {
            kickoff.lastCentralPane.forceActiveFocus(Qt.BacktabFocusReason);
        }
    }

    Behavior on height {
        enabled: kickoff.expanded
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InQuad
        }
    }

    // Using item containing WheelHandler instead of MouseArea because
    // MouseArea doesn't keep track to the total amount of rotation.
    // Keeping track of the total amount of rotation makes it work
    // better for touch pads.
    Item {
        id: mouseItem
        parent: root
        anchors.left: parent.left
        height: root.height
        width: tabBar.width
        z: 1 // Has to be above contentItem to receive mouse wheel events
        WheelHandler {
            id: tabScrollHandler
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: {
                const shouldDec = rotation >= 15
                const shouldInc = rotation <= -15
                const shouldReset = (rotation > 0 && tabBar.currentIndex === 0) || (rotation < 0 && tabBar.currentIndex === tabBar.count - 1)
                if (shouldDec) {
                    tabBar.decrementCurrentIndex();
                    rotation = 0
                } else if (shouldInc) {
                    tabBar.incrementCurrentIndex();
                    rotation = 0
                } else if (shouldReset) {
                    rotation = 0
                }
            }
        }
    }

    Shortcut {
        sequences: ["Ctrl+Tab", "Ctrl+Shift+Tab", StandardKey.NextChild, StandardKey.PreviousChild]
        onActivated: {
            tabBar.currentIndex = (tabBar.currentIndex === 0) ? 1 : 0;
        }
    }
}
