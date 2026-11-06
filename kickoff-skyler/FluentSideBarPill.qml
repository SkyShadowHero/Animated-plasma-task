/* SPDX-FileCopyrightText: 2026 SkyShadowHero <skyler@example.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid

/**
 * Fluent navigation indicator for the category sidebar: a thin accent pill
 * pinned to the left edge of the selected row.
 *
 * Declare it as a child of a KickoffListView and pass that view in. It follows
 * the view's currentItem, so switching categories (mouse, keyboard, or the
 * "Applications / Places" tab bar) moves the pill instead of popping it to the
 * new row.
 *
 * Motion is the Compose / Material navigation indicator: both ends of the bar
 * start on the previous row, but only the leading end (the one in the direction
 * of travel) moves right away. The trailing end waits a beat and then hurries
 * after it, so the bar first stretches and then settles back to its normal
 * length — it reads as being dragged across rather than teleported.
 *
 * Positioning is deliberately *not* computed from the index step. The sidebar
 * interleaves group separator rows between the entries, so `index * rowHeight`
 * is off by the height of every separator it crosses. The trip distance is
 * measured from the two rows themselves instead.
 */
Rectangle {
    id: root

    // The KickoffListView this pill belongs to (typed as var so the QML
    // compiler does not have to resolve the aliased `view` property).
    property var listView: null

    readonly property Item listItem: listView ? listView.currentItem : null
    readonly property Flickable flick: listView ? listView.view : null
    readonly property bool fluent: Plasmoid.configuration?.useFluentStyle ?? false

    readonly property real fullHeight: listItem
        ? Math.min(FluentStyle.navigationIndicatorHeight, listItem.height * 0.45)
        : 0

    // Top of the pill's resting slot, in the view's (viewport) coordinates.
    //
    // `mapToItem()` on its own is not a tracked operation: a binding that only
    // calls it keeps whatever value it computed when the pill was created, so
    // the pill stayed put as soon as the category list scrolled. This is written
    // from plain, observable properties instead — the row's own y, the content
    // item's offset (which moves with contentY), and the row's height — so the
    // binding re-evaluates on every scroll step.
    readonly property real slotTop: {
        if (!listItem || !flick) {
            return 0;
        }
        const contentOffset = flick.contentItem ? flick.contentItem.y : 0;
        return listItem.y + contentOffset + (listItem.height - fullHeight) / 2;
    }

    // ── Travel ────────────────────────────────────────────────────────────
    // Offsets of the two ends, in pixels, relative to the resting slot. Both
    // start at the distance between the old row and the new one and run to
    // zero, so the pill begins exactly where it was and ends exactly on its
    // row; a missed or interrupted animation can never leave it lost
    // somewhere, because the resting position always comes from `slotTop`.
    property real leadOffset: 0
    property real trailOffset: 0
    // 1 = travelling down (the bottom end leads), -1 = travelling up.
    property int dir: 1

    readonly property real topOffset: dir > 0 ? trailOffset : leadOffset
    readonly property real bottomOffset: dir > 0 ? leadOffset : trailOffset

    y: slotTop + Math.min(topOffset, bottomOffset)
    height: Math.max(2, fullHeight + Math.abs(bottomOffset - topOffset))
    width: FluentStyle.navigationIndicatorWidth
    radius: width / 2
    color: FluentStyle.accent
    visible: fluent && listItem !== null

    z: 100

    x: {
        if (!listItem) {
            return 0;
        }
        const contentOffset = flick && flick.contentItem ? flick.contentItem.x : 0;
        return listItem.x + contentOffset + 3;
    }

    // The row shrinks on press (see AbstractKickoffItemDelegate), so the pill
    // shrinks with it — a full-size mark next to a pressed row looks detached
    // from the item it belongs to.
    scale: listItem && listItem.down ? 0.75 : 1
    transformOrigin: Item.Center
    Behavior on scale {
        NumberAnimation {
            duration: FluentStyle.durationFast
            easing.type: FluentStyle.easingSoft
        }
    }

    // The trip is measured when the *row* changes, not when the index does:
    // `currentIndexChanged` fires before `currentItem` has been updated, so at
    // that point `slotTop` still described the old row and the offset was
    // applied on top of it — the pill jumped a whole row away and then crawled
    // back, which is what made the motion look stuttery.
    property Item previousItem: null

    onListItemChanged: {
        const previous = root.previousItem;
        root.previousItem = root.listItem;
        if (!previous || !root.listItem || previous === root.listItem) {
            return;
        }
        travel.stop();
        root.leadOffset = 0;
        root.trailOffset = 0;

        // Both delegates live in the flickable's content coordinates, so the
        // difference of their y is the true distance between the rows —
        // separator rows included, which an index * rowHeight product misses.
        const delta = previous.y - root.listItem.y;
        if (delta === 0) {
            return;
        }
        root.dir = delta < 0 ? 1 : -1;
        root.leadOffset = delta;
        root.trailOffset = delta;
        travel.restart();
    }

    // A scroll while the pill is travelling would move the slot out from under
    // the offsets; drop the trip and ride the row instead.
    Connections {
        target: root.flick
        function onContentYChanged(): void {
            if (travel.running) {
                travel.stop();
                root.leadOffset = 0;
                root.trailOffset = 0;
            }
        }
    }

    ParallelAnimation {
        id: travel

        // Leading end: one continuous glide on Compose's "fast-out-slow-in"
        // curve.
        NumberAnimation {
            target: root
            property: "leadOffset"
            to: 0
            duration: 470
            easing.type: Easing.Bezier
            easing.bezierCurve: [0.4, 0.0, 0.2, 1.0]
        }
        // Trailing end: held back for a beat (that is what stretches the bar),
        // then it hurries to catch up and settles together with the leading
        // end — so the bar ends at exactly its normal length.
        SequentialAnimation {
            PauseAnimation {
                duration: 70
            }
            NumberAnimation {
                target: root
                property: "trailOffset"
                to: 0
                duration: 400
                easing.type: Easing.InOutCubic
            }
        }
    }
}
