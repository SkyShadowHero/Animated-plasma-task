/*
 * SPDX-FileCopyrightText: 2026 SkyShadowHero <skyler@example.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.components as KirigamiComponents
import org.kde.coreaddons as KCoreAddons
import org.kde.config as KConfig
import org.kde.kcmutils as KCM
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.sessions as Sessions
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.plasmoid
import "code/tools.js" as Tools

/**
 * A 1:1 recreation of the Windows 11 Start menu, drawn entirely with Fluent
 * tokens, so it follows the system light/dark scheme and the KDE accent.
 *
 * It is a drop-in replacement for FullRepresentation's body: it owns its own
 * search field (published as kickoff.searchField), a Pinned grid backed by the
 * favourites model with paging, an optional Recent list from Plasma's own
 * recently-used model, an All apps view, and a user / power footer. All launching goes
 * through the Kicker models, so favourites, recent usage and search behave
 * exactly as they do in the classic layout.
 */
T.Page {
    id: root

    // Published so the applet's queries and keyboard helpers find us exactly
    // as they find the classic Header.
    property alias searchField: searchFieldItem

    // The classic delegates read `blockingHoverFocus` off the representation;
    // define it here so the guard in AbstractKickoffItemDelegate stays valid.
    readonly property bool blockingHoverFocus: false

    // RootModel is autoPopulate:false; the classic FullRepresentation fills it
    // with an explicit refresh() on completion. Since the Loader picks exactly
    // one representation, the Win11 layout has to do that itself, otherwise
    // modelForRow(1) (All apps) stays empty. modelForRow() also creates no QML
    // dependency, so poking the row on every refresh re-evaluates the binding.
    property int appsModelRow: 1
    readonly property var appsModel: kickoff.rootModel.modelForRow(root.appsModelRow)

    // ── All apps: grouping mode ─────────────────────────────────────────
    // "alpha" is the Windows drawer: one flat list whose headings are each
    // app's first letter. "category" reuses the grouping the classic layout
    // already has — taken from RootModel itself instead of being guessed
    // from each .desktop's Categories= field. The model parses the system
    // menu file (applications.menu), so row 0 is Favourites, row 1 the flat
    // All apps model, and rows 2..N are the freedesktop categories, already
    // translated and with their own icon; modelForRow(row) is that
    // category's app list for any of them.
    //
    // The mode is a setting (ConfigGeneral → "Group by"), not a control in
    // the menu: a switch inside the drawer was hard to see and hit, and the
    // preference belongs with the other layout options anyway.
    readonly property string configuredGrouping:
        (Plasmoid.configuration?.win11AllAppsGrouping ?? 0) === 1 ? "category" : "alpha"
    // Plain property, not a binding: the swap animation assigns it halfway
    // through its own timeline, and a binding would be broken by that first
    // assignment. The setting is mirrored in on completion and on change.
    property string allAppsGrouping: "alpha"
    readonly property bool appsByCategory: root.allAppsGrouping === "category"

    // ── Grouping swap ───────────────────────────────────────────────────
    // Changing the grouping rebuilds the whole All apps view, so the change
    // is staged instead of snapping: the old drawer sinks to 0.8 and fades
    // out, the model is swapped while nothing is visible, then the new
    // drawer grows back in. Driven by the two properties below, which the
    // All apps loader binds its scale / opacity to.
    property real appsSwapScale: 1
    property real appsSwapOpacity: 1
    property string pendingGrouping: ""

    // rowCount()/modelForRow() emit nothing and create no QML dependency, so
    // every refresh bumps this counter to re-run the derivations below.
    property int categoryRevision: 0

    readonly property var categoryEntries: {
        const revision = root.categoryRevision;
        const rm = kickoff.rootModel;
        const out = [];
        if (!rm) {
            return out;
        }
        for (let row = 2; row < rm.rowCount(); ++row) {
            const child = rm.modelForRow(row);
            if (!child || child.count < 1) {
                continue;
            }
            out.push({
                name: String(rm.labelForRow(row) ?? ""),
                // Category rows carry a QIcon in the decoration role;
                // Kirigami.Icon.source accepts either that or a string.
                icon: rm.data(rm.index(row, 0), Qt.DecorationRole) ?? "",
                model: child,
                count: child.count
            });
        }
        return out;
    }

    Component.onCompleted: {
        root.allAppsGrouping = root.configuredGrouping;
        kickoff.rootModel.refresh();
    }

    Connections {
        target: kickoff.rootModel
        function onRefreshed(): void {
            root.appsModelRowChanged()
            root.categoryRevision++
        }
    }

    // The grouping now comes from the configuration dialog. Mirror it in
    // through the same staged swap the in-menu control used, so the drawer
    // still cross-fades instead of snapping if the setting changes while the
    // menu happens to be open.
    Connections {
        target: Plasmoid.configuration
        function onWin11AllAppsGroupingChanged(): void {
            root.setAllAppsGrouping(root.configuredGrouping);
        }
    }

    // The page sits inside the theme's frame margins. Negative insets push
    // the acrylic backdrop out over the real card edge (positive insets would
    // pull it inward and leave an untouched ring); the content itself keeps
    // normal padding and lays itself out inside the card.
    leftInset: -kickoff.backgroundMetrics.leftPadding
    rightInset: -kickoff.backgroundMetrics.rightPadding
    topInset: -kickoff.backgroundMetrics.topPadding
    bottomInset: -kickoff.backgroundMetrics.bottomPadding

    // Layout metrics, scaled from gridUnit so the menu keeps Win11's
    // proportions at any Plasma scale factor. gridUnit is 18 at 100%.
    readonly property real u: Kirigami.Units.gridUnit
    readonly property int menuWidth: Math.round(u * 34)
    readonly property int menuHeight: Math.round(u * 37)
    readonly property int tileWidth: Math.round(u * 4.6)
    readonly property int tileHeight: Math.round(u * 5)
    readonly property int iconSize: Math.round(u * 2.2)

    // Optional Recent block above All apps. It reads Plasma's own
    // RecentUsageModel, the same History list Kickoff shows in Places; the
    // setting is off by default and the section disappears when empty.
    readonly property bool showWin11Recent: (Plasmoid.configuration?.win11ShowRecent ?? false)
    // The Home strip shows this many in one horizontal row; the full Recent
    // page lists everything the model returns.
    readonly property int recentRowLimit: 12
    readonly property int recentRowHeight: Math.round(u * 2.4)

    // Independent model so Fluent's Recent can include files and folders
    // without changing the classic Kickoff History page (which uses the
    // app-only kickoff.recentUsageModel).
    Kicker.RecentUsageModel {
        id: win11RecentModel
        favoritesModel: kickoff.rootModel.favoritesModel
        shownItems: Kicker.RecentUsageModel.AppsAndDocs
    }

    // All apps drawer style: Pinned-style cards or compact list rows. Lives on
    // the page rather than on the home item so the category drawer — declared
    // at page scope — can read it too.
    readonly property bool appsAsCards: (Plasmoid.configuration?.win11AppsAsCards ?? false)

    implicitWidth: menuWidth
    implicitHeight: menuHeight
    Layout.minimumWidth: menuWidth
    Layout.minimumHeight: menuHeight

    // The "fake acrylic" card: a colour cast plus grain drawn by QML, not a
    // real compositor blur. The Win11 menu is always a frosted card; the
    // separate option only governs the classic layout.
    background: FluentAcrylic {
        opacity: 1
    }

    KCoreAddons.KUser {
        id: kuser
    }

    // Publish our field the same way the classic Header does, so the applet's
    // runner query binds to whichever representation is currently loaded.
    Binding {
        target: kickoff
        property: "searchField"
        value: searchFieldItem
        restoreMode: Binding.RestoreNone
    }
    Connections {
        target: kickoff
        function onExpandedChanged(): void {
            // Never leave the surface shrunk away — and never leave the A–Z
            // sheet up: the applet is only hidden, not reloaded, so the sheet
            // would still be there the next time the menu opens.
            shrinkAway.stop();
            growBack.stop();
            sheetCloseTimer.stop();
            letterSheet.sheetOpen = false;
            root.contentScale = 1;
            root.contentOpacity = 1;
            root.pickerActive = false;
            // A grouping swap caught mid-flight would leave the drawer faded
            // out; settle it on the mode that was actually chosen.
            groupingSwap.stop();
            if (root.pendingGrouping.length > 0) {
                root.allAppsGrouping = root.pendingGrouping;
            }
            root.appsSwapScale = 1;
            root.appsSwapOpacity = 1;
            if (!kickoff.expanded) {
                suppressTextSwitch = true;
                searchFieldItem.clear();
                // A menu closed while the field was focused must not reopen
                // with the focus accent still painted.
                searchFieldItem.focus = false;
                suppressTextSwitch = false;
            } else {
                // Always open on the Home page, even if the last session was
                // left on All apps or an empty search result.
                root.showHome();
                // ...and always at its top. The applet is only hidden between
                // opens, so the page keeps the scroll offset it had when it was
                // closed; Win11 starts at the top every single time.
                root.scrollToTop();
                // Qt hands the focus to the first focusable item when a popup
                // is shown, and the search box is that item. Take it back so
                // the menu opens without a blinking caret — unless the user is
                // already typing, in which case the field must keep it.
                Qt.callLater(() => {
                    if (searchFieldItem.activeFocus && searchFieldItem.text.length === 0) {
                        root.forceActiveFocus(Qt.OtherFocusReason);
                    }
                });
            }
        }
    }

    // ── Search → view switching ─────────────────────────────────────────
    // Clearing the field on leaving search must not bounce us back to Home:
    // the text handler checks this guard before deciding which view to show.
    property bool suppressTextSwitch: false

    // Put whichever page is showing back to its beginning. Every page owns its
    // own scroll surface (Home scrolls both Pinned and the drawer, All apps is
    // a grid, Search is a list), so each one exposes the same one-liner and the
    // page just forwards to it.
    function scrollToTop(): void {
        const page = stackView.currentItem;
        if (page && page.scrollToTop) {
            page.scrollToTop();
        }
    }

    // Every page change goes through the same shrink/fade. The stack view's
    // own slide transition is disabled (see its replaceEnter/Exits), so this
    // is the only motion the user sees.
    function zoomToPage(component): void {
        if (pageZoomAnim.running) {
            return;
        }
        root.pageSwitchTarget = component;
        pageZoomAnim.restart();
    }

    function showHome(): void {
        if (stackView.currentItem && stackView.currentItem.objectName === "win11Home") {
            return;
        }
        zoomToPage(homeComponent);
    }

    function showAllApps(): void {
        suppressTextSwitch = true;
        searchFieldItem.text = "";
        suppressTextSwitch = false;
        zoomToPage(allAppsComponent);
    }

    function showRecent(): void {
        if (stackView.currentItem && stackView.currentItem.objectName === "win11Recent") {
            return;
        }
        suppressTextSwitch = true;
        searchFieldItem.text = "";
        suppressTextSwitch = false;
        zoomToPage(recentComponent);
    }

    function showSearch(): void {
        if (stackView.currentItem && stackView.currentItem.objectName === "win11Search") {
            return;
        }
        zoomToPage(searchComponent);
    }

    // ── Search focus and launch-by-Return ───────────────────────────────
    // The menu opens with the focus on the page, not in the search box: a
    // caret blinking there on every open is noise, and most opens are a click
    // on a tile. Typing is still the fast path — the first printable key
    // hands the focus to the field *and* types that key into it, so
    // Super → "firefox" → Return launches without reaching for Ctrl+F.
    readonly property var searchPage: stackView.currentItem
        && stackView.currentItem.objectName === "win11Search" ? stackView.currentItem : null

    // A Return keypress that arrived while the runner was still answering.
    property bool pendingLaunch: false

    Keys.onPressed: event => {
        if (root.pickerActive) {
            return;
        }
        // Shortcuts and Alt/Ctrl/Meta combinations belong to the session.
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) {
            return;
        }
        // Return still launches after the box has lost the caret (a click on
        // the empty menu), so the "type, hit Return" flow never depends on
        // where the focus happens to sit.
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.searchPage) {
                root.launchFirstResult();
                event.accepted = true;
            }
            return;
        }
        // With the focus on the page the popup's own CloseOnEscape never sees
        // the key, so closing has to be handled here as well.
        if (event.key === Qt.Key_Escape) {
            kickoff.expanded = false;
            event.accepted = true;
            return;
        }
        const ch = event.text;
        // One printable character: the field owns it from here on.
        if (ch.length === 1 && ch.charCodeAt(0) >= 0x20 && ch.charCodeAt(0) !== 0x7f) {
            root.focusSearchField(ch);
            event.accepted = true;
        }
    }

    function focusSearchField(seedText): void {
        // Already typing: the key was delivered to the field itself and must
        // not be inserted twice.
        if (searchFieldItem.activeFocus) {
            return;
        }
        searchFieldItem.forceActiveFocus(Qt.ShortcutFocusReason);
        if (seedText) {
            searchFieldItem.insert(searchFieldItem.cursorPosition, seedText);
        }
    }

    // Clicking anywhere no control claimed drops the focus back on the page,
    // which closes the search box's caret exactly like clicking the empty part
    // of the Start menu does in Windows.
    function releaseSearchFocus(): void {
        if (!searchFieldItem.activeFocus && !searchFieldItem.focus) {
            return;
        }
        // forceActiveFocus() alone can be swallowed when the page is not a
        // focus scope: clear the field's own focus flag as well, then give the
        // page keyboard focus so the underline/hover animation really unwinds.
        searchFieldItem.focus = false;
        root.focus = true;
        root.forceActiveFocus(Qt.MouseFocusReason);
    }

    function stepSearchResult(delta): void {
        const page = root.searchPage;
        if (!page || page.count === 0) {
            return;
        }
        page.currentIndex = Math.max(0, Math.min(page.count - 1, page.currentIndex + delta));
    }

    function launchFirstResult(): void {
        if (!root.searchPage) {
            return;
        }
        // The runner answers asynchronously: a Return typed at speed lands
        // before "firefox" has any results, and launching whatever the list
        // still holds would start the wrong app. Wait for the query instead —
        // this has to be checked before the empty-list guard below, because
        // while the runner is busy the previous results are already gone.
        if (kickoff.runnerModel.querying) {
            root.pendingLaunch = true;
            launchFallbackTimer.restart();
            return;
        }
        root.pendingLaunch = false;
        launchFallbackTimer.stop();
        const page = root.searchPage;
        if (!page || page.count === 0) {
            return;
        }
        const item = page.currentItem;
        if (!item || !item.action) {
            return;
        }
        item.action.trigger();
        if (kickoff.hideOnWindowDeactivate) {
            kickoff.expanded = false;
        }
    }

    Timer {
        id: launchFallbackTimer
        interval: 1500
        // Never leave a Return hanging if a backend keeps reporting "querying".
        onTriggered: {
            if (!root.pendingLaunch) {
                return;
            }
            root.pendingLaunch = false;
            root.launchFirstResult();
        }
    }

    Connections {
        target: kickoff.runnerModel
        function onQueryFinished(): void {
            if (!root.pendingLaunch) {
                return;
            }
            // One turn for the result model to reach the view.
            Qt.callLater(() => {
                root.pendingLaunch = false;
                root.launchFirstResult();
            });
        }
    }

    // Any tap that no child control consumed is a click on the empty menu.
    // A handler on the page itself (instead of a MouseArea painted behind it)
    // actually receives those taps: a z:-1 sibling is covered by the content
    // item and never saw them, which left the search field's focus accent
    // stuck on after clicking elsewhere.
    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.releaseSearchFocus()
    }

    // The whole surface zooms away behind the A–Z sheet: everything inside
    // the card shrinks to 0.8 and fades out before the letters pop in, and
    // grows back once the sheet is dismissed.
    property real contentScale: 1
    property real contentOpacity: 1

    // True from the moment the A–Z sheet starts opening until it is gone.
    // The surface is still there (only faded), so it must stop taking input
    // the instant the sheet comes up.
    property bool pickerActive: false

    // Page-switch zoom (Home / All apps / Recent / Search): the outgoing page
    // shrinks to 0.8 and fades out, the new one grows back in — the same
    // gesture the All apps grouping swap uses.
    property real pageScale: 1
    property real pageOpacity: 1
    property Component pageSwitchTarget: null

    contentItem: ColumnLayout {
        id: rootColumn
        spacing: 0
        opacity: root.contentOpacity
        enabled: !root.pickerActive
        transform: Scale {
            origin.x: rootColumn.width / 2
            origin.y: rootColumn.height / 2
            xScale: root.contentScale
            yScale: root.contentScale
        }

        // ── Top: centred search box ─────────────────────────────────────
        Item {
            Layout.fillWidth: true
            // WinUI's Start menu leaves ~12px above and below a 32px box; the
            // old 3.4u row was tuned for the 36px field it used to hold.
            Layout.preferredHeight: Math.round(u * 3.2)

            FluentSearchField {
                id: searchFieldItem
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - FluentStyle.spacingLarge * 2, Math.round(u * 22))
                placeholderText: i18nc("@info:placeholder Search applications", "Search apps, files and settings") // qmllint disable unqualified
                onTextChanged: {
                    if (root.suppressTextSwitch) {
                        return;
                    }
                    if (text.length > 0) {
                        root.showSearch();
                    } else {
                        root.showHome();
                    }
                }
                Keys.onEscapePressed: {
                    if (text.length > 0) {
                        text = "";
                    } else {
                        kickoff.expanded = false;
                    }
                }
                // Return launches whatever is highlighted — the first result
                // unless the arrow keys moved it. Down / Up walk the results
                // without leaving the field, so typing can continue.
                onAccepted: root.launchFirstResult()
                Keys.onDownPressed: root.stepSearchResult(1)
                Keys.onUpPressed: root.stepSearchResult(-1)
            }
        }

        // Full-bleed rules: negative layout margins cancel the theme's
        // content padding so the hairlines reach the card edges, matching
        // the acrylic background the negative insets pushed out above.
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: -kickoff.backgroundMetrics.leftPadding
            Layout.rightMargin: -kickoff.backgroundMetrics.rightPadding
            Layout.preferredHeight: FluentStyle.strokeWidth
            color: FluentStyle.divider
        }

        // ── Middle: Home / All apps / Search ────────────────────────────
        VerticalStackView {
            id: stackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            initialItem: homeComponent
            // Driven by pageZoomAnim instead of the stack view's slide: the
            // whole page area shrinks and fades on every page change.
            opacity: root.pageOpacity
            transform: Scale {
                origin.x: stackView.width / 2
                origin.y: stackView.height / 2
                xScale: root.pageScale
                yScale: root.pageScale
            }
            // No built-in slide/fade: pageZoomAnim owns the transition.
            replaceEnter: Transition {}
            replaceExit: Transition {}
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: -kickoff.backgroundMetrics.leftPadding
            Layout.rightMargin: -kickoff.backgroundMetrics.rightPadding
            Layout.preferredHeight: FluentStyle.strokeWidth
            color: FluentStyle.divider
        }

        // ── Bottom: user (left) + power (right) ─────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(u * 2.8)

            // Footer band: one flat, semi-transparent ink overlay — the card,
            // a shade darker, nothing more. The negative margins mirror the
            // rules above so the band reaches every card edge, and the bottom
            // ones also swallow the page's padding ring: stopping at the
            // content edge left a pale acrylic strip that made the band look
            // like it floated a few pixels above the bottom of the card.
            Rectangle {
                id: footerBand
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: -kickoff.backgroundMetrics.leftPadding
                anchors.rightMargin: -kickoff.backgroundMetrics.rightPadding
                anchors.bottomMargin: -kickoff.backgroundMetrics.bottomPadding
                // Same radius the fake-acrylic card is drawn with, so the
                // corners follow the card instead of poking past it.
                readonly property int cardRadius: (Plasmoid.configuration?.acrylicFollowsTheme ?? true)
                    ? Kirigami.Units.cornerRadius
                    : (Plasmoid.configuration?.acrylicRadius ?? 12)
                bottomLeftRadius: footerBand.cardRadius
                bottomRightRadius: footerBand.cardRadius
                antialiasing: true
                // A white wash, not an ink one: the bar should read as the
                // brightest part of the card. Layering black over the frosted
                // background turned it grey, which is what it looked like.
                color: FluentStyle.dark
                    ? Qt.rgba(1, 1, 1, 0.05)
                    : Qt.rgba(1, 1, 1, 0.38)
            }

            // The whole user block is one button: a real face avatar on the
            // left plus the name, matching the classic Header. Clicking
            // either opens the same KCM. The avatar icon URL briefly flips to
            // empty on change, so caching is disabled exactly as in Header.
            PC3.ToolButton {
                id: userButton
                anchors.left: parent.left
                anchors.leftMargin: FluentStyle.spacingLarge
                anchors.verticalCenter: parent.verticalCenter
                // Width follows the avatar + name only — no hover mask, and
                // the click target stops at the text instead of stretching
                // across to the power buttons.
                width: implicitWidth
                height: Math.round(root.u * 2)
                enabled: openUserSettingsAction.enabled
                display: PC3.AbstractButton.TextBesideIcon
                text: kuser.fullName && kuser.fullName.length > 0 ? kuser.fullName : kuser.loginName
                flat: true
                background: Item {}
                contentItem: RowLayout {
                    spacing: FluentStyle.spacingSmall
                    KirigamiComponents.Avatar {
                        Layout.preferredWidth: Math.round(root.u * 1.5)
                        Layout.preferredHeight: Layout.preferredWidth
                        name: kuser.fullName
                        source: kuser.faceIconUrl
                        cache: false
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        text: userButton.text
                        elide: Text.ElideRight
                        color: FluentStyle.textPrimary
                        font: Kirigami.Theme.defaultFont
                    }
                }
                onClicked: openUserSettingsAction.trigger()
                FluentToolTip {
                    visible: parent.hovered
                    text: openUserSettingsAction.text
                }
            }

            Kirigami.Action {
                id: openUserSettingsAction
                text: i18nc("@action:button", "Open user settings") // qmllint disable unqualified
                icon.name: "user-identity"
                enabled: KConfig.KAuthorized.authorizeControlModule("kcm_users")
                onTriggered: KCM.KCMLauncher.openSystemSettings("kcm_users")
            }

            Win11PowerCluster {
                id: powerCluster
                anchors.right: parent.right
                anchors.rightMargin: FluentStyle.spacingLarge
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ── Power / session actions, Win11 style ────────────────────────────
    // Win11 keeps exactly two actions on the Start menu — Shut down and
    // Restart — and folds everything else into an overflow flyout. Kicker's
    // SystemModel stays the single source of truth, but we read its rows into
    // plain JS objects instead of filtering it with two proxy models. That
    // removes the crash where filterRowCallback receives a null QModelIndex
    // for top-level rows and index(row, 0, null) is rejected by Qt.
    component Win11PowerCluster : Item {
        id: cluster
        readonly property int buttonSize: Math.round(root.u * 1.7)
        readonly property int iconSize: Math.round(root.u * 0.9)
        readonly property int menuWidth: Math.round(root.u * 11)

        // favoriteId strings Kicker.SystemModel uses; ConfigGeneral's presets
        // use the same ones. Order matters: it is the button order on screen.
        readonly property var surfaceActionIds: ["shutdown", "reboot", "logout"]

        property var surfaceActions: []
        property var overflowActions: []
        // Milliseconds timestamp of the last time the overflow flyout closed.
        // A press on the ellipsis dismisses the flyout before the click is
        // delivered, so the click needs to know it was a dismissal.
        property double lastCloseTime: 0

        implicitWidth: buttonRow.implicitWidth
        implicitHeight: buttonSize

        Kicker.SystemModel {
            id: systemModel
            favoritesModel: kickoff.rootModel.systemFavoritesModel

            // The model fills in lazily, so rebuild whenever it changes.
            onCountChanged: cluster.rebuildActions()
            Component.onCompleted: cluster.rebuildActions()
        }

        // Leave actions ask first. Kicker's SystemModel triggers KWorkSpace
        // with the user's "confirm" preference, which is off on plenty of
        // setups — so a single click on Shut down powered the machine down.
        // The classic menu always shows the 30-second confirmation; asking
        // the session manager with ForcePrompt gives exactly that, while
        // suspend / hibernate / switch user / lock keep going through the
        // model unchanged.
        Sessions.SessionManagement {
            id: sessionManagement
        }

        function requestSession(favoriteId: string): bool {
            // No backend (unusual init systems): fall back to Kicker's own
            // trigger rather than swallowing the click.
            if (sessionManagement.state === Sessions.SessionManagement.Error) {
                return false;
            }
            switch (favoriteId) {
            case "shutdown":
                sessionManagement.requestShutdown(Sessions.SessionManagement.ForcePrompt);
                return true;
            case "reboot":
                sessionManagement.requestReboot(Sessions.SessionManagement.ForcePrompt);
                return true;
            case "logout":
                sessionManagement.requestLogout(Sessions.SessionManagement.ForcePrompt);
                return true;
            default:
                return false;
            }
        }

        function rebuildActions(): void {
            const favoriteIdRole = systemModel.KItemModels.KRoleNames.role("favoriteId");
            const surface = [];
            const overflow = [];
            for (let row = 0; row < systemModel.count; ++row) {
                // Two-argument index(): SystemModel is a flat list and the
                // three-argument overload cannot take a null parent from JS.
                const modelIndex = systemModel.index(row, 0);
                const favoriteId = String(systemModel.data(modelIndex, favoriteIdRole) ?? "");
                if (favoriteId.length === 0) {
                    continue;
                }
                const action = {
                    row: row,
                    favoriteId: favoriteId,
                    label: String(systemModel.data(modelIndex, Qt.DisplayRole) ?? ""),
                    decoration: systemModel.data(modelIndex, Qt.DecorationRole)
                };
                if (cluster.surfaceActionIds.indexOf(favoriteId) >= 0) {
                    surface.push(action);
                } else {
                    overflow.push(action);
                }
            }
            surface.sort((a, b) => cluster.surfaceActionIds.indexOf(a.favoriteId) - cluster.surfaceActionIds.indexOf(b.favoriteId));
            cluster.surfaceActions = surface;
            cluster.overflowActions = overflow;
        }

        function trigger(action): void {
            if (!cluster.requestSession(action.favoriteId)) {
                systemModel.trigger(action.row, "", null);
            }
            if (kickoff.hideOnWindowDeactivate) {
                kickoff.expanded = false;
            }
        }

        RowLayout {
            id: buttonRow
            anchors.fill: parent
            spacing: 0

            Repeater {
                model: cluster.surfaceActions
                delegate: PC3.ToolButton {
                    id: powerButton
                    required property var modelData
                    Layout.preferredWidth: cluster.buttonSize
                    Layout.preferredHeight: cluster.buttonSize
                    display: PC3.AbstractButton.IconOnly
                    flat: true
                    // decoration is a QString on some models and a QIcon on
                    // others; Kirigami.Icon accepts both without the
                    // QIcon→QString and icon.width/height binding loop.
                    contentItem: Kirigami.Icon {
                        source: powerButton.modelData.decoration
                        width: cluster.iconSize
                        height: cluster.iconSize
                        anchors.centerIn: parent
                        animated: false
                        selected: false
                    }
                    background: FluentHighlight {
                        hovered: powerButton.hovered
                        pressed: powerButton.down
                        radius: width / 2
                        flatStates: true
                    }
                    onClicked: cluster.trigger(powerButton.modelData)
                    FluentToolTip {
                        visible: parent.hovered
                        text: powerButton.modelData.label
                    }
                }
            }

            PC3.ToolButton {
                id: overflowButton
                visible: cluster.overflowActions.length > 0
                Layout.preferredWidth: cluster.buttonSize
                Layout.preferredHeight: cluster.buttonSize
                display: PC3.AbstractButton.IconOnly
                flat: true
                contentItem: Kirigami.Icon {
                    source: "view-more-symbolic"
                    width: cluster.iconSize
                    height: cluster.iconSize
                    anchors.centerIn: parent
                    animated: false
                    selected: false
                }
                background: FluentHighlight {
                    hovered: overflowButton.hovered
                    pressed: overflowButton.down
                    selected: powerMenu.opened
                    radius: width / 2
                    flatStates: true
                }
                // Toggle without replaying the entrance animation. The flyout
                // closes on press-outside, and the press that lands on this
                // button counts as outside — so by the time onClicked runs the
                // menu is already closed and a naive open() played the spring
                // a second time. Remember when the flyout closed and treat any
                // click that lands immediately after as the dismissal it
                // already was.
                onPressedChanged: {
                    if (overflowButton.pressed && powerMenu.opened) {
                        powerMenu.close();
                    }
                }
                onClicked: {
                    if (powerMenu.opened) {
                        powerMenu.close();
                        return;
                    }
                    if (Date.now() - cluster.lastCloseTime < 300) {
                        return;
                    }
                    powerMenu.open();
                }
                FluentToolTip {
                    visible: parent.hovered
                    text: i18nc("@info:tooltip", "More power options") // qmllint disable unqualified
                }
            }
        }

        // A Fluent flyout instead of the Plasma platform menu: rounded card,
        // hairline edge and the same translucent state layer everywhere else.
        // It sits above the footer and opens upward from the ellipsis button.
        T.Popup {
            id: powerMenu
            z: 10
            width: cluster.menuWidth
            height: powerMenuContent.implicitHeight + 2 * FluentStyle.spacingXSmall
            // WinUI flyouts keep a 4px gutter between the card edge and the
            // first / last row, which is what the rounded wash insets into.
            padding: FluentStyle.spacingXSmall
            modal: false
            // Recorded on the tick `opened` drops, which is the press that
            // dismissed it — before the button's click handler runs.
            onOpenedChanged: {
                if (!powerMenu.opened) {
                    cluster.lastCloseTime = Date.now();
                }
            }
            focus: true
            closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside
            // Live inside the card, not in the window overlay. The overlay
            // belongs to the applet dialog window, whose origin is offset from
            // the card's content area, so mapping the button into it put the
            // flyout in the wrong corner.
            //
            // The parent is the page itself, not its `contentItem`: that
            // content item is a ColumnLayout, and a Layout lays out every
            // child item it finds — the flyout's own content item included —
            // so on the next relayout the flyout was re-flowed into the
            // column. The page is a plain Control, so the position assigned
            // here stays put.
            parent: root
            // Gap between the ellipsis's top edge and the flyout's bottom edge.
            // WinUI's is 4px, but that leaves the flyout sitting right on the
            // footer; opening it a little higher keeps it clear of the power
            // buttons while still reading as anchored to the ellipsis.
            readonly property int cornerGutter: FluentStyle.spacingMedium

            // Offset of the ellipsis's top-left corner inside the page,
            // accumulated by hand instead of with mapToItem(). The loop reads
            // the x / y of every item on the way, which is what makes the
            // bindings below depend on the footer's layout: mapToItem() does
            // the same walk in C++ and files no dependency at all, so a
            // mapping on its own is evaluated once and then cached — the
            // flyout then keeps the position it had when the card was a
            // different height, which is exactly the drift after a resize.
            function cornerOffset(horizontal) {
                let offset = 0;
                let node = overflowButton;
                while (node && node !== parent) {
                    offset += horizontal ? node.x : node.y;
                    node = node.parent;
                }
                return offset;
            }

            x: {
                if (!parent) {
                    return 0;
                }
                const cardWidth = parent.width;
                // Right edges line up with the ellipsis, so the flyout sits in
                // the corner instead of centring on it.
                const wanted = cornerOffset(true) + overflowButton.width - width;
                return Math.max(FluentStyle.spacingSmall,
                                Math.min(wanted, cardWidth - width - FluentStyle.spacingSmall));
            }
            y: {
                if (!parent) {
                    return 0;
                }
                const cardHeight = parent.height;
                // Measured from the bottom edge up. The footer is pinned to
                // that edge, so the gap under the ellipsis is a constant of
                // the layout, while the button's distance from the top grows
                // and shrinks with the window. Building the position from the
                // bottom therefore keeps the flyout glued to the corner at any
                // height: card bottom → gap → ellipsis → gutter → flyout.
                const gapBelowButton = Math.max(0,
                    cardHeight - (cornerOffset(false) + overflowButton.height));
                return Math.max(FluentStyle.spacingSmall,
                                cardHeight - gapBelowButton
                                - overflowButton.height - cornerGutter - height);
            }
            // The flyout grows from the ellipsis corner, so BottomRight is
            // the anchor when it opens upward (the common case).
            transformOrigin: Item.BottomRight
            // Fluent flyout entrance: a short fade plus a barely-there scale
            // from 96%. No spring, no overshoot — WinUI surfaces appear, they
            // do not bounce.
            enter: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"; from: 0; to: 1
                        duration: FluentStyle.durationNormal; easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "scale"; from: 0.96; to: 1
                        duration: FluentStyle.durationNormal; easing.type: Easing.OutCubic
                    }
                }
            }
            exit: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"; from: 1; to: 0
                        duration: FluentStyle.durationFast; easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        property: "scale"; from: 1; to: 0.98
                        duration: FluentStyle.durationFast; easing.type: Easing.InQuad
                    }
                }
            }
            background: FluentFlyoutSurface {}
            contentItem: Column {
                id: powerMenuContent
                spacing: 0
                Repeater {
                    model: cluster.overflowActions
                    delegate: FluentMenuItem {
                        required property var modelData
                        required property int index
                        // Width comes from the popup, not from the Column: a
                        // Column sizes itself to its children, so binding the
                        // children back to it would be circular.
                        width: powerMenu.availableWidth
                        text: String(modelData.label ?? "")
                        iconSource: String(modelData.decoration ?? "")
                        onClicked: {
                            powerMenu.close();
                            cluster.trigger(modelData);
                        }
                    }
                }
            }
        }
    }

    // ── Right-click action menu (self-drawn Fluent flyout) ──────────────
    // Kicker's model already carries the action list the classic delegate
    // shows (Add to Desktop, Edit Application, …). We merge in the
    // add/remove-favourite action and render everything as our own popup so
    // it matches the power flyout instead of using the platform menu.
    property var actionEntries: []
    property var actionModel: null
    property int actionRow: -1
    property Item actionAnchor: null

    function flattenActions(list) {
        const out = [];
        for (let i = 0; i < list.length; ++i) {
            const a = list[i];
            if (!a) {
                continue;
            }
            // subActions comes from a QVariantList, which is not a JS Array,
            // so test its length rather than using Array.isArray.
            if (a.subActions && a.subActions.length > 0) {
                // Submenus are flattened into a titled group so every entry
                // stays reachable without a second-level popup.
                out.push({ type: "title", text: a.text ?? "" });
                for (let j = 0; j < a.subActions.length; ++j) {
                    const sub = a.subActions[j];
                    if (sub && sub.type !== "separator") {
                        out.push(sub);
                    }
                }
            } else {
                out.push(a);
            }
        }
        return out;
    }

    function buildAppActions(list, favoriteId) {
        let merged = list ? Array.from(list) : [];
        const favActions = Tools.createFavoriteActions(
            i18n, // qmllint disable unqualified
            kickoff.rootModel.favoritesModel,
            favoriteId
        );
        if (favActions) {
            if (merged.length > 0) {
                // Same insertion rule the classic menu uses: favourite
                // actions go right after the "Add to …" entries.
                const firstAddTo = merged.findIndex((a) =>
                    a && ["addToDesktop", "addToTaskManager", "addToPanel"].includes(a.actionId));
                if (firstAddTo >= 0) {
                    merged.splice(firstAddTo, 0, ...favActions);
                } else {
                    merged.push({ type: "separator" }, ...favActions);
                }
            } else {
                merged = favActions;
            }
        }
        return root.flattenActions(merged);
    }

    function openAppMenu(model, row, favoriteId, actionList, anchor, x, y) {
        const entries = root.buildAppActions(actionList, favoriteId);
        if (!entries || entries.length === 0) {
            return;
        }
        root.actionEntries = entries;
        root.actionModel = model;
        root.actionRow = row;
        root.actionAnchor = anchor;
        appActionMenu.openAt(x, y);
    }

    T.Popup {
        id: appActionMenu
        z: 10
        width: Math.round(root.u * 12)
        height: appActionContent.implicitHeight + 2 * FluentStyle.spacingXSmall
        padding: FluentStyle.spacingXSmall
        modal: false
        focus: true
        closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside
        parent: QQC2.Overlay.overlay
        transformOrigin: Item.TopLeft

        property real localX: 0
        property real localY: 0

        function openAt(px, py) {
            localX = px;
            localY = py;
            // `opened` is read-only on Qt 6 Popup; use the imperative API.
            open();
        }

        x: {
            if (!parent || !root.actionAnchor) {
                return 0;
            }
            const p = root.actionAnchor.mapToItem(parent, localX, localY);
            const maxX = Math.max(FluentStyle.spacingLarge, parent.width - width - FluentStyle.spacingLarge);
            return Math.min(Math.max(FluentStyle.spacingLarge, p.x), maxX);
        }
        y: {
            if (!parent || !root.actionAnchor) {
                return 0;
            }
            const p = root.actionAnchor.mapToItem(parent, localX, localY);
            if (p.y + height > parent.height - FluentStyle.spacingLarge) {
                // Flip above the pointer when the menu would run off-screen.
                return Math.max(FluentStyle.spacingLarge, p.y - height);
            }
            return Math.min(p.y, Math.max(FluentStyle.spacingLarge,
                                         parent.height - height - FluentStyle.spacingLarge));
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"; from: 0; to: 1
                    duration: FluentStyle.durationNormal; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"; from: 0.96; to: 1
                    duration: FluentStyle.durationNormal; easing.type: Easing.OutCubic
                }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"; from: 1; to: 0
                    duration: FluentStyle.durationFast; easing.type: Easing.InQuad
                }
                NumberAnimation {
                    property: "scale"; from: 1; to: 0.98
                    duration: FluentStyle.durationFast; easing.type: Easing.InQuad
                }
            }
        }

        background: FluentFlyoutSurface {}

        contentItem: Column {
            id: appActionContent
            // Bind to the popup's inner width instead of implicitWidth: the
            // rows bind their width back to this, so an implicitWidth would
            // be a circular binding.
            width: appActionMenu.availableWidth
            spacing: 0
            Repeater {
                model: root.actionEntries
                delegate: Item {
                    id: actionEntry
                    required property var modelData
                    required property int index
                    readonly property bool isSeparator: modelData.type === "separator"
                    readonly property bool isTitle: modelData.type === "title"
                    readonly property bool isAction: !isSeparator && !isTitle
                    width: appActionContent.width
                    height: isSeparator
                        // A bare hairline: the rows above and below already
                        // carry their own padding, so giving the rule a slot
                        // of its own doubled the gap it was meant to divide.
                        ? FluentStyle.strokeWidth
                        : isTitle
                            ? Math.round(root.u * 1.6)
                            : actionRowItem.implicitHeight

                    Rectangle {
                        visible: actionEntry.isSeparator
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: FluentStyle.spacingLarge
                        anchors.rightMargin: FluentStyle.spacingLarge
                        anchors.verticalCenter: parent.verticalCenter
                        height: FluentStyle.strokeWidth
                        color: FluentStyle.divider
                    }

                    Text {
                        visible: actionEntry.isTitle
                        anchors.left: parent.left
                        // Lines up with the labels below it: the flyout's own
                        // 4px gutter plus the row's 12px padding.
                        anchors.leftMargin: FluentStyle.spacingLarge
                        anchors.right: parent.right
                        anchors.rightMargin: FluentStyle.spacingLarge
                        anchors.verticalCenter: parent.verticalCenter
                        text: actionEntry.modelData.text ?? ""
                        font.family: Kirigami.Theme.defaultFont.family
                        font.weight: Font.Medium
                        font.pointSize: Math.max(1, Kirigami.Theme.defaultFont.pointSize - 1)
                        color: FluentStyle.textSecondary
                        elide: Text.ElideRight
                    }

                    FluentMenuItem {
                        id: actionRowItem
                        visible: actionEntry.isAction
                        width: actionEntry.width
                        text: String(actionEntry.modelData.text ?? "")
                        iconSource: String(actionEntry.modelData.icon ?? "")
                        enabled: actionEntry.modelData.enabled ?? true
                        showCheck: actionEntry.modelData.checkable === true
                                   && actionEntry.modelData.checked === true
                        onClicked: {
                            const triggered = Tools.triggerAction(
                                root.actionModel,
                                root.actionRow,
                                actionEntry.modelData.actionId,
                                actionEntry.modelData.actionArgument
                            );
                            appActionMenu.close();
                            if (triggered && kickoff.hideOnWindowDeactivate) {
                                kickoff.expanded = false;
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Grouping swap ───────────────────────────────────────────────────
    // Called from the configuration connection above: the drawer is rebuilt
    // behind a short cross-fade so a change made in the settings dialog does
    // not make the menu's contents jump if it happens to be open.
    function setAllAppsGrouping(mode: string): void {
        if (mode === root.allAppsGrouping) {
            return;
        }
        root.pendingGrouping = mode;
        groupingSwap.stop();
        groupingSwap.start();
    }

    // Stage one: the current drawer sinks away. Stage two: swap the model
    // (nothing is visible at that instant) and grow the new one back.
    SequentialAnimation {
        id: groupingSwap
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "appsSwapScale"; to: 0.8
                duration: 150; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root; property: "appsSwapOpacity"; to: 0
                duration: 130; easing.type: Easing.OutCubic
            }
        }
        ScriptAction { script: root.allAppsGrouping = root.pendingGrouping }
        // One beat for the new drawer to build, so the fade-in never shows
        // the old rows for a frame.
        PauseAnimation { duration: 60 }
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "appsSwapScale"; to: 1
                duration: 220; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root; property: "appsSwapOpacity"; to: 1
                duration: 180; easing.type: Easing.OutCubic
            }
        }
    }


    // Page-switch shrink: sink the current page to 0.8 and fade it out, swap
    // the page while nothing is visible, then grow the new one back.
    SequentialAnimation {
        id: pageZoomAnim
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "pageScale"; to: 0.8
                duration: 150; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root; property: "pageOpacity"; to: 0
                duration: 130; easing.type: Easing.OutCubic
            }
        }
        ScriptAction {
            script: {
                if (root.pageSwitchTarget) {
                    stackView.replace(root.pageSwitchTarget);
                }
            }
        }
        PauseAnimation { duration: 40 }
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "pageScale"; to: 1
                duration: 220; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root; property: "pageOpacity"; to: 1
                duration: 180; easing.type: Easing.OutCubic
            }
        }
    }

    // ── Jump sheet (A–Z / categories) ───────────────────────────────────
    // One sheet, two data sets. Clicking any letter heading opens the
    // alphabet grid and picking a letter scrolls the Home surface to that
    // section; clicking a category heading — the same interactive row, in
    // the category drawer — opens the identical grid with the category icons
    // in place of the letters, and an icon jumps to its section.
    property string pickerMode: "alpha"

    readonly property var pickerItems: {
        if (root.pickerMode === "category") {
            const entries = root.categoryEntries;
            const categories = [];
            for (let i = 0; i < entries.length; ++i) {
                categories.push({
                    key: i,
                    label: entries[i].name,
                    icon: entries[i].icon,
                    available: true
                });
            }
            return categories;
        }
        const page = stackView.currentItem;
        const available = (page && page.letters) ? page.letters : [];
        // The alphabet is always complete: letters the current drawer has no
        // apps for stay in the grid, dimmed and inert, so its shape never
        // changes between one menu and the next.
        const letters = [];
        for (let i = 0; i < 26; ++i) {
            const letter = String.fromCharCode(65 + i);
            letters.push({ key: letter, label: letter, icon: "", available: available.indexOf(letter) >= 0 });
        }
        return letters;
    }

    // Nothing to jump to (category mode, or an empty drawer) — the sheet only
    // opens when at least one letter actually exists.
    readonly property bool pickerHasAny: {
        const page = stackView.currentItem;
        return !!(page && page.letters && page.letters.length > 0);
    }

    function openPickerSheet(mode: string): void {
        if (mode === "alpha" && !root.pickerHasAny) {
            return;
        }
        if (mode === "category" && root.categoryEntries.length === 0) {
            return;
        }
        if (letterSheet.sheetOpen) {
            return;
        }
        // The sheet's contents follow the mode, and the mode is settled
        // before the card starts to sink, so the grid never flashes the
        // previous data set on its way in.
        root.pickerMode = mode;
        root.pickerActive = true;
        sheetCloseTimer.stop();
        shrinkAway.restart();
    }

    function openLetterPicker(): void {
        root.openPickerSheet("alpha");
    }

    // Stage one: the card's contents sink to 0.8 and vanish; stage two: the
    // letter sheet pops in on top of the emptied card.
    SequentialAnimation {
        id: shrinkAway
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "contentScale"; to: 0.8
                duration: 180; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root; property: "contentOpacity"; to: 0
                duration: 160; easing.type: Easing.OutCubic
            }
        }
        onFinished: letterSheet.sheetOpen = true
    }

    ParallelAnimation {
        id: growBack
        NumberAnimation {
            target: root; property: "contentScale"; to: 1
            duration: 240; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "contentOpacity"; to: 1
            duration: 200; easing.type: Easing.OutCubic
        }
    }

    function jumpToLetter(letter): void {
        const page = stackView.currentItem;
        if (page && page.jumpToLetter) {
            page.jumpToLetter(letter);
        }
    }

    function jumpToCategory(index): void {
        const page = stackView.currentItem;
        if (page && page.jumpToCategory) {
            page.jumpToCategory(index);
        }
    }

    function closeLetterPicker(): void {
        if (!letterSheet.sheetOpen) {
            return;
        }
        letterSheet.sheetOpen = false;
        sheetCloseTimer.restart();
    }

    // Waits for the sheet's exit animation, then brings the surface back.
    Timer {
        id: sheetCloseTimer
        interval: 140
        onTriggered: {
            root.pickerActive = false;
            growBack.restart();
        }
    }

    // The A–Z sheet is drawn inside the card instead of as a window-level
    // Popup: a Popup's x/y live in the overlay's coordinate space, which is
    // not the card's (it came out ~140px off-centre), and it left the
    // invisible surface behind it clickable. As a plain item it centres with
    // anchors and can take input for the whole area.
    Item {
        id: letterSheet
        // A Control's default property is `contentData`, i.e. everything
        // declared here lands *inside* contentItem — which is a ColumnLayout,
        // where anchors are undefined behaviour and the sheet gets sized to
        // nothing (blank page). Re-parent onto the page itself: a plain item,
        // where anchors are legal and the sheet covers the whole card.
        parent: root
        anchors.fill: parent
        z: 100
        visible: opacity > 0
        opacity: sheetOpen ? 1 : 0
        property bool sheetOpen: false
        // Takes focus while open so Escape dismisses it, like a popup.
        focus: sheetOpen
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Keys.onEscapePressed: root.closeLetterPicker()

        // Clicking anywhere outside the card dismisses the sheet.
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeLetterPicker()
        }

        Item {
            id: sheetCard
            anchors.centerIn: parent
            width: letterSheetGrid.implicitWidth + FluentStyle.spacingMedium * 2
            height: letterSheetGrid.implicitHeight + FluentStyle.spacingMedium * 2
            scale: letterSheet.sheetOpen ? 1 : 0.85
            opacity: letterSheet.sheetOpen ? 1 : 0
            Behavior on scale {
                NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
            }
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            // No surface behind the chips: the card itself is the backdrop,
            // so the sheet is just the grid floating over it.
            Grid {
                id: letterSheetGrid
                anchors.centerIn: parent
                columns: 4
                spacing: FluentStyle.spacingSmall
                Repeater {
                    model: root.pickerItems
                    delegate: T.ItemDelegate {
                        id: letterChip
                        required property var modelData
                        // Entries the current drawer cannot reach are drawn but
                        // inert: the grid keeps the same shape, a dead entry is
                        // dimmed instead of being removed.
                        readonly property bool available: !!(letterChip.modelData && letterChip.modelData.available)
                        readonly property string label: letterChip.modelData ? String(letterChip.modelData.label ?? "") : ""
                        readonly property var glyph: letterChip.modelData ? letterChip.modelData.icon : ""
                        readonly property bool hasIcon: letterChip.glyph !== "" && letterChip.glyph !== null
                            && letterChip.glyph !== undefined

                        width: Math.round(root.u * 3.6)
                        height: Math.round(root.u * 2.9)
                        enabled: letterChip.available
                        hoverEnabled: true
                        // Same mask as a tile / letter row, not a separate
                        // state-layer wash: the sheet has no surface of its
                        // own, so the hover feedback has to come from the one
                        // shared recipe.
                        background: Item {
                            TaskHoverMask {
                                anchors.fill: parent
                                hovered: letterChip.available && (letterChip.hovered || letterChip.down)
                                radius: FluentStyle.radiusControl
                            }
                        }
                        // Category mode swaps each letter for the category's own
                        // icon; the layout, chip size and hover feedback stay
                        // identical so the two sheets are the same object.
                        contentItem: Item {
                            Text {
                                anchors.centerIn: parent
                                visible: !letterChip.hasIcon
                                text: letterChip.label
                                font.family: Kirigami.Theme.defaultFont.family
                                font.weight: Font.Medium
                                // Two steps up from body text: with no panel
                                // behind them the letters have to carry the
                                // sheet alone.
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                                color: letterChip.available
                                    ? FluentStyle.textPrimary
                                    : FluentStyle.withAlpha(FluentStyle.textPrimary, 0.32)
                                Behavior on color {
                                    ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
                                }
                            }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                visible: letterChip.hasIcon
                                width: Math.round(root.u * 1.6)
                                height: width
                                source: letterChip.hasIcon ? letterChip.glyph : ""
                                color: FluentStyle.textPrimary
                                opacity: letterChip.available ? 1 : 0.32
                                animated: false
                                selected: false
                            }
                        }
                        // An icon alone cannot say which category it is, so its
                        // name rides along as a tooltip instead of a caption
                        // that would break the shared grid rhythm.
                        FluentToolTip {
                            parent: letterChip
                            visible: letterChip.hasIcon && letterChip.hovered && letterChip.available
                            text: letterChip.label
                        }
                        onClicked: {
                            if (!letterChip.available) {
                                return;
                            }
                            if (root.pickerMode === "category") {
                                root.jumpToCategory(letterChip.modelData.key);
                            } else {
                                root.jumpToLetter(letterChip.label);
                            }
                            root.closeLetterPicker();
                        }
                    }
                }
            }
        }
    }


    // ── Category caption ────────────────────────────────────────────────
    // Section heading of the category drawer: the freedesktop category icon
    // plus its translated name, at the same vertical rhythm as a letter
    // heading so switching grouping does not shift the drawer's beat.
    component CategoryHeader : Item {
        id: categoryHeader
        property string title: ""
        property var icon: ""
        property int topSpace: 0
        signal clicked()

        readonly property int iconSize: Math.round(root.u * 0.95)
        readonly property bool hasIcon: categoryHeader.icon !== "" && categoryHeader.icon !== null
            && categoryHeader.icon !== undefined
        readonly property int textX: hasIcon
            ? FluentStyle.spacingMedium + iconSize + FluentStyle.spacingSmall
            : FluentStyle.spacingMedium

        width: parent ? parent.width : 0
        implicitHeight: Math.round(root.u * 1.9) + topSpace
        height: implicitHeight

        // Same interactive heading as a letter row: full width, shared hover
        // mask, hand cursor — clicking it opens the jump sheet, which in this
        // mode lists the categories instead of the alphabet.
        TaskHoverMask {
            anchors.fill: parent
            anchors.topMargin: categoryHeader.topSpace + 2
            anchors.bottomMargin: 2
            hovered: categoryMouse.containsMouse
            radius: FluentStyle.radiusControl
        }

        Kirigami.Icon {
            x: FluentStyle.spacingMedium
            y: categoryHeader.topSpace + Math.round((categoryHeader.height - categoryHeader.topSpace - height) / 2)
            width: categoryHeader.iconSize
            height: categoryHeader.iconSize
            source: categoryHeader.icon
            visible: categoryHeader.hasIcon
            animated: false
            selected: false
        }

        Text {
            x: categoryHeader.textX
            y: categoryHeader.topSpace + Math.round((categoryHeader.height - categoryHeader.topSpace - height) / 2)
            text: categoryHeader.title
            font.family: Kirigami.Theme.defaultFont.family
            font.weight: Font.Bold
            font.pointSize: Math.max(1, Kirigami.Theme.defaultFont.pointSize - 1)
            color: FluentStyle.textPrimary
        }

        MouseArea {
            id: categoryMouse
            anchors.fill: parent
            // Leave the air above the caption out of the hit area: that gap
            // belongs to the previous section, not to this heading.
            anchors.topMargin: categoryHeader.topSpace
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: categoryHeader.clicked()
        }
    }

    // ── Shared section heading ──────────────────────────────────────────
    component SectionHeader : Item {
        id: header
        property string title: ""
        property string actionText: ""
        // Icon-only action (an overflow "…" rather than a labelled button).
        // Ignored when actionText is set.
        property string actionIcon: ""
        // When true the caption hugs the top edge instead of being centred.
        // Used for the "All apps" header so its line sits right under the
        // rule above it with no padding in between.
        property bool alignTop: false
        // Additional air above the caption, on top of its own height. The
        // "All apps" heading uses it to stand off the rule it follows.
        property int topSpace: 0
        // Outer margin: the caption is inset from the drawer edge instead of
        // being flush with the tiles below it.
        property int hMargin: FluentStyle.spacingMedium
        signal actionTriggered()
        readonly property bool hasAction: actionText.length > 0 || actionIcon.length > 0
        readonly property bool iconOnlyAction: actionText.length === 0

        implicitHeight: Math.round(u * 1.9) + topSpace
        width: parent ? parent.width : 0

        PC3.Label {
            id: titleLabel
            x: header.hMargin
            y: header.alignTop ? header.topSpace : Math.round((header.height - height) / 2)
            text: header.title
            color: FluentStyle.textPrimary
            font.bold: true
            font.pixelSize: Math.round(FluentStyle.spacingLarge * 0.92)
        }

        // Labelled action ("See all" style), used when actionText is set.
        PC3.ToolButton {
            id: actionButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: header.hasAction && !header.iconOnlyAction
            text: header.actionText
            icon.name: "go-next"
            display: PC3.AbstractButton.TextBesideIcon
            flat: true
            background: FluentHighlight {
                hovered: actionButton.hovered
                pressed: actionButton.down
                radius: FluentStyle.radiusControl
                flatStates: true
            }
            onClicked: header.actionTriggered()
        }

        // Icon-only action (an overflow "…" rather than a word). Square, the
        // height of the caption, so the header line keeps its rhythm.
        PC3.ToolButton {
            id: iconActionButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: header.hasAction && header.iconOnlyAction
            display: PC3.AbstractButton.IconOnly
            implicitWidth: Math.round(u * 1.7)
            implicitHeight: Math.round(u * 1.7)
            icon.name: header.actionIcon
            icon.width: Math.round(u * 0.9)
            icon.height: Math.round(u * 0.9)
            flat: true
            background: FluentHighlight {
                hovered: iconActionButton.hovered
                pressed: iconActionButton.down
                radius: FluentStyle.radiusControl
                flatStates: true
            }
            onClicked: header.actionTriggered()
        }
    }

    // ── Shared hover mask ───────────────────────────────────────────────
    // The recipe from taskmanager's hoverHighlightBg: a flat white or black
    // fill driven by the shared highlightColor setting (0=White, 1=Black,
    // 2=Automatic), plus its small soft shadow. Every Win11 row uses this so
    // the launcher and the taskbar match.
    //
    // Dark schemes are the exception: the taskbar recipe paints that mask with
    // a *black* fill at 85%, which works over a wallpaper but over the menu's
    // own dark card it read as a black block glued to the row. Dark therefore
    // ignores the fill choice and uses a faint white lift instead — the same
    // 10-12% state layer WinUI uses on a dark surface.
    component TaskHoverMask : Rectangle {
        id: mask
        property bool hovered: false
        z: -1
        radius: FluentStyle.radiusOverlay

        readonly property int highlightChoice: Plasmoid.configuration?.highlightColor ?? 2
        readonly property bool usesWhite: Tools.highlightUsesWhite(mask.highlightChoice, FluentStyle.dark)
        readonly property real hoverOpacity: Tools.highlightAlpha(mask.highlightChoice, FluentStyle.dark, false)
        color: FluentStyle.dark
            ? Qt.rgba(1, 1, 1, 0.12)
            : (mask.usesWhite ? Qt.rgba(1, 1, 1, mask.hoverOpacity) : Qt.rgba(0, 0, 0, mask.hoverOpacity))

        // A real, visible fade in both directions instead of an instant
        // switch: WinUI brings its state layer in slightly slower than it
        // takes it away, so the row you are leaving does not blink out.
        opacity: mask.hovered ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: mask.hovered ? 200 : 150
                easing.type: Easing.OutCubic
            }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            // Was 0.15: at that strength the shadow turned into a grey halo
            // around a fill that is itself a thin wash. 0.10 still lifts the
            // mask off the acrylic without darkening its edge.
            shadowOpacity: 0.10
            shadowBlur: 0.15
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }
    }

    // ── Letter heading (a jump target, not just a label) ────────────────
    // One row shared by both All apps layouts: full drawer width so the hover
    // mask spans it edge to edge, the same taskbar-style mask a tile uses,
    // and a click that opens the A–Z picker.
    component LetterHeader : Item {
        id: letterRow
        property string letter: ""
        signal clicked()

        width: parent ? parent.width : 0
        implicitHeight: Math.round(root.u * 1.8)
        height: implicitHeight

        TaskHoverMask {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            hovered: letterMouse.containsMouse
            radius: FluentStyle.radiusControl
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: FluentStyle.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            text: letterRow.letter
            font.family: Kirigami.Theme.defaultFont.family
            font.weight: Font.Bold
            font.pointSize: Math.max(1, Kirigami.Theme.defaultFont.pointSize - 1)
            color: FluentStyle.textPrimary
        }

        MouseArea {
            id: letterMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: letterRow.clicked()
        }
    }

    // ── Menu row (Fluent / WinUI MenuFlyoutItem) ────────────────────────
    // A 32px row with 12px side padding, a 16px glyph 12px before the label,
    // and a 4px-rounded state layer inset 4px from the flyout edge. There is
    // no per-row card and no bounce: the whole interaction is one translucent
    // wash that fades in over ~100ms, which is what makes a WinUI menu read as
    // a quiet list instead of a stack of buttons.
    component FluentMenuItem : T.ItemDelegate {
        id: menuRow
        // `text` comes from AbstractButton (it is FINAL there, so it must not
        // be redeclared); the row simply uses it as the label.
        property string iconSource: ""
        property bool showCheck: false

        // WinUI's control height, but never shorter than the text needs — a
        // larger system font must not clip the row.
        readonly property int rowHeight: Math.max(FluentStyle.controlHeight,
            Math.round(root.u * 1.75))
        readonly property int iconSize: Math.round(root.u * 0.9)
        readonly property int sidePadding: FluentStyle.spacingMedium
        readonly property int iconGap: FluentStyle.spacingMedium

        width: parent ? parent.width : 0
        implicitHeight: rowHeight
        height: implicitHeight
        leftPadding: menuRow.sidePadding
        rightPadding: menuRow.sidePadding
        // The 32px height already leaves the air the row needs, so the label
        // is simply centred instead of being pushed down by padding.
        topPadding: 0
        bottomPadding: 0
        hoverEnabled: true

        background: Item {
            Rectangle {
                // Inset from the flyout edge: WinUI's wash is a rounded chip
                // floating inside the menu, never a full-bleed band.
                anchors.fill: parent
                anchors.leftMargin: FluentStyle.spacingXSmall
                anchors.rightMargin: FluentStyle.spacingXSmall
                radius: FluentStyle.radiusControl
                color: FluentStyle.stateColor(menuRow.down
                    ? FluentStyle.alphaPressed
                    : (menuRow.hovered ? FluentStyle.alphaHover : 0))
                Behavior on color {
                    ColorAnimation {
                        duration: FluentStyle.durationFast
                        easing.type: FluentStyle.easingSoft
                    }
                }
            }
        }

        contentItem: RowLayout {
            spacing: menuRow.iconGap
            // Fixed cell so every label starts on the same column even when an
            // action has no icon of its own.
            Item {
                Layout.preferredWidth: menuRow.iconSize
                Layout.preferredHeight: menuRow.iconSize
                Kirigami.Icon {
                    visible: menuRow.iconSource.length > 0
                    anchors.fill: parent
                    source: menuRow.iconSource
                    color: FluentStyle.textPrimary
                    opacity: menuRow.enabled ? 1 : 0.4
                    animated: false
                    selected: false
                }
            }
            Text {
                Layout.fillWidth: true
                text: menuRow.text
                font.family: Kirigami.Theme.defaultFont.family
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                font.weight: Font.Medium
                color: FluentStyle.textPrimary
                opacity: menuRow.enabled ? 1 : 0.4
                elide: Text.ElideRight
            }
            Kirigami.Icon {
                visible: menuRow.showCheck
                source: "checkmark-symbolic"
                Layout.preferredWidth: menuRow.iconSize
                Layout.preferredHeight: menuRow.iconSize
                color: FluentStyle.accent
                animated: false
                selected: false
            }
        }
    }

    // ── Flyout surface ──────────────────────────────────────────────────
    // WinUI's menu flyout card: 8px corners, an "acrylic in app" fill one
    // step above the surface it opens over, a hairline edge, and a soft
    // shadow. No accent bar and no outline offset.
    component FluentFlyoutSurface : Rectangle {
        radius: FluentStyle.radiusOverlay
        color: FluentStyle.flyoutFill
        border.width: FluentStyle.strokeWidth
        border.color: FluentStyle.flyoutStroke
        antialiasing: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            // Softer than it started: 0.5/0.24 pooled into a black skirt along
            // the bottom edge that was heavier than the hairline it was meant
            // to support. The fill is opaque now, so less shadow is needed to
            // separate the menu from the card.
            shadowOpacity: FluentStyle.dark ? 0.36 : 0.16
            shadowBlur: 0.5
            shadowVerticalOffset: 3
            shadowHorizontalOffset: 0
        }
    }

    // Shared wheel handling for every Win11 scroll surface. The classic views
    // already use Kirigami.WheelHandler with this step size; the Win11 pages
    // only had Flickable's built-in wheel flicking plus a /2 step on the tiny
    // scrollbar, which made the wheel feel far slower than the rest of Plasma.
    component FastWheelHandler : Kirigami.WheelHandler {
        filterMouseEvents: true
        // Same default speed the classic Kickoff views use.
        horizontalStepSize: 20 * Qt.styleHints.wheelScrollLines
        verticalStepSize: 20 * Qt.styleHints.wheelScrollLines
    }

    // ── Minimal overlay scrollbar ───────────────────────────────────────
    // Win11 does not use a Plasma scrollbar here: no track, no arrows, no
    // frame — just a short rounded thumb that sits faintly on the edge and
    // strengthens while the content moves or the pointer is near it. It stays
    // 4px wide so it reads as a hint rather than a control, and it is
    // draggable for mouse users.
    component SmallScrollBar : Item {
        id: bar
        property Flickable flickable: null
        property int thickness: 4

        readonly property real maxOffset: bar.flickable
            ? Math.max(0, bar.flickable.contentHeight - bar.flickable.height)
            : 0
        readonly property bool needed: bar.maxOffset > 0.5
        // A fixed, deliberately short thumb: Win11's Start menu uses a stub
        // that only signals "there is more below", not a proportional
        // elevator that grows with the content.
        readonly property int thumbLength: Math.round(root.u * 1.4)
        // Pressing the bar itself stretches the stub: a press no longer jumps
        // the view, so the pointer feedback has to come from the bar. Both
        // the height *and* the position come from this one animated value —
        // animating the height while `y` read the target height made the stub
        // visibly extend downwards only. With `y` derived from the animated
        // height, the centre stays put and the stub grows both ways.
        property real grow: thumbArea.pressed ? 1 : 0
        Behavior on grow {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        readonly property real thumbStretch: 1 + 0.2 * bar.grow
        readonly property real thumbBaseHeight: Math.min(bar.thumbLength, bar.height)
        readonly property real thumbHeight: bar.thumbBaseHeight * bar.thumbStretch
        readonly property real scrollProgress: bar.maxOffset > 0
            ? Math.max(0, Math.min(1, bar.flickable.contentY / bar.maxOffset))
            : 0

        width: bar.thickness
        implicitWidth: bar.thickness
        visible: bar.needed

        // A hairline presence at rest — Win11 keeps its bar faintly visible so
        // you can tell the list continues — that firms up on hover or while
        // the content is moving.
        readonly property real emphasis: ((bar.flickable && bar.flickable.movingVertically)
            || thumbArea.containsMouse || thumbArea.pressed) ? 1.0 : 0.55

        Rectangle {
            id: thumb
            width: bar.width
            height: bar.thumbHeight
            // Centre of the stub on the track, then the grown height is hung
            // around that centre: both ends travel outwards by the same
            // amount, whether the stub sits at the top, in the middle or at
            // the bottom. Deliberately unclamped — the bar keeps a small
            // margin above and below, which is wider than the 10% overhang,
            // so the growth never reaches the rules.
            y: bar.scrollProgress * (bar.height - bar.thumbBaseHeight)
                + bar.thumbBaseHeight / 2 - thumb.height / 2
            radius: width / 2
            // Deeper on press, a touch lighter on hover, faint at rest.
            color: thumbArea.pressed
                ? (FluentStyle.dark ? Qt.rgba(1, 1, 1, 0.62) : Qt.rgba(0, 0, 0, 0.55))
                : (FluentStyle.dark ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(0, 0, 0, 0.34))
            opacity: bar.emphasis
            Behavior on color {
                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: thumbArea
            // Wider than the 4px thumb so the bar is actually grabbable: the
            // extra 6px stays inside the Flickable's right padding and never
            // steals clicks from a tile.
            anchors.fill: parent
            anchors.leftMargin: -6
            hoverEnabled: true
            enabled: bar.visible

            // A press only "grabs" the bar — it does not jump the view.
            // Scrolling starts once the pointer actually travels, and then
            // moves the content by the same distance the pointer covers.
            property real pressY: 0
            property real pressContentY: 0
            property bool dragging: false

            function beginDrag(pointerY: real): void {
                pressY = pointerY;
                pressContentY = bar.flickable ? bar.flickable.contentY : 0;
                dragging = false;
            }

            function updateDrag(pointerY: real): void {
                if (!bar.flickable) {
                    return;
                }
                if (!dragging) {
                    if (Math.abs(pointerY - pressY) < 3) {
                        return;
                    }
                    dragging = true;
                }
                const track = Math.max(1, bar.height - bar.thumbHeight);
                const delta = (pointerY - pressY) * (bar.maxOffset / track);
                bar.flickable.contentY = Math.max(0, Math.min(bar.maxOffset,
                    pressContentY + delta));
            }

            onPressed: (mouse) => thumbArea.beginDrag(mouse.y)
            onPositionChanged: (mouse) => {
                if (thumbArea.pressed) {
                    thumbArea.updateDrag(mouse.y);
                }
            }
            onReleased: thumbArea.dragging = false
            onCanceled: thumbArea.dragging = false
        }

        // Wheel over the thin bar uses the same step size as the surface, so
        // speed no longer changes depending on which part of the menu is under
        // the pointer.
        FastWheelHandler {
            target: bar.flickable
        }
    }

    // ── Pinned app tile ─────────────────────────────────────────────────
    // Kicker exposes three name flavours: `display` is formatted according to
    // appNameFormat and may be "Name (Comment)", `compactName` is the bare
    // application name, and `description` is the comment/generic name. Pinned
    // tiles show only the bare name (wrapped, never elided); the description
    // lives in the tooltip so it never crowds the tile.
    component AppTile : Item {
        id: tile
        required property int index
        required property var model
        // The Pinned grid measures each tile from its wrapped name; the All
        // apps card grid keeps supplying a fixed height through `view`.
        property var view: null
        property real cellWidth: root.tileWidth
        // All apps cards size to their caption instead of a fixed cell, so a
        // short name gets a narrow card and a long one wider. Pinned keeps
        // the fixed grid cell so its columns stay aligned.
        property bool dynamicWidth: false
        // When tiles are rebuilt into letter groups, the delegate index is a
        // position inside the group, not the model row — carry the real row.
        property int triggerRow: -1

        readonly property string appName: {
            const raw = String(tile.model?.compactName ?? tile.model?.display ?? "");
            return raw.replace(/\s*\([^()]*\)\s*$/, "");
        }
        readonly property string appDescription: String(tile.model?.description ?? "").trim()
        // `decoration` is a QString on favourites but a QIcon on the usage
        // models; Kirigami.Icon.source is a var and accepts both. Keeping it
        // out of ToolButton.icon.name avoids "QIcon to QString" and the
        // icon.height↔icon.width binding loop the icon group used to create.
        readonly property var appDecoration: tile.model?.decoration ?? ""

        // Two lines is the cap, but the card only grows as tall as the name
        // actually needs: a one-line label keeps a compact tile, a two-line
        // name gets a taller state layer so the text never crowds its edge.
        readonly property int contentSpacing: Math.round(Kirigami.Units.smallSpacing * 0.5)
        readonly property int verticalPadding: Math.round(Kirigami.Units.smallSpacing * 1.5)
        readonly property int nameMaxHeight: Math.round(root.u * 1.8)
        // Small inset shared by the icon and the caption. Both are left
        // aligned, so the text width has to reserve it on both sides or the
        // measured line count would not match what is drawn.
        readonly property int leftInset: FluentStyle.spacingSmall
        // Dynamic mode: one-line caption, width follows the text (never
        // narrower than the icon). Fixed mode: the caption wraps inside the
        // cell and the card grows taller instead.
        readonly property int nameWidth: tile.dynamicWidth
            ? Math.max(root.iconSize, Math.ceil(Math.min(nameMeasure.implicitWidth,
                                                         Math.max(1, tile.cellWidth - tile.leftInset * 2))))
            : Math.max(1, Math.floor(tile.cellWidth - tile.leftInset * 2))
        readonly property int nameHeight: Math.min(Math.ceil(nameMeasure.implicitHeight), tile.nameMaxHeight)

        implicitWidth: tile.dynamicWidth
            ? Math.min(tile.nameWidth + tile.leftInset * 2, tile.cellWidth)
            : tile.cellWidth
        implicitHeight: tile.verticalPadding * 2 + root.iconSize + tile.contentSpacing + tile.nameHeight
        // Flow positions by width/height, so bind them to the implicit size
        // explicitly; without this a bare Item would report 0 and overlap.
        width: implicitWidth
        height: implicitHeight

        // Hidden twin of the visible label: measures how many lines the name
        // wraps to at this tile width so the card grows with its content.
        Text {
            id: nameMeasure
            visible: false
            // Dynamic mode measures the unwrapped single line: with NoWrap
            // implicitWidth is the natural text width and does not depend on
            // `width`, so a large value here does not loop into nameWidth.
            width: tile.dynamicWidth ? 10000 : tile.nameWidth
            text: tile.appName
            // Match the visible caption exactly, otherwise the line count —
            // and therefore the elastic tile height — would be measured with
            // a wider face than the one actually drawn.
            font.family: Kirigami.Theme.defaultFont.family
            font.weight: Font.Light
            font.pointSize: Math.max(1, Kirigami.Theme.defaultFont.pointSize - 1)
            wrapMode: tile.dynamicWidth ? Text.NoWrap : Text.Wrap
            elide: Text.ElideNone
            maximumLineCount: tile.dynamicWidth ? 1 : 2
        }

        // Fully self-drawn: a bare ItemDelegate with no themed background, a
        // translucent rounded highlight with a soft shadow on hover (the same
        // recipe the task buttons use), and a shrink animation on press. A
        // press never paints a colour layer — only the scale responds.
        T.ItemDelegate {
            id: button
            anchors.fill: parent
            hoverEnabled: true
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            background: Item {}
            scale: button.down ? 0.94 : 1
            Behavior on scale {
                NumberAnimation { duration: FluentStyle.durationFast; easing.type: FluentStyle.easingSoft }
            }

            // Same flat white/black mask as the taskbar, including its small
            // soft shadow. Colour follows the shared highlightColor setting.
            TaskHoverMask {
                anchors.fill: parent
                hovered: button.hovered
            }

            contentItem: Item {
                // The block (icon + caption) is anchored to the left of the
                // cell, while the icon and the text are centred relative to
                // each other: centred content, left-aligned overall.
                Column {
                    id: contentBlock
                    x: tile.leftInset
                    y: tile.verticalPadding
                    width: tile.nameWidth
                    spacing: tile.contentSpacing

                    Kirigami.Icon {
                        x: Math.round((contentBlock.width - width) / 2)
                        width: root.iconSize
                        height: root.iconSize
                        source: tile.appDecoration
                        animated: false
                        selected: false
                    }
                    Text {
                        width: contentBlock.width
                        text: tile.appName
                        // Light face for the tile caption: finer than body
                        // text, matching the smaller secondary line.
                        font.family: Kirigami.Theme.defaultFont.family
                        font.weight: Font.Light
                        font.pointSize: Math.max(1, Kirigami.Theme.defaultFont.pointSize - 1)
                        color: FluentStyle.textPrimary
                        // Dynamic cards stay on one line and elide if the
                        // name would exceed the available width; fixed cards
                        // wrap to at most two lines.
                        wrapMode: tile.dynamicWidth ? Text.NoWrap : Text.Wrap
                        elide: tile.dynamicWidth ? Text.ElideRight : Text.ElideNone
                        maximumLineCount: tile.dynamicWidth ? 1 : 2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignTop
                    }
                }
            }
            // Right click opens the app action menu at the pointer. Only the
            // right button is accepted, so the left-click launch path and the
            // hover highlight stay untouched.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                z: 2
                onClicked: (mouse) => {
                    const m = tile.view ? tile.view.model : kickoff.rootModel.favoritesModel;
                    const rowIndex = tile.triggerRow >= 0 ? tile.triggerRow : tile.index;
                    root.openAppMenu(m, rowIndex,
                                     tile.model?.favoriteId ?? null,
                                     tile.model?.actionList ?? null,
                                     button, mouse.x, mouse.y);
                }
            }
            Accessible.name: tile.appName
            Accessible.description: tile.appDescription
            onClicked: {
                const m = tile.view ? tile.view.model : kickoff.rootModel.favoritesModel;
                const row = tile.triggerRow >= 0 ? tile.triggerRow : tile.index;
                if (m && m.trigger) {
                    if (m.trigger(row, "", null) && kickoff.hideOnWindowDeactivate) {
                        kickoff.expanded = false;
                    }
                }
            }
            FluentToolTip {
                parent: button
                y: button.height + Math.round(Kirigami.Units.smallSpacing)
                visible: button.hovered && tile.appName.length > 0
                text: tile.appName
                description: tile.appDescription
            }
        }
    }

    // ── App row for the "All apps" list drawer ──────────────────────────
    // Unlike a pinned tile there is room for two lines, so the description
    // goes under the name in a lighter, smaller face.
    component AppListItem : Item {
        id: row
        required property int index
        required property var model
        required property var view
        width: view ? view.width : 0
        height: Math.round(root.u * 2.4)

        readonly property string appName: {
            const raw = String(row.model?.compactName ?? row.model?.display ?? "");
            return raw.replace(/\s*\([^()]*\)\s*$/, "");
        }
        readonly property string appDescription: {
            const d = String(row.model?.description ?? "").trim();
            return d !== row.appName ? d : "";
        }
        readonly property var appDecoration: row.model?.decoration ?? ""

        // Tile metrics, expressed as a list cell: the horizontal inset puts
        // the icon on the same column the letter headings start on. No
        // vertical padding — the block is centred on the row height, so the
        // air above and below it is identical whether the app has a
        // description line or not.
        readonly property int hPad: FluentStyle.spacingMedium

        T.ItemDelegate {
            id: rowButton
            anchors.fill: parent
            hoverEnabled: true
            leftPadding: row.hPad
            rightPadding: row.hPad
            topPadding: 0
            bottomPadding: 0
            // No press colour: a list row behaves like a pinned tile — the
            // surface never changes on click, it only gives under the pointer.
            scale: rowButton.down ? 0.985 : 1
            Behavior on scale {
                NumberAnimation { duration: FluentStyle.durationFast; easing.type: FluentStyle.easingSoft }
            }
            background: Item {
                // Same mask as a tile and a letter heading — the taskbar's
                // white/black wash plus its small soft shadow — instead of the
                // ink state layer this row used to paint. Inset 2px top and
                // bottom so neighbouring rows do not fuse into one band.
                TaskHoverMask {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    hovered: rowButton.hovered || rowButton.down
                    radius: FluentStyle.radiusControl
                }
            }
            contentItem: Item {
                // The block is centred on the row explicitly instead of being
                // stretched over the padded area: a Control hands its
                // contentItem the whole padded height, and a two-line label
                // then sat a fraction lower than a symmetric inset. Anchoring
                // the RowLayout by its own centre keeps the air above and
                // below identical whatever the font metrics do.
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: FluentStyle.spacingMedium
                    Kirigami.Icon {
                        source: row.appDecoration
                        Layout.preferredWidth: Math.round(root.u * 1.3)
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.alignment: Qt.AlignVCenter
                        animated: false
                        selected: false
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.appName
                            font: Kirigami.Theme.defaultFont
                            color: FluentStyle.textPrimary
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: row.appDescription.length > 0
                            text: row.appDescription
                            font.family: Kirigami.Theme.defaultFont.family
                            font.weight: Font.Light
                            font.pointSize: Math.max(1, Kirigami.Theme.defaultFont.pointSize - 1)
                            color: FluentStyle.textSecondary
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                z: 2
                onClicked: (mouse) => {
                    root.openAppMenu(row.view.model, row.index,
                                     row.model?.favoriteId ?? null,
                                     row.model?.actionList ?? null,
                                     rowButton, mouse.x, mouse.y);
                }
            }
            onClicked: {
                const m = row.view.model;
                if (m && m.trigger && m.trigger(row.index, "", null) && kickoff.hideOnWindowDeactivate) {
                    kickoff.expanded = false;
                }
            }
        }
    }

    // ── Search result row ───────────────────────────────────────────────
    // One runner result, drawn as a Win11 list row: the same 2.4u height, 1.3u
    // glyph and 12px insets as an All apps row, plus the description line the
    // runner provides. It exists because Kicker's own delegate takes its
    // paddings, icon size, fonts and state layer from the Plasma theme and the
    // classic launcher — no amount of retuning from the outside removed the
    // old look, so the search view draws its own row instead.
    component SearchResultRow : Item {
        id: resultRow
        required property int index
        required property var model
        required property var view

        // `isCurrentItem` is the documented flag, but it is only attached to
        // the delegate root and is easy to lose when the row is rebuilt; the
        // index comparison is a second, always-available source of truth so the
        // pre-highlight can never silently disappear.
        readonly property bool current: ListView.isCurrentItem
            || (resultRow.view !== null && resultRow.view.currentIndex === resultRow.index)
        readonly property bool separator: resultRow.model ? resultRow.model.isSeparator === true : false
        readonly property string resultName: String(resultRow.model?.display ?? resultRow.model?.compactName ?? "")
        readonly property string resultDetail: {
            const detail = String(resultRow.model?.description ?? "").trim();
            return detail !== resultRow.resultName ? detail : "";
        }
        readonly property int rowHeight: Math.round(root.u * 2.4)

        // The page's Return handler drives `currentItem.action.trigger()`, so
        // the row publishes the same tiny action surface a delegate has.
        readonly property var action: resultAction

        width: resultRow.view ? resultRow.view.width : 0
        // Separators are Kicker's own group splitting; the section captions
        // above already do that here, so these collapse to nothing.
        visible: !resultRow.separator
        height: resultRow.separator ? 0 : resultRow.rowHeight

        function trigger(): void {
            const m = resultRow.view ? resultRow.view.model : null;
            if (m && m.trigger) {
                if (m.trigger(resultRow.index, "", null) && kickoff.hideOnWindowDeactivate) {
                    kickoff.expanded = false;
                }
            }
        }

        QtObject {
            id: resultAction
            function trigger(): void {
                resultRow.trigger();
            }
        }

        T.ItemDelegate {
            id: rowButton
            anchors.fill: parent
            hoverEnabled: true
            leftPadding: FluentStyle.spacingMedium
            rightPadding: FluentStyle.spacingMedium
            topPadding: 0
            bottomPadding: 0
            // A row gives under the pointer instead of changing colour, like a
            // pinned tile.
            scale: rowButton.down ? 0.985 : 1
            Behavior on scale {
                NumberAnimation { duration: FluentStyle.durationFast; easing.type: FluentStyle.easingSoft }
            }

            // The same mask a tile, an All apps row and a letter heading use —
            // the taskbar's white/black wash plus its small soft shadow — so a
            // result row reads as the same kind of surface as everything else
            // in the menu. A flat ink rectangle here was the odd one out: it
            // looked like the classic Kicker highlight, which is exactly why
            // the search list never felt Fluent.
            background: Item {
                TaskHoverMask {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    radius: FluentStyle.radiusControl
                    // The pre-highlighted first result and plain hover share
                    // one layer: Win11 only ever has one "current" row here.
                    hovered: rowButton.hovered || resultRow.current
                }
            }

            contentItem: Item {
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: FluentStyle.spacingMedium
                    Kirigami.Icon {
                        source: resultRow.model?.decoration ?? ""
                        Layout.preferredWidth: Math.round(root.u * 1.3)
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.alignment: Qt.AlignVCenter
                        animated: false
                        selected: false
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: resultRow.resultName
                            font: Kirigami.Theme.defaultFont
                            color: FluentStyle.textPrimary
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: resultRow.resultDetail.length > 0
                            text: resultRow.resultDetail
                            font.family: Kirigami.Theme.defaultFont.family
                            font.weight: Font.Light
                            font.pointSize: Math.max(1, Kirigami.Theme.defaultFont.pointSize - 1)
                            color: FluentStyle.textSecondary
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                    }
                }
            }

            onClicked: resultRow.trigger()
        }
    }

    // ── Home: Pinned + All apps, in one scroll surface ──────────────────
    // Both sections live in the same Flickable so scrolling Pinned flows
    // straight into the app drawer, the way the Windows menu behaves.
    Component {
        id: homeComponent
        Item {
            id: home
            objectName: "win11Home"
            // No clip here: the Flickable clips its own content, and the
            // scrollbar deliberately reaches past this item's right edge to
            // sit on the card edge instead of the padded content edge.

            // One scroll surface covers Pinned *and* the app drawer, so a
            // single reset puts both back to the top.
            function scrollToTop(): void {
                homeScroll.contentY = 0;
            }

            readonly property real contentWidth: home.width - FluentStyle.spacingLarge * 2
            // Elastic columns, same floor as All apps: fit as many tiles as
            // the width allows instead of pinning the row to five/six.
            readonly property int minCellWidth: Math.round(root.u * 4.6)
            readonly property int columns: Math.max(1, Math.floor(contentWidth / minCellWidth))
            // Flow sizes the pinned section to whatever its tiles need: the
            // row count follows the number of favourites, and a tile with a
            // two-line name grows taller than its one-line neighbours.
            readonly property bool appsAsCards: root.appsAsCards

            // Letters the current drawer exposes, used by the A–Z picker.
            readonly property var letters: (allAppsLoader.item && allAppsLoader.item.letters)
                ? allAppsLoader.item.letters
                : []

            // Jumping is animated: a letter pick is a deliberate navigation,
            // and an instant snap makes it hard to see where you landed.
            NumberAnimation {
                id: homeJumpAnimation
                target: homeScroll
                property: "contentY"
                duration: 260
                easing.type: Easing.OutCubic
            }

            function jumpToLetter(letter: string): void {
                const source = allAppsLoader.item;
                if (!source || !source.sectionY) {
                    return;
                }
                jumpToSection(source.sectionY(letter));
            }

            // Same travel, addressed by category index: the category drawer
            // has no letter headings, so the icon sheet hands us the section
            // number instead.
            function jumpToCategory(index: int): void {
                const source = allAppsLoader.item;
                if (!source || !source.categorySectionY) {
                    return;
                }
                jumpToSection(source.categorySectionY(index));
            }

            function jumpToSection(sectionOffset: real): void {
                const maxY = Math.max(0, homeScroll.contentHeight - homeScroll.height);
                // homeColumn is offset by the scroll surface's own padding,
                // so its children's y is relative to that, not to the content.
                const target = Math.max(0, Math.min(maxY,
                    homeColumn.y + allAppsLoader.y + sectionOffset));
                homeJumpAnimation.stop();
                homeJumpAnimation.from = homeScroll.contentY;
                homeJumpAnimation.to = target;
                homeJumpAnimation.start();
            }

            // One scroll surface for the whole page: Pinned, the rule, the
            // "All apps" caption and the drawer all sit in a single Flickable,
            // so dragging anywhere — including over the favourites — scrolls
            // the menu instead of stopping at a fixed block of icons.
            Flickable {
                id: homeScroll
                anchors.fill: parent
                anchors.leftMargin: FluentStyle.spacingLarge
                anchors.rightMargin: FluentStyle.spacingLarge
                anchors.topMargin: 0
                anchors.bottomMargin: 0
                // Inner padding of the scroll surface itself: the content
                // gets breathing room at both extremes instead of butting
                // against the rules above and below when scrolled to an end.
                readonly property int contentPadding: FluentStyle.spacingSmall
                contentWidth: width
                contentHeight: homeColumn.implicitHeight + homeScroll.contentPadding * 2
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                FastWheelHandler {
                    target: homeScroll
                }

                Column {
                    id: homeColumn
                    y: homeScroll.contentPadding
                    width: homeScroll.width
                    spacing: 0

                    SectionHeader {
                        title: i18nc("@title:section pinned applications", "Pinned") // qmllint disable unqualified
                        actionText: ""
                        alignTop: true
                    }

                    Flow {
                        id: pinnedGrid
                        width: homeColumn.width
                        spacing: 0
                        Repeater {
                            model: kickoff.rootModel.favoritesModel
                            delegate: AppTile {
                                cellWidth: Math.floor(home.contentWidth / home.columns)
                            }
                        }
                    }

                    Item {
                        width: homeColumn.width
                        // Rule sits at the bottom edge: the gap above keeps
                        // Pinned breathing room, nothing below before the
                        // optional Recent block and All apps.
                        height: FluentStyle.strokeWidth + FluentStyle.spacingSmall
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: FluentStyle.strokeWidth
                            color: FluentStyle.divider
                        }
                    }

                    // Optional Recent block above All apps. Reads an
                    // independent RecentUsageModel that includes apps, files
                    // and folders (the classic History page stays app-only).
                    // Shown as ONE horizontal row; the "…" button opens the
                    // full page.
                    // Zero height when off or empty.
                    Item {
                        id: recentSection
                        width: homeColumn.width
                        // Fit the row to the available width: take as many
                        // tiles as comfortably fit, then divide the width
                        // evenly so nothing ever spills past the right edge.
                        // Same minimum as the app tiles below, so the Recent
                        // row reads at the same scale as Pinned / All apps.
                        readonly property int minTileWidth: root.tileWidth
                        readonly property int fitCount: Math.max(1, Math.floor(width / minTileWidth))
                        readonly property int shownCount: Math.min(win11RecentModel.count,
                                                                 root.recentRowLimit,
                                                                 fitCount)
                        readonly property int cellWidth: shownCount > 0
                            ? Math.min(root.tileWidth, Math.floor(width / shownCount))
                            : root.tileWidth
                        // No fixed cell height: each card keeps AppTile's own
                        // elastic height, so a one-line name stays compact and
                        // a wrapped two-line name grows — exactly like the
                        // Pinned / All apps cards. The row is as tall as its
                        // tallest visible card (the Flow reports that).
                        readonly property var viewBridge: ({ model: win11RecentModel })
                        height: root.showWin11Recent && shownCount > 0
                            ? recentHeader.implicitHeight + recentStrip.height + FluentStyle.spacingSmall
                            : 0
                        visible: recentSection.height > 0
                        clip: true

                        SectionHeader {
                            id: recentHeader
                            title: i18nc("@title:section recently used items", "Recent") // qmllint disable unqualified
                            // Overflow ellipsis instead of a word: the row is a
                            // preview, "…" opens the full Recent page.
                            actionText: ""
                            actionIcon: "view-more-horizontal-symbolic"
                            alignTop: true
                            topSpace: FluentStyle.spacingMedium
                            onActionTriggered: root.showRecent()
                        }

                        // A Flow, not a ListView: it sizes itself to its tallest
                        // child, which is what makes the row height follow the
                        // line count. The tiles are sized to fill the width
                        // exactly, so this never wraps to a second row; the full
                        // list lives on the Recent page the "…" opens.
                        Flow {
                            id: recentStrip
                            visible: root.showWin11Recent && recentSection.shownCount > 0
                            anchors.top: recentHeader.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 0
                            Repeater {
                                model: win11RecentModel
                                delegate: AppTile {
                                    visible: index < recentSection.shownCount
                                    cellWidth: recentSection.cellWidth
                                    // Flow has no model of its own; hand the
                                    // tile the same shim Pinned does not need
                                    // (it falls back to the favourites model).
                                    view: recentSection.viewBridge
                                }
                            }
                        }
                    }

                    // Stands off the rule above: glued to it, the caption and
                    // the letter headings under it read as part of the rule.
                    SectionHeader {
                        title: i18nc("@title:section all applications", "All apps") // qmllint disable unqualified
                        actionText: ""
                        alignTop: true
                        topSpace: FluentStyle.spacingMedium
                    }

                    Loader {
                        id: allAppsLoader
                        width: homeColumn.width
                        height: item ? item.contentHeight : 0
                        // The grouping swap animation: the drawer sinks to 0.8
                        // and fades out around its top edge, the model is
                        // exchanged, then the new drawer grows back. Origin at
                        // the top keeps the caption and the rule above it
                        // still while the content moves.
                        opacity: root.appsSwapOpacity
                        scale: root.appsSwapScale
                        transformOrigin: Item.Top
                        sourceComponent: root.appsByCategory
                            ? allAppsCategoryComponent
                            : (home.appsAsCards ? allAppsCardsComponent : allAppsListComponent)
                    }
                }
            }

            // Thin overlay scrollbar in the right padding, so it never covers
            // a tile: the Flickable reserves `spacingLarge` there already.
            SmallScrollBar {
                id: homeScrollBar
                flickable: homeScroll
                anchors.top: homeScroll.top
                anchors.bottom: homeScroll.bottom
                anchors.right: parent.right
                // Inset from both rules: a bar that ran edge to edge read as
                // part of the hairlines above and below it.
                anchors.topMargin: FluentStyle.spacingSmall
                anchors.bottomMargin: FluentStyle.spacingSmall
                // A small inset from the card edge, not flush against the
                // frame: cancelling the theme's content padding entirely put
                // the bar right on the border, which read as glued to it. The
                // inset still keeps it inside the padding gutter, clear of
                // every tile.
                anchors.rightMargin: Math.round(root.u * 0.4) - kickoff.backgroundMetrics.rightPadding
            }
        }
    }

    Component {
        id: allAppsListComponent
        Item {
            id: appsListHost
            clip: true

            readonly property int rowHeight: Math.round(root.u * 2.4)
            // Must match LetterHeader's own height: the jump maths below
            // assumes every header is exactly this tall.
            readonly property int sectionHeight: Math.round(root.u * 1.8)
            // Bind through root.appsModel so root's onRefreshed poke actually
            // re-evaluates it; modelForRow() alone creates no dependency.
            readonly property var appsModel: root.appsModel
            // The outer Flickable owns scrolling, so this view reports its
            // whole content height and never flicks on its own.
            readonly property real contentHeight: appsListView.contentHeight

            // Letters in order, each with the row it starts at. Rows are a
            // uniform height here, so the offset of any section is pure
            // arithmetic — no need to instantiate it to measure.
            property var sections: []
            readonly property var letters: {
                const out = [];
                for (let i = 0; i < appsListHost.sections.length; ++i) {
                    out.push(appsListHost.sections[i].letter);
                }
                return out;
            }

            function rebuildSections(): void {
                const m = appsListHost.appsModel;
                const out = [];
                if (m && m.count) {
                    const groupRole = m.KItemModels.KRoleNames.role("group");
                    let current = null;
                    for (let row = 0; row < m.count; ++row) {
                        const g = String(m.data(m.index(row, 0), groupRole) ?? "");
                        const key = g.length > 0 ? g[0].toUpperCase() : "#";
                        if (!current || current.letter !== key) {
                            current = { letter: key, firstRow: row };
                            out.push(current);
                        }
                    }
                }
                appsListHost.sections = out;
            }

            function sectionY(letter: string): real {
                for (let i = 0; i < appsListHost.sections.length; ++i) {
                    const s = appsListHost.sections[i];
                    if (s.letter === letter) {
                        return i * appsListHost.sectionHeight + s.firstRow * appsListHost.rowHeight;
                    }
                }
                return 0;
            }

            Component.onCompleted: appsListHost.rebuildSections()
            Connections {
                target: kickoff.rootModel
                function onRefreshed(): void { appsListHost.rebuildSections() }
            }

            ListView {
                id: appsListView
                anchors.fill: parent
                model: appsListHost.appsModel
                clip: true
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                section.property: "group"
                section.criteria: ViewSection.FirstCharacter
                section.labelPositioning: ViewSection.InlineLabels
                delegate: AppListItem {
                    view: appsListView
                    height: appsListHost.rowHeight
                }
                section.delegate: LetterHeader {
                    // ComponentBehavior: Bound requires the attached
                    // `section` property to be declared explicitly. Without
                    // it every letter header throws "section is not defined"
                    // and the A/B/C dividers render blank.
                    required property string section
                    letter: section.length === 1 ? section.toUpperCase() : section
                    height: appsListHost.sectionHeight
                    onClicked: root.openLetterPicker()
                }
            }
        }
    }

    // ── All apps as Pinned-style cards, grouped by letter ───────────────
    // The model is bucketed by the first character of `group` into plain JS
    // sections; each section renders one header plus a Flow of cards. A Flow
    // lets every tile keep its measured height, so a two-line name makes its
    // card — and its hover mask — taller, instead of clipping to one cell.
    Component {
        id: allAppsCardsComponent
        Item {
            id: appsCardsHost
            clip: true

            // Elastic columns: use the same minimum cell width as the Pinned
            // grid and fit as many tiles as the row allows, instead of
            // hard-coding five. A wider panel gains a column automatically.
            readonly property int minCellWidth: Math.round(root.u * 4.6)
            readonly property int columns: Math.max(1, Math.floor(appsCardsHost.contentWidth / appsCardsHost.minCellWidth))
            readonly property real contentWidth: appsCardsHost.width
            readonly property var appsModel: root.appsModel
            readonly property int cellWidth: Math.floor(appsCardsHost.contentWidth / appsCardsHost.columns)
            readonly property real contentHeight: contentColumn.implicitHeight

            property var sections: []

            // A QtObject shim gives AppTile a `view.model.trigger` that maps
            // back to the real Kicker model using each card's saved row.
            QtObject {
                id: triggerBridge
                readonly property var model: appsCardsHost.appsModel
            }

            function rebuildSections(): void {
                const m = appsCardsHost.appsModel;
                const result = [];
                if (!m || !m.count) {
                    appsCardsHost.sections = result;
                    return;
                }
                const displayRole = Qt.DisplayRole;
                const decoRole = Qt.DecorationRole;
                const groupRole = m.KItemModels.KRoleNames.role("group");
                const compactRole = m.KItemModels.KRoleNames.role("compactName");
                const descRole = m.KItemModels.KRoleNames.role("description");
                // Carried through so the right-click menu can build the same
                // actions the delegate model would expose.
                const favRole = m.KItemModels.KRoleNames.role("favoriteId");
                const actionRole = m.KItemModels.KRoleNames.role("actionList");
                const read = (row, role) => role >= 0 ? m.data(m.index(row, 0), role) : undefined;

                const buckets = {};
                const keys = [];
                for (let row = 0; row < m.count; ++row) {
                    const group = String(read(row, groupRole) ?? "");
                    const key = group.length > 0 ? group[0].toUpperCase() : "#";
                    if (!buckets[key]) {
                        buckets[key] = [];
                        keys.push(key);
                    }
                    buckets[key].push({
                        row: row,
                        compactName: String(read(row, compactRole) ?? read(row, displayRole) ?? ""),
                        display: String(read(row, displayRole) ?? ""),
                        description: String(read(row, descRole) ?? ""),
                        decoration: read(row, decoRole) ?? "",
                        favoriteId: read(row, favRole) ?? null,
                        actionList: read(row, actionRole) ?? null
                    });
                }
                keys.sort();
                for (const key of keys) {
                    result.push({ letter: key, apps: buckets[key] });
                }
                appsCardsHost.sections = result;
            }

            Component.onCompleted: appsCardsHost.rebuildSections()
            Connections {
                target: kickoff.rootModel
                function onRefreshed(): void { appsCardsHost.rebuildSections() }
            }

            readonly property var letters: {
                const out = [];
                for (let i = 0; i < appsCardsHost.sections.length; ++i) {
                    out.push(appsCardsHost.sections[i].letter);
                }
                return out;
            }

            // Sections are laid out as siblings in one Column, so their real
            // y is available once the repeater has built them — no height
            // arithmetic needed even though a Flow row can be taller than its
            // neighbours.
            function sectionY(letter: string): real {
                for (let i = 0; i < appsCardsHost.sections.length; ++i) {
                    if (appsCardsHost.sections[i].letter === letter) {
                        const item = contentColumn.children[i];
                        return item ? item.y : 0;
                    }
                }
                return 0;
            }

            Column {
                id: contentColumn
                width: parent.width
                spacing: 0
                Repeater {
                    model: appsCardsHost.sections
                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        spacing: 0

                        LetterHeader {
                            width: parent.width
                            letter: modelData.letter
                            onClicked: root.openLetterPicker()
                        }

                        Flow {
                            width: parent.width
                            spacing: 0
                            Repeater {
                                model: modelData.apps
                                delegate: AppTile {
                                    required property var modelData
                                    triggerRow: modelData.row
                                    view: triggerBridge
                                    model: modelData
                                    // Uniform width for every app; only the
                                    // height varies with the wrapped name, so
                                    // one row of tiles still lines up.
                                    cellWidth: appsCardsHost.cellWidth
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── All apps grouped by system menu category ────────────────────────
    // Same category set the classic layout's sidebar lists: they come from
    // RootModel rows 2..N (see categoryEntries), i.e. straight out of the
    // system applications.menu, so they are translated, ordered the way the
    // menu file orders them and carry their own icon. Each section shows its
    // caption and then either the same cards the alphabetical drawer uses,
    // or compact rows when the user prefers lists.
    Component {
        id: allAppsCategoryComponent
        Item {
            id: appsCategoryHost
            clip: true

            readonly property real contentHeight: categoryColumn.implicitHeight
            // No alphabetical jump targets while grouping by category.
            readonly property var letters: []

            readonly property int minCellWidth: Math.round(root.u * 4.6)
            readonly property int columns: Math.max(1, Math.floor(appsCategoryHost.width / appsCategoryHost.minCellWidth))
            readonly property int cellWidth: Math.floor(appsCategoryHost.width / appsCategoryHost.columns)
            readonly property int rowHeight: Math.round(root.u * 2.4)

            // One section per category, straight from RootModel. The apps are
            // driven by each category's own model, so the delegates keep the
            // same role access they have in the alphabetical drawer and
            // trigger() lands on the right row without any bookkeeping.
            readonly property var sections: {
                const revision = root.categoryRevision;
                const out = [];
                for (const entry of root.categoryEntries) {
                    out.push({
                        name: entry.name,
                        icon: entry.icon,
                        model: entry.model,
                        // AppTile reaches the model through `view.model`;
                        // this shim keeps that single access path.
                        bridge: ({ model: entry.model })
                    });
                }
                return out;
            }

            function sectionY(letter: string): real {
                return 0;
            }
            // Offset of one category section inside this page, so the Home
            // surface can scroll to it. The delegates are the Column children
            // in the same order as `sections`.
            function categorySectionY(index: int): real {
                const section = categoryColumn.children[index];
                return section ? section.y : 0;
            }
            function jumpToLetter(letter: string): void {
            }

            Column {
                id: categoryColumn
                width: parent.width
                spacing: 0

                Repeater {
                    model: appsCategoryHost.sections
                    delegate: Column {
                        id: categorySection
                        required property var modelData
                        required property int index
                        width: parent.width
                        spacing: 0

                        CategoryHeader {
                            width: parent.width
                            title: categorySection.modelData.name
                            icon: categorySection.modelData.icon
                            // Air between categories; the first one sits
                            // straight under the "All apps" caption.
                            topSpace: categorySection.index > 0 ? FluentStyle.spacingMedium : 0
                            // The category drawer has no letter headings, so
                            // its own headings are the jump trigger: same
                            // sheet, icons instead of letters.
                            onClicked: root.openPickerSheet("category")
                        }

                        Flow {
                            visible: root.appsAsCards
                            width: parent.width
                            spacing: 0
                            Repeater {
                                model: categorySection.modelData.model
                                delegate: AppTile {
                                    view: categorySection.modelData.bridge
                                    cellWidth: appsCategoryHost.cellWidth
                                }
                            }
                        }

                        ListView {
                            id: categoryAppsView
                            width: parent.width
                            // Collapsed to zero when the card drawer is used,
                            // so its delegates are never instantiated.
                            height: visible ? count * appsCategoryHost.rowHeight : 0
                            visible: !root.appsAsCards
                            model: categorySection.modelData.model
                            interactive: false
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: AppListItem {
                                view: categoryAppsView
                                height: appsCategoryHost.rowHeight
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Recent: full page of apps, files and folders ────────────────────
    Component {
        id: recentComponent
        Item {
            id: recentPage
            objectName: "win11Recent"
            readonly property real contentWidth: recentPage.width - FluentStyle.spacingLarge * 2
            readonly property int columns: Math.max(1, Math.floor(contentWidth / root.tileWidth))

            function scrollToTop(): void {
                if (root.appsAsCards) {
                    recentGrid.positionViewAtBeginning();
                } else {
                    recentFullList.positionViewAtBeginning();
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: FluentStyle.spacingLarge
                anchors.rightMargin: FluentStyle.spacingLarge
                anchors.topMargin: FluentStyle.spacingSmall
                anchors.bottomMargin: 0
                spacing: FluentStyle.spacingSmall

                RowLayout {
                    Layout.fillWidth: true
                    PC3.ToolButton {
                        id: recentBackButton
                        // Back arrow only — no word next to it.
                        icon.name: "go-previous"
                        display: PC3.AbstractButton.IconOnly
                        implicitWidth: Math.round(root.u * 1.7)
                        implicitHeight: Math.round(root.u * 1.7)
                        icon.width: Math.round(root.u * 0.9)
                        icon.height: Math.round(root.u * 0.9)
                        flat: true
                        background: FluentHighlight { hovered: recentBackButton.hovered; pressed: recentBackButton.down; radius: FluentStyle.radiusControl; flatStates: true }
                        onClicked: root.showHome()
                        FluentToolTip {
                            visible: recentBackButton.hovered
                            text: i18nc("@action:button", "Back") // qmllint disable unqualified
                        }
                    }
                    Item { Layout.fillWidth: true }
                    PC3.Label {
                        text: i18nc("@title:section recently used items", "Recent") // qmllint disable unqualified
                        color: FluentStyle.textPrimary
                        font.bold: true
                    }
                }

                GridView {
                    id: recentGrid
                    visible: root.appsAsCards
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: win11RecentModel
                    cellWidth: Math.floor(recentPage.contentWidth / recentPage.columns)
                    cellHeight: root.tileHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    FastWheelHandler { target: recentGrid }

                    delegate: AppTile {
                        view: recentGrid
                        cellWidth: recentGrid.cellWidth
                        width: recentGrid.cellWidth
                        height: recentGrid.cellHeight
                    }
                }

                ListView {
                    id: recentFullList
                    visible: !root.appsAsCards
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: win11RecentModel
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    focus: false
                    currentIndex: -1

                    FastWheelHandler { target: recentFullList }

                    delegate: AppListItem { view: recentFullList }
                }
            }

            // Anchored to the page, NOT placed inside the ColumnLayout: a
            // layout manages its children's geometry, so anchors there are
            // undefined behaviour (and left the page blank).
            SmallScrollBar {
                flickable: root.appsAsCards ? recentGrid : recentFullList
                anchors.top: recentPage.top
                anchors.bottom: recentPage.bottom
                anchors.right: recentPage.right
                anchors.topMargin: FluentStyle.spacingSmall
                anchors.bottomMargin: FluentStyle.spacingSmall
                anchors.rightMargin: Math.round(root.u * 0.4)
            }

            // Empty state when the model has no history yet.
            Column {
                anchors.centerIn: parent
                spacing: FluentStyle.spacingMedium
                visible: win11RecentModel.count === 0
                Kirigami.Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "view-history"
                    width: Math.round(root.u * 2.4)
                    height: width
                    color: FluentStyle.textSecondary
                }
                PC3.Label {
                    text: i18nc("@info no recent items yet", "No recent items") // qmllint disable unqualified
                    color: FluentStyle.textSecondary
                }
            }
        }
    }

    // ── All apps: flat scrollable grid ──────────────────────────────────
    Component {
        id: allAppsComponent
        Item {
            id: allApps
            objectName: "win11AllApps"
            readonly property real contentWidth: allApps.width - FluentStyle.spacingLarge * 2
            readonly property int columns: 5

            function scrollToTop(): void {
                allAppsGrid.positionViewAtBeginning();
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: FluentStyle.spacingLarge
                anchors.rightMargin: FluentStyle.spacingLarge
                anchors.topMargin: FluentStyle.spacingSmall
                anchors.bottomMargin: 0
                spacing: FluentStyle.spacingSmall

                RowLayout {
                    Layout.fillWidth: true
                    PC3.ToolButton {
                        id: backButton
                        // Back arrow only — no word next to it.
                        icon.name: "go-previous"
                        display: PC3.AbstractButton.IconOnly
                        implicitWidth: Math.round(root.u * 1.7)
                        implicitHeight: Math.round(root.u * 1.7)
                        icon.width: Math.round(root.u * 0.9)
                        icon.height: Math.round(root.u * 0.9)
                        flat: true
                        background: FluentHighlight { hovered: backButton.hovered; pressed: backButton.down; radius: FluentStyle.radiusControl; flatStates: true }
                        onClicked: root.showHome()
                        FluentToolTip {
                            visible: backButton.hovered
                            text: i18nc("@action:button", "Back") // qmllint disable unqualified
                        }
                    }
                    Item { Layout.fillWidth: true }
                    PC3.Label {
                        text: i18nc("@title:section all applications", "All apps") // qmllint disable unqualified
                        color: FluentStyle.textPrimary
                        font.bold: true
                    }
                }

                GridView {
                    id: allAppsGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: root.appsModel
                    cellWidth: Math.floor(allApps.contentWidth / allApps.columns)
                    cellHeight: root.tileHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    FastWheelHandler {
                        target: allAppsGrid
                    }

                    delegate: AppTile {
                        view: allAppsGrid
                        cellWidth: allAppsGrid.cellWidth
                        width: allAppsGrid.cellWidth
                        height: allAppsGrid.cellHeight
                    }
                }
            }
        }
    }

    // ── Search results ──────────────────────────────────────────────────
    Component {
        id: searchComponent
        Item {
            id: searchView
            objectName: "win11Search"
            readonly property var searchModel: kickoff.runnerModel.count ? kickoff.runnerModel.modelForRow(0) : null
            // Read by the window's Return / Down / Up handling: the field owns
            // the keyboard, the list only exposes where the highlight is.
            readonly property alias count: resultsView.count
            property alias currentIndex: resultsView.currentIndex
            readonly property alias currentItem: resultsView.currentItem

            function scrollToTop(): void {
                resultsView.positionViewAtBeginning();
            }

            // A plain ListView with our own row, not KickoffListView: that is
            // Kicker's list, and it drags the Plasma delegate, the themed
            // section header and the themed scroll bar along with it. That is
            // why the results still looked like the classic launcher however
            // the delegate was retuned from the outside.
            ListView {
                id: resultsView
                anchors.fill: parent
                model: searchView.searchModel
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                FastWheelHandler {
                    target: resultsView
                }

                // The search field owns the keyboard; this view only carries
                // the highlight, so it must never take the focus — otherwise
                // every keystroke after the first would land on the list.
                focus: false
                // No ListView highlight component at all: the pre-highlighted
                // result is drawn by the row itself (SearchResultRow's
                // FluentHighlight). An explicit null keeps any inherited or
                // style-provided highlight from ever painting over the row.
                highlight: null
                keyNavigationEnabled: false
                currentIndex: count > 0 ? 0 : -1
                onCountChanged: {
                    // Every new query starts on the first result.
                    currentIndex = count > 0 ? 0 : -1;
                    positionViewAtBeginning();
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }
                }

                section.property: "group"
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                    required property string section
                    width: resultsView.width
                    // Runner plugins that report no group leave the property
                    // empty; that must not leave a blank band above the list.
                    height: section.length > 0 ? Math.round(root.u * 1.8) : 0
                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: FluentStyle.spacingMedium
                        anchors.rightMargin: FluentStyle.spacingMedium
                        anchors.bottomMargin: FluentStyle.spacingXSmall
                        visible: section.length > 0
                        text: parent.section
                        color: FluentStyle.textSecondary
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pointSize: Math.max(1, Kirigami.Theme.defaultFont.pointSize - 1)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }

                delegate: SearchResultRow {
                    view: resultsView
                }
            }

            SmallScrollBar {
                flickable: resultsView
                anchors.top: resultsView.top
                anchors.bottom: resultsView.bottom
                anchors.right: parent.right
                anchors.topMargin: FluentStyle.spacingSmall
                anchors.bottomMargin: FluentStyle.spacingSmall
                anchors.rightMargin: Math.round(root.u * 0.4)
            }

            // Win11's empty state: one glyph and a line of secondary text,
            // centred in the results area. Laid out by a Column, so the
            // children are given the full width and centre their own content —
            // anchoring inside a positioner is not allowed.
            Column {
                id: emptyState
                readonly property int glyphSize: Math.round(root.u * 2.4)
                anchors.centerIn: parent
                width: resultsView.width
                spacing: FluentStyle.spacingMedium
                visible: resultsView.count === 0

                Item {
                    width: parent.width
                    height: emptyState.glyphSize
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: emptyState.glyphSize
                        height: width
                        source: "edit-none"
                        color: FluentStyle.textSecondary
                        opacity: 0.6
                        animated: false
                        selected: false
                    }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: i18nc("@info:status", "No matches") // qmllint disable unqualified
                    color: FluentStyle.textSecondary
                    font: Kirigami.Theme.defaultFont
                }
            }
        }
    }
}
