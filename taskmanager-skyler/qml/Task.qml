/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2024 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import plasma.applet.org.kde.plasma.taskmanager.skyler as TaskManagerApplet
import org.kde.plasma.plasmoid

import org.kde.taskmanager as TaskManager

PlasmaCore.ToolTipArea {
    id: task

    activeFocusOnTab: true

    // To achieve a bottom-to-top layout on vertical panels, the task manager
    // is rotated by 180 degrees(see main.qml). This makes the tasks rotated,
    // so un-rotate them here to fix that.
    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    implicitHeight: inPopup
                    ? TaskManagerApplet.LayoutMetrics.preferredHeightInPopup()
                    : (tasksRoot.vertical
                        ? TaskManagerApplet.LayoutMetrics.preferredMinHeight()
                        : Math.max(tasksRoot.height / Plasmoid.configuration.maxStripes,
                             TaskManagerApplet.LayoutMetrics.preferredMinHeight()))
    implicitWidth: tasksRoot.vertical
        ? Math.max(TaskManagerApplet.LayoutMetrics.preferredMinWidth(), Math.min(TaskManagerApplet.LayoutMetrics.preferredMaxWidth(), tasksRoot.width / Plasmoid.configuration.maxStripes))
        : 0

    Layout.fillWidth: true
    Layout.fillHeight: !inPopup
    Layout.maximumWidth: tasksRoot.vertical
        ? -1
        : ((model.IsLauncher && !tasksRoot.iconsOnly) ? tasksRoot.height / taskList.rows : TaskManagerApplet.LayoutMetrics.preferredMaxWidth())
    Layout.maximumHeight: tasksRoot.vertical ? TaskManagerApplet.LayoutMetrics.preferredMaxHeight() : -1

    required property var model
    required property int index
    required property /*main.qml*/ Item tasksRoot

    readonly property int pid: model.AppPid
    readonly property string appName: model.AppName
    readonly property string appId: model.AppId.replace(/\.desktop/, '')
    readonly property bool isIcon: tasksRoot.iconsOnly || model.IsLauncher
    property bool toolTipOpen: false
    property bool inPopup: false
    property bool isWindow: model.IsWindow
    property bool minimizeFromClick: false
    property int childCount: model.ChildCount
    property int previousChildCount: 0
    property alias labelText: label.text
    property QtObject contextMenu: null
    readonly property bool smartLauncherEnabled: !inPopup
    property QtObject smartLauncherItem: null

    property Item audioStreamIcon: null
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    property bool completed: false
    // Store decoration QVariant for ghost icon creation (model.decoration
    // becomes unreliable during rowsAboutToBeRemoved).
    property var closingDecoration: null
    // Track WinIdList length to detect child window removals from a group.
    property var winIdList: model.WinIdList
    property int lastWinCount: winIdList ? winIdList.length : 0

    // Animation speed: 0=Fast, 1=Normal, 2=Slow.  Scales entry+minimize only.
    readonly property real animMul: {
        switch (Plasmoid.configuration.animationSpeed) {
            case 0: return 0.5;
            case 2: return 1.5;
            default: return 1.0;
        }
    }

    // Suppress minimise animation for newly-appeared tasks
    // (e.g. virtual-desktop switch where IsMinimized arrives set).
    Timer { id: entryCooldown; interval: 300 }

    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property bool tooltipControlsEnabled: Plasmoid.configuration.tooltipControls
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)

    readonly property bool highlighted: (inPopup && activeFocus) || (!inPopup && containsMouse)
        || (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open)
        || (!!tasksRoot.groupDialog && tasksRoot.groupDialog.visualParent === task)

    active: !inPopup && !tasksRoot.groupDialog && task.contextMenu?.status !== PlasmaExtras.Menu.Open
    interactive: model.IsWindow || mainItem.playerData
    location: Plasmoid.location
    mainItem: !Plasmoid.configuration.showToolTips || !model.IsWindow ? pinnedAppToolTipDelegate : openWindowToolTipDelegate

    SequentialAnimation {
        id: entryAnim
        ParallelAnimation {
            NumberAnimation { target: icon; property: "opacity"; from: 0.0; to: 1.0; duration: 200 * task.animMul; easing.type: Easing.OutQuad }
            NumberAnimation { target: entrySlide; property: "y"; from: 30; to: 0; duration: 200 * task.animMul; easing.type: Easing.OutBack }
        }
    }
    SequentialAnimation {
        id: minimizeAnim
        PauseAnimation { duration: 50 }
        ParallelAnimation {
            NumberAnimation { target: icon; property: "opacity"; to: 0.5; duration: 80 * task.animMul; easing.type: Easing.InQuad }
            NumberAnimation { target: minimizeBounce; property: "y"; to: 10; duration: 80 * task.animMul; easing.type: Easing.InQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: icon; property: "opacity"; to: 1.0; duration: 120 * task.animMul; easing.type: Easing.OutQuad }
            NumberAnimation { target: minimizeBounce; property: "y"; to: 0; duration: 120 * task.animMul; easing.type: Easing.OutQuad }
        }
    }

    function triggerMinimizePulse(): void {
        minimizeAnim.start();
    }

    NumberAnimation {
        id: pressDownAnim
        target: icon
        property: "scale"
        to: 0.85
        duration: 80
        easing.type: Easing.OutQuad
    }
    NumberAnimation {
        id: pressUpAnim
        target: icon
        property: "scale"
        to: 1.0
        duration: 250
        easing.type: Easing.OutBack
    }

    // Exit animation: slide down + scale down + fade out.
    // For multi-window close: exit → reappearAnim phase 2 (see onFinished).
    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation { target: icon; property: "opacity"; to: 0; duration: 150 * task.animMul; easing.type: Easing.InQuad }
            NumberAnimation { target: entrySlide; property: "y"; to: 50; duration: 150 * task.animMul; easing.type: Easing.InQuad }
            NumberAnimation { target: icon; property: "scale"; to: 0.5; duration: 150 * task.animMul; easing.type: Easing.InQuad }
        }
        onFinished: {
            if (model) {
                var remaining = model.ChildCount;
                if (model.IsLauncher) {
                    // Pinned last-close → reappear (the launcher reappears via Component.onCompleted)
                    // Pin readded launcher animation seperately.
                } else if (remaining > 0 || !model.IsGroupParent) {
                    // remaining > 0: other windows remain in the group → scale popup
                    // !IsGroupParent: group dissolved (2→1), delegate now a single window
                    // Both cases need reappearAnim to undo exitAnim's opacity=0 / scale=0.5 / y=50
                    reappearAnim.start();
                }
                // remaining == 0 && IsGroupParent → group was removed by model (ghost handles exit)
            }
        }
    }

    // Reappear animation for multi-window close: pop up like pinned launcher.
    // Position resets instantly then delayed scale + fade in.
    SequentialAnimation {
        id: reappearAnim
        PropertyAction { target: entrySlide; property: "y"; value: 0 }
        PropertyAction { target: minimizeBounce; property: "y"; value: 0 }
        PauseAnimation { duration: 100 * task.animMul }
        ParallelAnimation {
            NumberAnimation { target: icon; property: "scale"; from: 0.5; to: 1.0; duration: 70 * task.animMul; easing.type: Easing.OutQuad }
            NumberAnimation { target: icon; property: "opacity"; from: 0; to: 1.0; duration: 70 * task.animMul; easing.type: Easing.OutQuad }
        }
    }

    // Launcher reappear animation: delayed scale + fade in (no bounce).
    // Duration and delay both scale with animMul to match the user's speed preference.
    SequentialAnimation {
        id: launcherReappearAnim
        PauseAnimation { duration: 100 * task.animMul }
        ParallelAnimation {
            NumberAnimation { target: icon; property: "scale"; from: 0.5; to: 1.0; duration: 70 * task.animMul; easing.type: Easing.OutQuad }
            NumberAnimation { target: icon; property: "opacity"; from: 0; to: 1.0; duration: 70 * task.animMul; easing.type: Easing.OutQuad }
        }
    }

    // Bump animation: when a new window joins an existing group, briefly pop up.
    SequentialAnimation {
        id: bumpAnim
        ParallelAnimation {
            NumberAnimation { target: entrySlide; property: "y"; to: -4; duration: 80 * task.animMul; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: entrySlide; property: "y"; to: 0; duration: 120 * task.animMul; easing.type: Easing.OutBounce }
        }
    }

    // Pulse animation when one of multiple windows closes but icon stays
    // Brief scale up + opacity dip, then return to normal
    SequentialAnimation {
        id: pulseAnim
        ParallelAnimation {
            NumberAnimation { target: icon; property: "scale"; from: 0.8; to: 1.15; duration: 200; easing.type: Easing.OutQuad }
            NumberAnimation { target: icon; property: "opacity"; from: 0.7; to: 1.0; duration: 200; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: icon; property: "scale"; to: 1.0; duration: 300; easing.type: Easing.OutBack }
            NumberAnimation { target: icon; property: "opacity"; to: 1.0; duration: 300; easing.type: Easing.OutQuad }
        }
    }

    // Move animation: smooth transition when task buttons are reordered via drag
    property real oldX: -1
    property real oldY: -1

    onXChanged: {
        if (!completed) {
            return;
        }
        if (oldX < 0) {
            oldX = x;
            return;
        }
        moveAnim.x = oldX - x + translateTransform.x;
        moveAnim.y = translateTransform.y;
        oldX = x;
        moveAnim.restart();
    }
    onYChanged: {
        if (!completed) {
            return;
        }
        if (oldY < 0) {
            oldY = y;
            return;
        }
        moveAnim.y = oldY - y + translateTransform.y;
        moveAnim.x = translateTransform.x;
        oldY = y;
        moveAnim.restart();
    }
    SequentialAnimation {
        id: moveAnim
        property real x
        property real y
        onRunningChanged: {
            if (running) {
                ++task.parent.animationsRunning;
            } else {
                --task.parent.animationsRunning;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: translateTransform
                properties: "x"
                from: moveAnim.x
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
            NumberAnimation {
                target: translateTransform
                properties: "y"
                from: moveAnim.y
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
        }
    }
    transform: Translate {
        id: translateTransform
    }

    Accessible.name: model.display
    Accessible.description: {
        if (!model.display) {
            return "";
        }

        if (model.IsLauncher) {
            return i18nc("@info:usagetip %1 application name", "Launch %1", model.display)
        }

        let smartLauncherDescription = "";
        if (iconBox.active) {
            smartLauncherDescription += i18ncp("@info:tooltip", "There is %1 new message.", "There are %1 new messages.", task.smartLauncherItem.count);
        }

        if (model.IsGroupParent) {
            switch (Plasmoid.configuration.groupedTaskVisualization) {
            case 0:
                break; // Use the default description
            case 1: {
                return `${i18nc("@info:usagetip %1 task name", "Show Task tooltip for %1", model.display)}; ${smartLauncherDescription}`;
            }
            case 2: {
                if (effectWatcher.registered) {
                    return `${i18nc("@info:usagetip %1 task name", "Show windows side by side for %1", model.display)}; ${smartLauncherDescription}`;
                }
                // fallthrough
            }
            default:
                return `${i18nc("@info:usagetip %1 task name", "Open textual list of windows for %1", model.display)}; ${smartLauncherDescription}`;
            }
        }

        return `${i18nc("@info:usagetip %1 task name", "Activate %1", model.display)}; ${smartLauncherDescription}`;
    }
    Accessible.role: Accessible.Button
    Accessible.onPressAction: leftTapHandler.leftClick()

    onToolTipVisibleChanged: toolTipVisible => {
        task.toolTipOpen = toolTipVisible;
        if (!toolTipVisible) {
            tasksRoot.toolTipOpenedByClick = null;
        } else {
            tasksRoot.toolTipAreaItem = task;
        }
    }

    onContainsMouseChanged: {
        if (containsMouse) {
            task.forceActiveFocus(Qt.MouseFocusReason);
            task.updateMainItemBindings();
        } else {
            tasksRoot.toolTipOpenedByClick = null;
        }
    }

    onHighlightedChanged: {
        // ensure it doesn't get stuck with a window highlighted
        tasksRoot.cancelHighlightWindows();
    }

    onPidChanged: updateAudioStreams({delay: false})
    onAppNameChanged: updateAudioStreams({delay: false})

    onIsWindowChanged: {
        if (model.IsWindow) {
            taskInitComponent.createObject(task);
            updateAudioStreams({delay: false});
        }
    }

    onChildCountChanged: {
        // Only keep the original geometry-publish logic.
        if (TaskManagerApplet.TaskTools.taskManagerInstanceCount < 2 && childCount > previousChildCount) {
            tasksModel.requestPublishDelegateGeometry(modelIndex(), backend.globalRect(task), task);
        }

        previousChildCount = childCount;
    }

    // Detect child window additions/removals from the group by tracking WinIdList length.
    // When a window closes: list shrinks → exit+reappear animation.
    // When a new window joins an existing group: list grows → bump animation.
    onWinIdListChanged: {
        var newLen = task.winIdList ? task.winIdList.length : 0;
        if (newLen < task.lastWinCount && newLen > 0) {
            // Guard: exitAnim may not be ready if the signal fires during construction
            if (exitAnim) {
                exitAnim.start();
            }
            // exitAnim.onFinished triggers reappearAnim (see exitAnim definition)
        } else if (newLen > task.lastWinCount && task.lastWinCount > 0) {
            // New window joined existing group → bump up
            if (bumpAnim) {
                bumpAnim.start();
            }
        }
        task.lastWinCount = newLen;
    }

    onIndexChanged: {
        hideToolTip();

        if (!inPopup && !tasksRoot.vertical
                && !Plasmoid.configuration.separateLaunchers) {
            tasksRoot.requestLayout();
        }
    }

    onSmartLauncherEnabledChanged: {
        if (smartLauncherEnabled && !smartLauncherItem) {
            const component = Qt.createComponent("plasma.applet.org.kde.plasma.taskmanager.skyler", "SmartLauncherItem");
            const smartLauncher = component.createObject(task);
            component.destroy();

            smartLauncher.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);

            smartLauncherItem = smartLauncher;
        }
    }

    onHasAudioStreamChanged: {
        const audioStreamIconActive = hasAudioStream && audioIndicatorsEnabled;
        if (!audioStreamIconActive) {
            if (audioStreamIcon !== null) {
                audioStreamIcon.destroy();
                audioStreamIcon = null;
            }
            return;
        }
        // Create item on demand instead of using Loader to reduce memory consumption,
        // because only a few applications have audio streams.
        const component = Qt.createComponent("AudioStream.qml");
        audioStreamIcon = component.createObject(task);
        component.destroy();
    }
    onAudioIndicatorsEnabledChanged: task.hasAudioStreamChanged()

    Keys.onMenuPressed: event => contextMenuTimer.start()
    Keys.onReturnPressed: event => TaskManagerApplet.TaskTools.activateTask(modelIndex(), model, event.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered)
    Keys.onEnterPressed: event => Keys.returnPressed(event);
    Keys.onSpacePressed: event => Keys.returnPressed(event);
    Keys.onUpPressed: event => Keys.leftPressed(event)
    Keys.onDownPressed: event => Keys.rightPressed(event)
    Keys.onLeftPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index - 1);
        } else {
            event.accepted = false;
        }
    }
    Keys.onRightPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index + 1);
        } else {
            event.accepted = false;
        }
    }

    function modelIndex(): /*QModelIndex*/ var {
        return inPopup
            ? tasksModel.makeModelIndex(groupDialog.visualParent.index, index)
            : tasksModel.makeModelIndex(index);
    }

    function showContextMenu(args: var): void {
        task.hideImmediately();
        contextMenu = tasksRoot.createContextMenu(task, modelIndex(), args) as ContextMenu;
        contextMenu.show();
    }

    function updateAudioStreams(args: var): void {
        if (args) {
            // When the task just appeared (e.g. virtual desktop switch), show the audio indicator
            // right away. Only when audio streams change during the lifetime of this task, delay
            // showing that to avoid distraction.
            delayAudioStreamIndicator = !!args.delay;
        }

        var pa = pulseAudio.item;
        if (!pa || !task.isWindow) {
            task.audioStreams = [];
            return;
        }

        // Check appid first for app using portal
        // https://docs.pipewire.org/page_portal.html
        var streams = pa.streamsForAppId(task.appId);
        if (!streams.length) {
            streams = pa.streamsForPid(model.AppPid);
            if (streams.length) {
                pa.registerPidMatch(model.AppName);
            } else {
                // We only want to fall back to appName matching if we never managed to map
                // a PID to an audio stream window. Otherwise if you have two instances of
                // an application, one playing and the other not, it will look up appName
                // for the non-playing instance and erroneously show an indicator on both.
                if (!pa.hasPidMatch(model.AppName)) {
                    streams = pa.streamsForAppName(model.AppName);
                }
            }
        }

        task.audioStreams = streams;
    }

    function toggleMuted(): void {
        if (muted) {
            task.audioStreams.forEach(item => item.unmute());
        } else {
            task.audioStreams.forEach(item => item.mute());
        }
    }

    // Will also be called in activateTaskAtIndex(index)
    function updateMainItemBindings(): void {
        if ((mainItem.parentTask === this && mainItem.rootIndex.row === index)
            || (tasksRoot.toolTipOpenedByClick === null && !active)
            || (tasksRoot.toolTipOpenedByClick !== null && tasksRoot.toolTipOpenedByClick !== this)) {
            return;
        }

        mainItem.blockingUpdates = (mainItem.isGroup !== model.IsGroupParent); // BUG 464597 Force unload the previous component

        mainItem.parentTask = this;
        mainItem.rootIndex = tasksModel.makeModelIndex(index, -1);

        mainItem.appName = Qt.binding(() => model.AppName);
        mainItem.pidParent = Qt.binding(() => model.AppPid);
        mainItem.windows = Qt.binding(() => model.WinIdList);
        mainItem.isGroup = Qt.binding(() => model.IsGroupParent);
        mainItem.icon = Qt.binding(() => model.decoration);
        mainItem.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
        mainItem.isLauncher = Qt.binding(() => model.IsLauncher);
        mainItem.isMinimized = Qt.binding(() => model.IsMinimized);
        mainItem.display = Qt.binding(() => model.display);
        mainItem.genericName = Qt.binding(() => model.GenericName);
        mainItem.virtualDesktops = Qt.binding(() => model.VirtualDesktops);
        mainItem.isOnAllVirtualDesktops = Qt.binding(() => model.IsOnAllVirtualDesktops);
        mainItem.activities = Qt.binding(() => model.Activities);

        mainItem.smartLauncherCountVisible = Qt.binding(() => smartLauncherItem?.countVisible ?? false);
        mainItem.smartLauncherCount = Qt.binding(() => mainItem.smartLauncherCountVisible ? (smartLauncherItem?.count ?? 0) : 0);

        mainItem.blockingUpdates = false;
        tasksRoot.toolTipAreaItem = this;
    }

    Connections {
        target: pulseAudio.item
        ignoreUnknownSignals: true // Plasma-PA might not be available
        function onStreamsChanged(): void {
            task.updateAudioStreams({delay: true})
        }
    }

    TapHandler {
        id: menuTapHandler
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Stylus
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onLongPressed: {
            // When we're a launcher, there's no window controls, so we can show all
            // places without the menu getting super huge.
            if (task.model.IsLauncher) {
                task.showContextMenu({showAllPlaces: true})
            } else {
                task.showContextMenu();
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        gesturePolicy: TapHandler.WithinBounds // Release grab when menu appears
        onPressedChanged: if (pressed) contextMenuTimer.start()
    }

    Timer {
        id: contextMenuTimer
        interval: 0
        onTriggered: menuTapHandler.longPressed()
    }

    TapHandler {
        id: leftTapHandler
        acceptedButtons: Qt.LeftButton
        onTapped: (eventPoint, button) => leftClick()

        function leftClick(): void {
            if (task.active) {
                task.hideToolTip();
            }
            if (model.IsActive) {
                task.minimizeFromClick = true;
            }
            TaskManagerApplet.TaskTools.activateTask(modelIndex(), model, point.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered);
        }

        onPressedChanged: {
            if (pressed) {
                pressDownAnim.start();
            } else {
                pressUpAnim.start();
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.MiddleButton) {
                if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.NewInstance) {
                    tasksModel.requestNewInstance(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.Close) {
                    tasksModel.requestClose(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.ToggleMinimized) {
                    tasksModel.requestToggleMinimized(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.ToggleGrouping) {
                    tasksModel.requestToggleGrouping(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.BringToCurrentDesktop) {
                    TaskManagerApplet.TaskTools.foreachChildTask((childIndex) => {
                        tasksModel.requestVirtualDesktops(childIndex, [virtualDesktopInfo.currentDesktopByScreenGeometry(tasksModel.data(childIndex, TaskManager.AbstractTasksModel.ScreenGeometry))]);
                    }, modelIndex(), tasksModel);
                }
            } else if (button === Qt.BackButton || button === Qt.ForwardButton) {
                const playerData = mpris2Source.playerForLauncherUrl(task.model.LauncherUrlWithoutIcon, task.model.AppPid);
                if (playerData) {
                    if (button === Qt.BackButton) {
                        playerData.Previous();
                    } else {
                        playerData.Next();
                    }
                } else {
                    eventPoint.accepted = false;
                }
            }

            task.tasksRoot.cancelHighlightWindows();
        }
    }

    KSvg.FrameSvgItem {
        id: frame

        anchors {
            fill: parent

            topMargin: (!task.tasksRoot.vertical && taskList.rows > 1) ? TaskManagerApplet.LayoutMetrics.iconMargin : 0
            bottomMargin: (!task.tasksRoot.vertical && taskList.rows > 1) ? TaskManagerApplet.LayoutMetrics.iconMargin : 0
            leftMargin: ((task.inPopup || task.tasksRoot.vertical) && taskList.columns > 1) ? TaskManagerApplet.LayoutMetrics.iconMargin : 0
            rightMargin: ((task.inPopup || task.tasksRoot.vertical) && taskList.columns > 1) ? TaskManagerApplet.LayoutMetrics.iconMargin : 0
        }

        imagePath: "widgets/tasks"
        property bool isHovered: task.highlighted && Plasmoid.configuration.taskHoverEffect
        property string basePrefix: "normal"
        prefix: isHovered ? TaskManagerApplet.TaskTools.taskPrefixHovered(basePrefix, Plasmoid.location) : TaskManagerApplet.TaskTools.taskPrefix(basePrefix, Plasmoid.location)

        // Avoid repositioning delegate item after dragFinished
        DragHandler {
            id: dragHandler
            grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType

            function setRequestedInhibitDnd(value: bool): void {
                // This is modifying the value in the panel containment that
                // inhibits accepting drag and drop, so that we don't accidentally
                // drop the task on this panel.
                let item = this;
                while (item.parent) {
                    item = item.parent;
                    if (item.appletRequestsInhibitDnD !== undefined) {
                        item.appletRequestsInhibitDnD = value
                    }
                }
            }

            onActiveChanged: {
                if (active) {
                    icon.grabToImage(result => {
                        if (!dragHandler.active) {
                            // BUG 466675 grabToImage is async, so avoid updating dragSource when active is false
                            return;
                        }
                        setRequestedInhibitDnd(true);
                        tasksRoot.dragSource = task;
                        dragHelper.Drag.imageSource = result.url;
                        dragHelper.Drag.mimeData = {
                            "text/x-orgkdeplasmataskmanager_taskurl": backend.tryDecodeApplicationsUrl(model.LauncherUrlWithoutIcon).toString(),
                            [model.MimeType]: model.MimeData,
                            "application/x-orgkdeplasmataskmanager_taskbuttonitem": model.MimeData,
                        };
                        dragHelper.Drag.active = dragHandler.active;
                    });
                } else {
                    setRequestedInhibitDnd(false);
                    dragHelper.Drag.active = false;
                    dragHelper.Drag.imageSource = "";
                }
            }
        }
    }

    Loader {
        id: taskProgressOverlayLoader

        anchors.fill: frame
        asynchronous: true
        active: task.smartLauncherItem && task.smartLauncherItem.progressVisible

        source: "TaskProgressOverlay.qml"
    }

    Loader {
        id: iconBox

        anchors {
            left: parent.left
            leftMargin: adjustMargin(true, parent.width, taskFrame.margins.left)
            top: parent.top
            topMargin: adjustMargin(false, parent.height, taskFrame.margins.top)
        }

        width: task.inPopup ? Math.max(Kirigami.Units.iconSizes.sizeForLabels, Kirigami.Units.iconSizes.medium) : Math.min(task.parent?.minimumWidth ?? 0, task.height)
        height: task.inPopup ? width : (parent.height - adjustMargin(false, parent.height, taskFrame.margins.top)
                 - adjustMargin(false, parent.height, taskFrame.margins.bottom))

        asynchronous: true
        active: height >= Kirigami.Units.iconSizes.small
                && task.smartLauncherItem && task.smartLauncherItem.countVisible
        source: "TaskBadgeOverlay.qml"

        transform: [
            Translate { id: entrySlide; y: 0 },
            Translate { id: minimizeBounce; y: 0 }
        ]

        function adjustMargin(isVertical: bool, size: real, margin: real): real {
            if (!size) {
                return margin;
            }

            var margins = isVertical ? TaskManagerApplet.LayoutMetrics.horizontalMargins() : TaskManagerApplet.LayoutMetrics.verticalMargins();

            if ((size - margins) < Kirigami.Units.iconSizes.small) {
                return Math.ceil((margin * (Kirigami.Units.iconSizes.small / size)) / 2);
            }

            return margin;
        }

        Kirigami.Icon {
            id: icon

            anchors.fill: parent

            active: task.highlighted
            enabled: true

            source: task.model.decoration
        }

        states: [
            // Using a state transition avoids a binding loop between label.visible and
            // the text label margin, which derives from the icon width.
            State {
                name: "standalone"
                when: !label.visible && task.parent

                AnchorChanges {
                    target: iconBox
                    anchors.left: undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                PropertyChanges {
                    iconBox.anchors.leftMargin: 0
                    iconBox.width: Math.min(task.parent.minimumWidth, tasksRoot.height)
                        - iconBox.adjustMargin(true, task.width, taskFrame.margins.left)
                        - iconBox.adjustMargin(true, task.width, taskFrame.margins.right)
                }
            }
        ]

        Loader {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            active: task.model.IsStartup
            sourceComponent: busyIndicator
        }
    }

    PlasmaComponents3.Label {
        id: label

        visible: (task.inPopup || !task.tasksRoot.iconsOnly && !task.model.IsLauncher
            && (parent.width - iconBox.height - Kirigami.Units.smallSpacing) >= TaskManagerApplet.LayoutMetrics.spaceRequiredToShowText())

        anchors {
            fill: parent
            leftMargin: taskFrame.margins.left + iconBox.width + TaskManagerApplet.LayoutMetrics.labelMargin
            topMargin: taskFrame.margins.top
            rightMargin: taskFrame.margins.right + (task.audioStreamIcon !== null && task.audioStreamIcon.visible ? (task.audioStreamIcon.width + TaskManagerApplet.LayoutMetrics.labelMargin) : 0)
            bottomMargin: taskFrame.margins.bottom
        }

        wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap
        elide: Text.ElideRight
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: Plasmoid.configuration.maxTextLines || undefined

        // The accessible item of this element is only used for debugging
        // purposes, and it will never gain focus (thus it won't interfere
        // with screenreaders).
        Accessible.ignored: !visible
        Accessible.name: parent.Accessible.name + "-labelhint"

        // use State to avoid unnecessary re-evaluation when the label is invisible
        states: State {
            name: "labelVisible"
            when: label.visible

            PropertyChanges {
                label.text: task.model.display
            }
        }
    }

    states: [
        State {
            name: "launcher"
            when: task.model.IsLauncher

            PropertyChanges {
                frame.basePrefix: ""
            }
        },
        State {
            name: "attention"
            when: task.model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)

            PropertyChanges {
                frame.basePrefix: "attention"
            }
        },
        State {
            name: "minimized"
            when: task.model.IsMinimized

            PropertyChanges {
                frame.basePrefix: "minimized"
            }
            StateChangeScript {
                script: {
                    if (entryCooldown.running) return;  // just appeared
                    if (task.minimizeFromClick) {
                        task.minimizeFromClick = false;
                        return;  // skip animation on click
                    }
                    minimizeDelay.start();
                }
            }
        },
        State {
            name: "active"
            when: task.model.IsActive

            PropertyChanges {
                frame.basePrefix: "focus"
            }
        }
    ]

    Timer {
        id: minimizeDelay
        interval: 50
        onTriggered: {
            if (entryCooldown.running) return;
            if (task.parent && task.isWindow && task.model.IsMinimized)
                minimizeAnim.start();
        }
    }

    Component.onCompleted: {
        // Store decoration for ghost exit animation
        closingDecoration = model ? model.decoration : null;

        if (!inPopup && model.IsWindow) {
            const component = Qt.createComponent("GroupExpanderOverlay.qml");
            component.createObject(task);
            component.destroy();
            updateAudioStreams({delay: false});
        }

        if (!inPopup && !model.IsWindow) {
            taskInitComponent.createObject(task);
        }
        // Entry animation only for truly new windows (skip windows spawned from pinned launchers)
        if (model.IsWindow && !model.IsLauncher && !model.HasLauncher) {
            icon.opacity = 0.0;
            entrySlide.y = 30;
            entryAnim.start();
        }
        // Bump feedback for windows opened from pinned launchers (first window)
        if (model.IsWindow && model.HasLauncher) {
            if (bumpAnim) {
                bumpAnim.start();
            }
        }
        // Reappear animation for pinned launchers in icons-only mode
        // (e.g. after the last window closes and the launcher becomes visible again)
        // Uses launcherReappearAnim: 150ms delay + OutQuad (no bounce).
        // Set opacity=0 so the icon is invisible during the PauseAnimation delay.
        if (!inPopup && tasksRoot.iconsOnly && model.IsLauncher && !model.IsWindow && !model.IsStartup) {
            icon.opacity = 0.0;
            launcherReappearAnim.start();
        }
        completed = true;
        entryCooldown.start();
    }
}
