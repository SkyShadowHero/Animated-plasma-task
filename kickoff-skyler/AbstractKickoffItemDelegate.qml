/*
    SPDX-FileCopyrightText: 2011 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2012 Gregor Taetzner <gregor@freenet.de>
    SPDX-FileCopyrightText: 2014 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2015-2018 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2022 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates as T
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "code/tools.js" as Tools
import org.kde.plasma.plasmoid

T.ItemDelegate {
    id: root

    enum AppNameFormat {
        NameOnly,
        GenericNameOnly,
        NameAndGenericName,
        GenericNameAndName
    }

    // model properties
    required property var model
    required property int index
    required property url url
    required property var decoration
    required property string description
    required property bool isMultilineText

    readonly property Flickable view: ListView.view ?? GridView.view
    property bool isCategoryListItem: false
    property bool removalPlaceholderActive: false
    readonly property bool hasActionList: model && (model.favoriteId !== null || ("hasActionList" in model && model.hasActionList === true))
    property bool isSearchResult: false

    readonly property bool isSeparator: model && (model.isSeparator === true)
    // Guarded: the measuring instances in KickoffSingleton have no applet
    // context, so `Plasmoid.configuration` is undefined there.
    readonly property bool fluent: Plasmoid.configuration?.useFluentStyle ?? false
    // A group separator in Fluent is empty space, not a line: the row keeps a
    // little height to breathe but draws nothing (see KickoffListDelegate).
    property int separatorHeight: fluent
        ? FluentStyle.spacingMedium
        : KickoffSingleton.lineSvg.horLineHeight + (2 * Kirigami.Units.smallSpacing)
    property int itemHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset, implicitContentHeight + topPadding + bottomPadding)

    readonly property bool dragEnabled: enabled && !isCategoryListItem
        && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable

    readonly property alias mouseArea: mouseArea

    // Upstream turns the label/icon to the highlighted colour while the item is
    // pressed, because the themed pressed state paints a highlight-coloured
    // background under it. The Fluent card never does — it is a white/neutral
    // lift — so the text has to keep its normal colour, otherwise it flashes
    // white (on light) for the duration of the click.
    readonly property bool iconAndLabelsShouldlookSelected: down && !isCategoryListItem
        && !(Plasmoid.configuration?.useFluentStyle ?? false)

    property bool labelTruncated: false
    property bool descriptionTruncated: false
    property bool descriptionVisible: true

    property Item dragIconItem: null

    down: mouseArea.pressed || dragHandler.active

    // WinUI press feedback. It is applied to the delegate itself so the state
    // layer, the glyph and the labels shrink together as one — scaling only the
    // content (as before) left the highlight at full size, which read as the
    // text sliding around inside a static box.
    scale: root.fluent && root.down && !root.isSeparator ? 0.96 : 1
    transformOrigin: Item.Center
    Behavior on scale {
        enabled: root.fluent
        NumberAnimation {
            duration: FluentStyle.durationFast
            easing.type: FluentStyle.easingSoft
        }
    }

    function openActionMenu(x = undefined, y = undefined) {
        if (!hasActionList) { return; }

        let actions = Array.from(model.actionList);
        const favoriteActions = Tools.createFavoriteActions(
            i18n, //i18n() function callback // qmllint disable unqualified
            root.view.model.favoritesModel,
            model.favoriteId,
        );
        if (favoriteActions) {
            if (actions && actions.length > 0) {
                // same logic as in kicker's fillActionMenu()
                // Insert favoriteActions after the "Add to" actions (called
                // "addLauncherActions" by libkicker)
                const firstAddToActionIndex = actions.findIndex((action) =>
                    ["addToDesktop", "addToTaskManager", "addToPanel"].includes(action?.actionId),
                );
                if (firstAddToActionIndex >= 0) {
                    actions.splice(firstAddToActionIndex, 0, ...favoriteActions);
                } else {
                    // Or at the end (with a separator) if they're not found
                    actions.push({ type: "separator" }, ...favoriteActions);
                }
            } else {
                actions = favoriteActions;
            }
        }

        if (actions && actions.length > 0) {
            ActionMenu.plasmoid = kickoff;
            ActionMenu.menu.visualParent = root;
            ActionMenu.actionList = actions;
            if (x !== undefined && y !== undefined) {
                ActionMenu.menu.open(x, y);
            } else {
                ActionMenu.menu.openRelative();
            }
        }
    }

    // The default Z value for delegates is 1. The default Z value for the section delegate is 2.
    // The highlight gets a value of 3 while the drag is active and then goes back to the default value of 0.
    z: Drag.active ? 4 : 1

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: isSeparator ? separatorHeight : itemHeight

    spacing: KickoffSingleton.fontMetrics.descent

    enabled: !isSeparator && !model.disabled
    hoverEnabled: false

    text: model.compactNameWrapped ?? model.compactName ?? model.displayWrapped ?? model.display
    Accessible.role: Accessible.ListItem
    Accessible.description: root.description !== root.text ? root.description : ""
    Accessible.onPressAction: {
        root.forceActiveFocus() // trigger is focus guarded
        action.trigger()
    }

    // Using an action so that it can be replaced or manually triggered
    // using `model` () instead of `root.model` leads to errors about
    // `model` not having the trigger() function
    action: T.Action {
        onTriggered: {
            // Unless we're showing search results, eat the activation if we
            // don't have focus, to prevent the return/enter key from
            // inappropriately activating unfocused items
            // Also block activation while dragging.
            if ((!root.activeFocus && !root.isSearchResult) || dragHandler.active || touchDragHandler.active) {
                return;
            }
            root.view.currentIndex = root.index
            // if successfully triggered, close popup
            if (root.view.model.trigger && root.view.model.trigger(root.index, "", null)) {
                if (kickoff.hideOnWindowDeactivate) {
                    kickoff.expanded = false;
                }
            }
        }
    }

    function performDrag(handler: DragHandler): void {
        if (!handler.active) {
            kickoff.dragSource.Drag.active = false;
            kickoff.dragSource.Drag.imageSource = "";
            kickoff.dragSource.sourceItem = null;
            return;
        }
        root.dragIconItem.grabToImage(result => {
            if (!handler.active) {
                return;
            }
            kickoff.dragSource.sourceItem = root;
            kickoff.dragSource.Drag.imageSource = result.url;
            kickoff.dragSource.Drag.mimeData = {
                "text/uri-list" : [root.url]
            };
            kickoff.dragSource.Drag.active = handler.active;
        });
    }

    DragHandler {
        id: dragHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        enabled: root.dragEnabled && root.dragIconItem !== null
        target: null // Using this Item fixes drag and drop causing delegates to reset to a 0 X position and overlapping each other.

        onActiveChanged: root.performDrag(this)
    }

    DragHandler {
        id: touchDragHandler
        acceptedDevices: PointerDevice.TouchScreen
        enabled: dragHandler.enabled
        target: null
        yAxis.enabled: false

        onActiveChanged: root.performDrag(this)
    }

    MouseArea {
        id: mouseArea
        parent: root
        anchors.fill: parent
        anchors.margins: 1
        // Flickable margins are not mirrored, so disable layout mirroring
        LayoutMirroring.enabled: false
        // Only for ListView since extending margins for GridView is hard.
        // Fluent keeps the hit area inside the row: the negative margins would
        // also cover the list padding (and the divider strip), so hovering there
        // would highlight a row the pointer is not on.
        anchors.leftMargin: root.fluent
            ? anchors.margins
            : (root.view instanceof ListView ? -root.view.leftMargin : anchors.margins)
        anchors.rightMargin: root.fluent
            ? anchors.margins
            : (root.view instanceof ListView ? -root.view.rightMargin : anchors.margins)
        hoverEnabled: !root.isSeparator
            && root.view
            // When the movedWithWheel condition is broken, this ensures that
            // onEntered is called again without moving the mouse.
            && !root.view.movedWithWheel
            // Fix VerticalStackView animation causing view currentIndex
            // to change while delegates are moving under the mouse cursor
            && kickoff.fullRepresentationItem && !kickoff.fullRepresentationItem.contentItem.busy && !kickoff.fullRepresentationItem.blockingHoverFocus
        // A separator is empty space, so it must not be a hover target at all:
        // otherwise the pointer lights up a "row" that draws nothing.
        enabled: !root.isSeparator
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered: {
            // - When the movedWithKeyboard condition is broken, we do not want to
            //   select the hovered item without moving the mouse.
            // - Don't highlight separators.
            // - Don't switch category items on hover if the setting isn't enabled
            if (root.view.movedWithKeyboard || root.isSeparator
                || (root.isCategoryListItem && !Plasmoid.configuration.switchCategoryOnHover)) {
                return
            }

            // forceActiveFocus() touches multiple items, so check for
            // activeFocus first to be more efficient. Keep activeFocus
            // stable if it's on the searchField to avoid unintentional
            // activation with Space key presses.
            if (!root.activeFocus && !kickoff.searchField?.activeFocus) {
                root.forceActiveFocus(Qt.MouseFocusReason)
            }
            // No need to check currentIndex first because it's
            // built into QQuickListView::setCurrentIndex() already
            root.view.currentIndex = root.index
        }
        onPressed: mouse => {
            // Select and focus on press to improve responsiveness and touch feedback
            root.view.currentIndex = root.index
            root.forceActiveFocus(Qt.MouseFocusReason)

            // We normally try to open right click menus on press like Qt Widgets
            if (mouse.button === Qt.RightButton) {
                root.openActionMenu(mouseX, mouseY)
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.action.trigger()
            }
        }

        TapHandler {
            acceptedDevices: PointerDevice.TouchScreen
            onLongPressed: root.openActionMenu(point.position.x, point.position.y)
        }
    }

    PC3.ToolTip.text: {
        if (root.labelTruncated) {
            return model?.display ?? ""
        } else if (root.descriptionTruncated || (!root.descriptionVisible && (root.isSearchResult
                                                                              || Plasmoid.configuration.appNameFormat > 1))) {
            return description
        }
        return ""
    }
    PC3.ToolTip.visible: mouseArea.containsMouse && PC3.ToolTip.text.length > 0
    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

    background: Loader {
        id: backgroundLoader

        readonly property bool current: (root.GridView?.isCurrentItem || root.ListView?.isCurrentItem) ?? false

        // Fluent keeps a state layer on every item so hovering fades one in —
        // the theme only ever needs it on the current item. Separators draw
        // nothing at all, not even a hover layer.
        active: !root.isSeparator && ((Plasmoid.configuration?.useFluentStyle ?? false) || current)

        sourceComponent: FluentHighlight {
            anchors.fill: parent
            z: (root.Drag.active ?? false) ? 3 : 0
            hovered: (Plasmoid.configuration?.useFluentStyle ?? false) ? root.mouseArea.containsMouse : true
            selected: backgroundLoader.current
            // Same white card as the selected category in the sidebar, so both
            // panes mark "here" identically instead of the right pane looking
            // washed out with a grey layer (and dark inverts it to a lifted
            // white layer, see FluentStyle.selectionSurface).
            selectedColor: FluentStyle.selectionSurface
            radius: root.GridView ? FluentStyle.radiusOverlay : FluentStyle.radiusControl

            pressed: root.down && !root.isCategoryListItem

            // Guarded: this Loader also runs for the measuring delegates in
            // KickoffSingleton, where `view` is still null.
            active: (root.view?.activeFocus ?? false) ||
                    (kickoff.contentArea === root && (kickoff.searchField?.activeFocus ?? false))
        }
    }
}
