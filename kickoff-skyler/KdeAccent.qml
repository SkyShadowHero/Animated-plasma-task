/* SPDX-FileCopyrightText: 2026 SkyShadowHero <skyler@example.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

/**
 * The KDE accent colour, resolved exactly the way the task manager does it
 * (see taskmanager-skyler/backend.cpp, Backend::accentColor()):
 *
 *   1. kdeglobals [General] AccentColor               — a custom accent
 *   2. kdeglobals [Colors:Selection] BackgroundNormal — "from colour scheme"
 *   3. kdeglobals [General] LastUsedCustomAccentColor — last custom accent
 *   4. Kirigami's highlight colour                    — nothing readable
 *
 * Why not simply Kirigami.Theme.highlightColor: inside the launcher popup that
 * value comes from the *Plasma style's* colours file (the Win11 style ships
 * #0078D4), not from kdeglobals, so it ignores the accent chosen in System
 * Settings and does not match the panel's running-application indicators.
 *
 * kdeglobals is not exposed to QML, so kreadconfig6 is asked through the
 * executable data engine. The singleton lives as long as the popup does, i.e.
 * the value is read once per launch — a colour change is picked up the next
 * time the launcher opens, which is all the task manager's KConfigWatcher buys
 * us in practice. Until the answers arrive `accent` is Kirigami's highlight
 * colour, so nothing ever renders black or transparent.
 */
Item {
    id: root

    visible: false

    // Source names double as the commands that are run: the executable engine
    // reports each result under the command string it executed.
    readonly property string customCommand: "kreadconfig6 --file kdeglobals --group General --key AccentColor"
    readonly property string schemeCommand: "kreadconfig6 --file kdeglobals --group Colors:Selection --key BackgroundNormal"
    readonly property string lastCommand: "kreadconfig6 --file kdeglobals --group General --key LastUsedCustomAccentColor"

    // null = not answered (or answered with nothing usable).
    property var customAccent: null
    property var schemeAccent: null
    property var lastAccent: null

    readonly property color accent: {
        if (root.customAccent !== null) {
            return root.customAccent;
        }
        if (root.schemeAccent !== null) {
            return root.schemeAccent;
        }
        if (root.lastAccent !== null) {
            return root.lastAccent;
        }
        return Kirigami.Theme.highlightColor;
    }

    readonly property P5Support.DataSource source: P5Support.DataSource {
        engine: "executable"
        connectedSources: [root.customCommand, root.schemeCommand, root.lastCommand]

        // The handler only forwards: qmlcachegen (Qt 6.8) segfaults while
        // compiling a handler that uses the `data` parameter both in an `if`
        // condition and inside its block, so the work happens in a plain
        // function below.
        onNewData: (sourceName, data) => root.applyAccent(sourceName, data)
    }

    function applyAccent(sourceName, data) {
        if (!data) {
            return;
        }
        const color = root.parseKdeColor(data["stdout"]);
        if (color === null) {
            return;
        }
        if (sourceName === root.customCommand) {
            root.customAccent = color;
        } else if (sourceName === root.schemeCommand) {
            root.schemeAccent = color;
        } else if (sourceName === root.lastCommand) {
            root.lastAccent = color;
        }
    }

    /**
     * KDE writes colours as "R,G,B" (optionally "R,G,B,A", all 0-255). Returns
     * null for empty or malformed output so the chain above can fall through.
     */
    function parseKdeColor(value) {
        // The engine hands out either a string or the list of output lines.
        const text = (Array.isArray(value) ? value.join("\n") : String(value ?? "")).trim();
        if (text.length === 0) {
            return null;
        }

        const parts = text.split(",");
        if (parts.length < 3) {
            return null;
        }

        const component = (index, fallback) => {
            if (index >= parts.length) {
                return fallback;
            }
            const parsed = parseInt(parts[index].trim(), 10);
            if (isNaN(parsed)) {
                return NaN;
            }
            return Math.min(255, Math.max(0, parsed));
        };

        const red = component(0, 0);
        const green = component(1, 0);
        const blue = component(2, 0);
        const alpha = component(3, 255);
        if (isNaN(red) || isNaN(green) || isNaN(blue) || isNaN(alpha)) {
            return null;
        }

        return Qt.rgba(red / 255, green / 255, blue / 255, alpha / 255);
    }
}
