/*
    SPDX-FileCopyrightText: 2011 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2012 Gregor Taetzner <gregor@freenet.de>
    SPDX-FileCopyrightText: 2012 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2013 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2015 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PC3
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami

import "code/tools.js" as Tools

PlasmoidItem {
    id: kickoff

    // The popup uses the theme's own dialog background — the "menu background"
    // itself — as its one and only surface. Fluent mode used to paint a card on
    // top of it, which is exactly what made the popup look like two stacked
    // layers (the card, plus whatever the heading frames drew over it). Only
    // the decorations drawn *inside* the surface are restyled.
    //
    // On a panel this property does double duty: the containment also paints the
    // applet background frame ("widgets/background") behind the compact icon
    // whenever the hints allow it — the same reason kdeconnect guards with
    // `inPanel ? NoBackground : DefaultBackground`. That frame is a KDE theme
    // SVG, so keeping it on left a theme card behind the launcher icon even
    // after "Use KDE theme decorations" was switched off. Fluent used to
    // short-circuit this to DefaultBackground (for the popup surface), which is
    // what kept the stray frame alive. The popup is a PlasmaWindow/AppletPopup
    // that paints its own "dialogs/background" frame and never reads this hint,
    // so on a panel the hint only ever produced that background.
    Plasmoid.backgroundHints: {
        if (inPanel) {
            return PlasmaCore.Types.NoBackground;
        }
        if (Plasmoid.configuration.useFluentStyle) {
            return PlasmaCore.Types.DefaultBackground;
        }
        return Plasmoid.configuration.useThemeDecorations
            ? PlasmaCore.Types.DefaultBackground
            : PlasmaCore.Types.NoBackground;
    }

    width: Kirigami.Units.iconSizes.huge
    height: Kirigami.Units.iconSizes.huge

    switchWidth: fullRepresentationItem ? fullRepresentationItem.Layout.minimumWidth : Kirigami.Units.iconSizes.huge * 10
    switchHeight: fullRepresentationItem ? fullRepresentationItem.Layout.minimumHeight : Kirigami.Units.iconSizes.huge * 10

    // The properties are defined here instead of the singleton because each
    // instance of Kickoff requires different instances of these properties

    readonly property bool inPanel: [
        PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.RightEdge,
        PlasmaCore.Types.BottomEdge,
        PlasmaCore.Types.LeftEdge,
    ].includes(Plasmoid.location)
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    // Custom decoration colour, resolved exactly like the task manager (see
    // Tools.highlightUsesWhite): White / Black / Automatic by colour scheme.
    // Kirigami.Theme.backgroundColor is the app palette's window colour, i.e.
    // kdeglobals [Colors:Window], so this follows the system light/dark mode.
    readonly property bool darkTheme: Kirigami.Theme.backgroundColor.hsvValue < 0.5
    readonly property bool highlightUsesWhite: Tools.highlightUsesWhite(Plasmoid.configuration.highlightColor, darkTheme)
    // Same five-speed multiplier as the task manager, from the same Enum
    // layout in main.xml, so the launcher highlight never runs at a different
    // pace from the taskbar highlight sitting next to it.
    readonly property real animMul: Tools.animationMultiplier(Plasmoid.configuration.animationSpeed)

    // The desktop shell paints a "widgets/tabbar" active-tab frame at an
    // applet's position in two independent places, and neither of them looks at
    // the applet's own decoration settings:
    //
    //  - CompactApplet.qml draws `expandedItem` (z: -100) behind the applet
    //    while the popup is expanded;
    //  - Panel.qml draws its "Panel Focus Indicator" at whichever applet holds
    //    focus, which is exactly what happens right after the icon is clicked.
    //
    // In the Win11OS theme both render as the blue bar on the panel edge plus
    // the light rounded plate behind the icon, so switching off "Use KDE theme
    // decorations" still left that plate in place. `Plasmoid.backgroundHints`
    // does not influence either of them. Gate both on the setting, leaving the
    // shell's own visibility/opacity animations intact so that with decorations
    // enabled the panel behaves exactly as upstream.
    function findAppletContainer() {
        const self = kickoff.compactRepresentation;
        if (!self) {
            return null;
        }
        const containerName = "org.kde.desktop-CompactApplet";

        // Walk up first: the shell parents the compact representation straight
        // into the container, so any matching ancestor is necessarily ours.
        let item = self;
        while (item) {
            if (item.objectName === containerName) {
                return item;
            }
            item = item.parent;
        }
        // Fall back to a window-wide search in case the item is still being
        // reparented when this runs. There it must be verified that the
        // container really belongs to this applet, not to a neighbour.
        const win = kickoff.Window.window;
        if (!win || !win.contentItem) {
            return null;
        }
        const stack = [win.contentItem];
        while (stack.length) {
            const node = stack.pop();
            if (node.objectName === containerName) {
                let owns = false;
                try {
                    owns = node.compactRepresentation === self;
                } catch (e) {
                    owns = false;
                }
                if (owns) {
                    return node;
                }
            }
            const kids = node.children;
            for (let i = 0; i < kids.length; ++i) {
                stack.push(kids[i]);
            }
        }
        return null;
    }

    // Every tabbar frame drawn on top of this applet, wherever it comes from.
    // `exceptFrame` is the container's expanded item, which is handled through
    // `visible` instead so its expand animation keeps working; `container` is
    // skipped as a whole as a safety net when `expandedFeedback` is missing.
    function gateAppletTabbarFrames(exceptFrame, container) {
        const win = kickoff.Window.window;
        const self = kickoff.compactRepresentation;
        if (!win || !self || !win.contentItem) {
            return false;
        }
        const content = win.contentItem;
        const origin = self.mapToItem(content, 0, 0);
        const left = origin.x;
        const top = origin.y;
        const right = left + self.width;
        const bottom = top + self.height;
        // The theme adds shadow margins around the tab frame, so compare with a
        // tolerance instead of demanding identical geometry.
        const tolerance = 16;

        let touched = false;
        const stack = [content];
        while (stack.length) {
            const node = stack.pop();
            let imagePath = "";
            try {
                imagePath = node.imagePath;
            } catch (e) {
                imagePath = "";
            }
            if (imagePath === "widgets/tabbar"
                    && node !== exceptFrame
                    && node !== container
                    && (!container || node.parent !== container)) {
                const nodeOrigin = node.mapToItem(content, 0, 0);
                const overlapsVertically = nodeOrigin.y < bottom
                    && nodeOrigin.y + node.height > top;
                const sameColumn = Math.abs(nodeOrigin.x - left) < tolerance
                    && Math.abs(node.width - self.width) < tolerance;
                if (overlapsVertically && sameColumn) {
                    // Opacity rather than visible: the panel indicator owns a
                    // `visible` binding of its own that must keep working.
                    node.opacity = Qt.binding(function () {
                        return Plasmoid.configuration.useThemeDecorations ? 1 : 0;
                    });
                    touched = true;
                }
            }
            const kids = node.children;
            for (let i = 0; i < kids.length; ++i) {
                stack.push(kids[i]);
            }
        }
        return touched;
    }

    function syncShellExpandedFrame() {
        const container = findAppletContainer();
        const frame = (container && container.expandedFeedback) ? container.expandedFeedback : null;

        let done = false;
        if (frame) {
            frame.visible = Qt.binding(function () {
                return Plasmoid.configuration.useThemeDecorations && frame.opacity > 0;
            });
            done = true;
        }
        if (gateAppletTabbarFrames(frame, container)) {
            done = true;
        }
        return done;
    }

    // Used to prevent the width from changing frequently when the scrollbar appears or disappears
    readonly property bool mayHaveGridWithScrollBar: Plasmoid.configuration.applicationsDisplay === 0
        || (Plasmoid.configuration.favoritesDisplay === 0 && kickoff.rootModel.favoritesModel.count > minimumGridRowCount * minimumGridRowCount)

    //BEGIN Models
    readonly property Kicker.RootModel rootModel: Kicker.RootModel {
        autoPopulate: false

        // TODO: appletInterface property now can be ported to "applet" and have the real Applet* assigned directly
        appletInterface: kickoff

        appNameFormat: Plasmoid.configuration.appNameFormat
        flat: true // have categories, but no subcategories
        sorted: Plasmoid.configuration.alphaSort
        showSeparators: !sorted && Plasmoid.configuration.applicationsDisplay != 0
        showTopLevelItems: true

        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: true
        highlightNewlyInstalledApps: Plasmoid.configuration.highlightNewlyInstalledApps

        Component.onCompleted: {
            favoritesModel.initForClient("org.kde.plasma.kickoff.favorites.instance-" + Plasmoid.id)

            if (!Plasmoid.configuration.favoritesPortedToKAstats) {
                if (favoritesModel.count < 1) {
                    favoritesModel.portOldFavorites(Plasmoid.configuration.favorites);
                }
                Plasmoid.configuration.favoritesPortedToKAstats = true;
            }
        }
    }

    readonly property Kicker.RunnerModel runnerModel: Kicker.RunnerModel {
        query: kickoff.searchField ? kickoff.searchField.text : ""
        onRequestUpdateQuery: query => {
            if (kickoff.searchField) {
                kickoff.searchField.text = query;
            }
        }
        appletInterface: kickoff
        mergeResults: true
        favoritesModel: kickoff.rootModel.favoritesModel
    }

    readonly property Kicker.ComputerModel computerModel: Kicker.ComputerModel {
        appletInterface: kickoff
        favoritesModel: kickoff.rootModel.favoritesModel
        systemApplications: Plasmoid.configuration.systemApplications
        Component.onCompleted: {
            //systemApplications = Plasmoid.configuration.systemApplications;
        }
    }

    readonly property alias recentUsageModel: recentUsageModel
    Kicker.RecentUsageModel {
        id: recentUsageModel
        favoritesModel: kickoff.rootModel.favoritesModel
    }

    readonly property alias frequentUsageModel: frequentUsageModel
    Kicker.RecentUsageModel {
        id: frequentUsageModel
        favoritesModel: kickoff.rootModel.favoritesModel
        ordering: 1 // Popular / Frequently Used
    }
    //END

    //BEGIN UI elements
    // Set in FullRepresentation.qml
    property Item header: null

    // Set in Header.qml
    // QTBUG Using PC3.TextField as type makes assignment fail
    // "Cannot assign QObject* to TextField_QMLTYPE_8*"
    property Item searchField: null

    // Set in FullRepresentation.qml, ApplicationPage.qml, PlacesPage.qml
    property Item sideBar: null // is null when searching
    property Item contentArea: null // is searchView when searching

    // Set in NormalPage.qml
    property Item footer: null

    // True when central pane (and header) LayoutMirroring diverges from global
    // LayoutMirroring, in order to achieve the desired sidebar position
    readonly property bool paneSwap: Plasmoid.configuration.paneSwap
    readonly property bool sideBarOnRight: (Application.layoutDirection == Qt.RightToLeft) != paneSwap
    // References to items according to their focus chain order
    readonly property Item firstHeaderItem: header ? (paneSwap ? header.pinButton : header.avatar) : null
    readonly property Item lastHeaderItem: header ? (paneSwap ? header.avatar : header.pinButton) : null
    readonly property Item firstCentralPane: paneSwap ? contentArea : sideBar
    readonly property Item lastCentralPane: paneSwap ? sideBar : contentArea

    readonly property Item dragSource: Item {
        id: dragSource // BUG 449426
        property Item sourceItem
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.LinkAction | Qt.MoveAction
    }
    //END

    //BEGIN Metrics
    readonly property KSvg.FrameSvgItem backgroundMetrics: KSvg.FrameSvgItem {
        // Inset defaults to a negative value when not set by margin hints
        readonly property real leftPadding: Math.round(margins.left - Math.max(inset.left, 0))
        readonly property real rightPadding: Math.round(margins.right - Math.max(inset.right, 0))
        readonly property real topPadding: Math.round(margins.top - Math.max(inset.top, 0))
        readonly property real bottomPadding: Math.round(margins.bottom - Math.max(inset.bottom, 0))
        readonly property real spacing: Math.round(leftPadding)
        visible: false
        imagePath: Plasmoid.formFactor === PlasmaCore.Types.Planar ? "widgets/background" : "dialogs/background"
    }

    // This is here rather than in the singleton with the other metrics items
    // because the list delegate's height depends on a configuration setting
    // and the singleton can't access those
    readonly property real listDelegateHeight: listDelegate.height
    KickoffListDelegate {
        id: listDelegate
        visible: false
        enabled: false
        model: null
        index: -1
        text: "asdf"
        url: ""
        decoration: "start-here-kde"
        description: "asdf"
        action: null
        indicator: null
    }

    // Used to show smaller Kickoff on small screens
    readonly property int minimumGridRowCount: Math.min(Screen.desktopAvailableWidth, Screen.desktopAvailableHeight) * Screen.devicePixelRatio < KickoffSingleton.gridCellSize * 4 + (fullRepresentationItem && fullRepresentationItem.normalPage ? fullRepresentationItem.normalPage.preferredSideBarWidth : KickoffSingleton.gridCellSize * 2) ? 2 : 4
    //END

    Plasmoid.icon: Plasmoid.configuration.icon

    preferredRepresentation: compactRepresentation

    // Two complete representations share this one entry point. A Loader keeps
    // both code paths isolated: the classic Kickoff layout is untouched, and
    // the Win11 Start menu is a self-contained page. The forwarded properties
    // below preserve the API the classic delegates and the sizing logic read
    // off `fullRepresentationItem`, so switching layouts cannot strand a
    // binding on a null item.
    fullRepresentation: Loader {
        id: representationLoader

        readonly property Item contentItem: item ? item.contentItem : null
        readonly property bool blockingHoverFocus: item ? (item.blockingHoverFocus ?? false) : false
        readonly property Item normalPage: item ? (item.normalPage ?? null) : null

        Layout.minimumWidth: item ? (item.Layout.minimumWidth ?? 0) : (Kirigami.Units.iconSizes.huge * 10)
        Layout.minimumHeight: item ? (item.Layout.minimumHeight ?? 0) : (Kirigami.Units.iconSizes.huge * 10)

        sourceComponent: (Plasmoid.configuration?.useWin11Menu ?? false)
                         && (Plasmoid.configuration?.useFluentStyle ?? false)
            ? win11RepresentationComponent
            : classicRepresentationComponent

        Component {
            id: classicRepresentationComponent
            FullRepresentation { focus: true }
        }
        Component {
            id: win11RepresentationComponent
            Win11StartMenu { focus: true }
        }
    }

    // Only exists because the default CompactRepresentation doesn't:
    // - open on drag
    // - allow defining a custom drop handler
    // - expose the ability to show text below or beside the icon
    // TODO remove once it gains those features
    compactRepresentation: Item {
        id: compactRep

        implicitWidth: compactRoot.iconSize
        implicitHeight: compactRoot.iconSize
        Layout.preferredWidth: compactRoot.sizing.preferredWidth
        Layout.preferredHeight: compactRoot.sizing.preferredHeight
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight

        // The shell reparents this item into its own applet container, so the
        // container can only be reached once the parent is in place. A short
        // retry covers the case where the container is built after we are.
        onParentChanged: kickoff.syncShellExpandedFrame()
        Component.onCompleted: kickoff.syncShellExpandedFrame()

        Timer {
            interval: 300
            repeat: true
            running: true
            property int attempts: 0
            onTriggered: {
                attempts++;
                if (kickoff.syncShellExpandedFrame() || attempts >= 10) {
                    running = false;
                }
            }
        }

        MouseArea {
            id: compactRoot
            anchors.fill: compactRep

            // Taken from DigitalClock to ensure uniform sizing when next to each other
            readonly property bool tooSmall: Plasmoid.formFactor === PlasmaCore.Types.Horizontal && Math.round(2 * (compactRoot.height / 5)) <= Kirigami.Theme.smallFont.pixelSize

        readonly property bool shouldHaveIcon: Plasmoid.formFactor === PlasmaCore.Types.Vertical || Plasmoid.icon !== ""
        readonly property bool shouldHaveLabel: Plasmoid.formFactor !== PlasmaCore.Types.Vertical && Plasmoid.configuration.menuLabel !== ""

        readonly property int iconSize: Kirigami.Units.iconSizes.large

        readonly property var sizing: {
            const displayedIcon = imageFallback.visible ? imageFallback : (buttonIcon.valid ? buttonIcon : buttonIconFallback);

            let impWidth = 0;
            if (shouldHaveIcon) {
                impWidth += displayedIcon.width;
            }
            if (shouldHaveLabel) {
                impWidth += labelTextField.contentWidth + labelTextField.Layout.leftMargin + labelTextField.Layout.rightMargin;
            }
            const impHeight = displayedIcon.height > 0 ? displayedIcon.height : iconSize

            // at least square, but can be wider/taller
            if (kickoff.inPanel) {
                if (kickoff.vertical) {
                    return {
                        preferredWidth: iconSize,
                        preferredHeight: impHeight
                    };
                } else { // horizontal
                    return {
                        preferredWidth: impWidth,
                        preferredHeight: iconSize
                    };
                }
            } else {
                return {
                    preferredWidth: impWidth,
                    preferredHeight: Kirigami.Units.iconSizes.small,
                };
            }
        }

        hoverEnabled: true

        // Same press depth as the taskbar icons (Task.qml pressDownAnim):
        // 0.85 on the way down, 1.0 on the way back. The old Fluent-only 0.96
        // made the launcher dip far less than the tasks beside it.
        readonly property real pressScaleTarget: 0.85

        transform: [
            Scale {
                id: pressScale
                origin.x: compactRoot.width / 2
                origin.y: compactRoot.height / 2
            },
            Translate {
                y: (Plasmoid.configuration.hoverEffect && compactRoot.containsMouse) ? -3 : 0
                Behavior on y {
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
            }
        ]

        property bool wasExpanded

        Accessible.name: Plasmoid.title
        Accessible.role: Accessible.Button

         onPressed: {
            wasExpanded = kickoff.expanded;
            pressDown.start();
         }
         onReleased: pressUp.start()
         onCanceled: pressUp.start()
         onClicked: kickoff.expanded = !wasExpanded

        ParallelAnimation {
            id: pressDown
            NumberAnimation { target: pressScale; property: "xScale"; to: compactRoot.pressScaleTarget; duration: 80 * kickoff.animMul; easing.type: Easing.OutQuad }
            NumberAnimation { target: pressScale; property: "yScale"; to: compactRoot.pressScaleTarget; duration: 80 * kickoff.animMul; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            id: pressUp
            NumberAnimation { target: pressScale; property: "xScale"; to: 1.0; duration: 250 * kickoff.animMul; easing.type: Easing.OutBack }
            NumberAnimation { target: pressScale; property: "yScale"; to: 1.0; duration: 250 * kickoff.animMul; easing.type: Easing.OutBack }
        }

        DropArea {
            id: compactDragArea
            anchors.fill: parent
            onEntered: drag => {
                if (drag.hasUrls) {
                    expandOnDragTimer.start()
                }
            }
            onExited: expandOnDragTimer.stop()
        }

        Timer {
            id: expandOnDragTimer
            // this is an interaction and not an animation, so we want it as a constant
            interval: 250
            onTriggered: kickoff.expanded = true
        }

        RowLayout {
            id: iconLabelRow
            anchors.fill: parent
            spacing: 0

             Kirigami.Icon {
                id: buttonIcon

                Layout.fillWidth: kickoff.vertical
                Layout.fillHeight: !kickoff.vertical
                Layout.preferredWidth: kickoff.vertical ? -1 : height / (implicitHeight / implicitWidth)
                Layout.preferredHeight: !kickoff.vertical ? -1 : width * (implicitHeight / implicitWidth)
                Layout.maximumHeight: Kirigami.Units.iconSizes.huge
                Layout.maximumWidth: Kirigami.Units.iconSizes.huge
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                source: Tools.iconOrDefault(Plasmoid.formFactor, Plasmoid.icon)
                active: Plasmoid.configuration.useThemeDecorations && (compactRoot.containsMouse || compactDragArea.containsDrag)
                roundToIconSize: implicitHeight === implicitWidth
                visible: valid && !imageFallback.visible
            }

            Kirigami.Icon {
                id: buttonIconFallback
                // fallback is assumed to be square
                Layout.fillWidth: kickoff.vertical
                Layout.fillHeight: !kickoff.vertical
                Layout.preferredWidth: kickoff.vertical ? -1 : height
                Layout.preferredHeight: !kickoff.vertical ? -1 : width
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

                source: buttonIcon.valid ? null : Tools.defaultIconName
                active: Plasmoid.configuration.useThemeDecorations && (compactRoot.containsMouse || compactDragArea.containsDrag)
                visible: !buttonIcon.valid && Plasmoid.icon !== "" && !imageFallback.visible
            }

            Image {
                id: imageFallback

                readonly property bool nonSquareImage: sourceSize.width != sourceSize.height

                visible: nonSquareImage && status == Image.Ready
                source: Plasmoid.icon.startsWith("/") ? "file:" + Plasmoid.icon.split("/").map(encodeURIComponent).join("/") : ""

                Layout.fillWidth: kickoff.vertical
                Layout.fillHeight: !kickoff.vertical
                Layout.preferredWidth: kickoff.vertical ? -1 : height / (implicitHeight / implicitWidth)
                Layout.preferredHeight: !kickoff.vertical ? -1 : width * (implicitHeight / implicitWidth)
                Layout.maximumHeight: kickoff.vertical ? -1 : Kirigami.Units.iconSizes.huge
                Layout.maximumWidth: kickoff.vertical ? Kirigami.Units.iconSizes.huge : -1
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }

            PC3.Label {
                id: labelTextField

                Layout.fillHeight: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                text: Plasmoid.configuration.menuLabel
                textFormat: Text.StyledText
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.NoWrap
                fontSizeMode: Text.VerticalFit
                font.pixelSize: compactRoot.tooSmall ? Kirigami.Theme.defaultFont.pixelSize : Kirigami.Units.iconSizes.roundedIconSize(Kirigami.Units.gridUnit * 2)
                minimumPointSize: Kirigami.Theme.smallFont.pointSize
                visible: compactRoot.shouldHaveLabel
            }
        }
        }

        // Custom highlight background (declared AFTER compactRoot so its
        // width/height bindings resolve reliably; does not inherit the
        // icon's hover/press transforms).
        Rectangle {
            id: launcherHighlight
            z: -1
            anchors.centerIn: compactRep
            // Match the taskbar masks exactly, not just in proportion: both are
            // a square scaled from the panel thickness by the same
            // `highlightScale` ratio (Tools.highlightRatio). The old base was
            // min(compactRep.width, height) = Kirigami's large icon size, so on
            // a taller panel the launcher mask came out visibly smaller than
            // the task mask beside it. Using the panel-thickness edge fixes
            // that. Whole-block highlight (icon + menu label) is not relevant
            // here: the launcher has no resizable task label to cover.
            readonly property real panelThickness: kickoff.vertical ? compactRep.width : compactRep.height
            width: panelThickness * Tools.highlightRatio(Plasmoid.configuration.highlightScale)
            height: width
            visible: Plasmoid.configuration.useCustomDecorations && Plasmoid.configuration.useHighlight
            readonly property real maskAlpha: Tools.highlightAlpha(
                Plasmoid.configuration.highlightColor, kickoff.darkTheme, kickoff.expanded)
            color: kickoff.highlightUsesWhite
                ? Qt.rgba(1, 1, 1, maskAlpha)
                : Qt.rgba(0, 0, 0, maskAlpha)
            Behavior on color {
                ColorAnimation { duration: 120 * kickoff.animMul; easing.type: Easing.OutQuad }
            }
            radius: {
                switch (Plasmoid.configuration.highlightShape) {
                case 1: return 0; // Rectangle
                case 2: return width / 2; // Circle
                default: return Kirigami.Units.smallSpacing; // Rounded Rectangle
                }
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.15
                shadowBlur: 0.15
                shadowVerticalOffset: 1
                shadowHorizontalOffset: 0
            }
            // Pure crossfade, same as the taskbar hover mask. The old Fluent
            // 0.9 -> 1 grow transform made the launcher pop differently from
            // the neighbouring tasks, so it is gone.
            opacity: (compactRoot.containsMouse || kickoff.expanded) ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 80 * kickoff.animMul; easing.type: Easing.OutQuad }
            }
        }
    }

    Kicker.ProcessRunner {
        id: processRunner
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("@action:inmenu launches kmenuedit", "Edit Applications…") // qmllint disable unqualified
            icon.name: "kmenuedit"
            visible: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            onTriggered: processRunner.runMenuEditor()
        }
    ]

    Component.onCompleted: {
        Plasmoid.activationTogglesExpanded = true
    }
} // root
