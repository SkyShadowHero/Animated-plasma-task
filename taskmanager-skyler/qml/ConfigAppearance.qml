/*
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

KCMUtils.SimpleKCM {
    id: root

    readonly property bool plasmaPaAvailable: Qt.createComponent("PulseAudio.qml").status === Component.Ready
    readonly property bool plasmoidVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconOnly: Plasmoid.pluginName === "org.kde.plasma.icontasks.skyler"

    property alias cfg_showToolTips: showToolTips.checked
    property alias cfg_highlightWindows: highlightWindows.checked
    property bool cfg_indicateAudioStreams
    property bool cfg_interactiveMute
    property bool cfg_tooltipControls
    property alias cfg_fill: fill.checked
    property alias cfg_maxStripes: maxStripes.value
    property alias cfg_forceStripes: forceStripes.checked
    property alias cfg_taskMaxWidth: taskMaxWidth.currentIndex
    property int cfg_iconSpacing: 0
    property alias cfg_miniTooltip: miniTooltip.checked
    property alias cfg_useThemeDecorations: useThemeDecorations.checked
    property alias cfg_useCustomIndicator: useCustomIndicator.checked
    property alias cfg_indicatorPosition: indicatorPosition.currentIndex
    property alias cfg_animationSpeed: animationSpeed.currentIndex
    property alias cfg_hoverEffect: hoverEffect.checked
    property alias cfg_hoverDirection: hoverDirection.currentIndex
    property alias cfg_iconScale: iconScale.value

    Component.onCompleted: {
        /* Don't rely on bindings for checking the radiobuttons
           When checking forceStripes, the condition for the checked value for the allow stripes button
           became true and that one got checked instead, stealing the checked state for the just clicked checkbox
        */
        if (maxStripes.value === 1) {
            forbidStripes.checked = true;
        } else if (!Plasmoid.configuration.forceStripes && maxStripes.value > 1) {
            allowStripes.checked = true;
        } else if (Plasmoid.configuration.forceStripes && maxStripes.value > 1) {
            forceStripes.checked = true;
        }
    }
    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showToolTips
            Kirigami.FormData.label: i18nc("@label for several checkboxes", "General:")
            text: i18nc("@option:check section General", "Show small window previews when hovering over tasks")
        }

        QQC2.CheckBox {
            id: highlightWindows
            text: showToolTips.checked ? i18nc("@option:check section General", "Hide other windows when hovering over previews") : i18nc("@option:check section General", "Hide other windows when hovering over tooltips")
        }

        QQC2.CheckBox {
            id: indicateAudioStreams
            text: i18nc("@option:check section General", "Show an indicator when a task is playing audio")
            checked: root.cfg_indicateAudioStreams && root.plasmaPaAvailable
            onToggled: root.cfg_indicateAudioStreams = checked
            enabled: root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: interactiveMute
            leftPadding: mirrored ? 0 : (indicateAudioStreams.indicator.width + indicateAudioStreams.spacing)
            rightPadding: mirrored ? (indicateAudioStreams.indicator.width + indicateAudioStreams.spacing) : 0
            text: i18nc("@option:check section General", "Mute task when clicking indicator")
            checked: root.cfg_interactiveMute && root.plasmaPaAvailable
            onToggled: root.cfg_interactiveMute = checked
            enabled: indicateAudioStreams.checked && root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: tooltipControls
            text: i18nc("@option:check section General", "Show media and volume controls in tooltip")
            checked: root.cfg_tooltipControls && root.plasmaPaAvailable
            onToggled: root.cfg_tooltipControls = checked
            enabled: root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: fill
            text: i18nc("@option:check section General", "Fill free space on panel")
        }

        Item {
            Kirigami.FormData.isSection: true
            visible: !root.iconOnly
        }

        QQC2.ComboBox {
            id: taskMaxWidth
            visible: !root.iconOnly && !root.plasmoidVertical

            Kirigami.FormData.label: i18nc("@label:listbox", "Maximum task width:")

            model: [
                i18nc("@item:inlistbox how wide a task item should be", "Narrow"),
                i18nc("@item:inlistbox how wide a task item should be", "Medium"),
                i18nc("@item:inlistbox how wide a task item should be", "Wide")
            ]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.RadioButton {
            id: forbidStripes
            Kirigami.FormData.label: root.plasmoidVertical
                ? i18nc("@label for radio button group, completes sentence: … when panel is low on space etc.", "Use multi-column view:")
                : i18nc("@label for radio button group, completes sentence: … when panel is low on space etc.", "Use multi-row view:")
            onToggled: {
                if (checked) {
                    maxStripes.value = 1
                }
            }
            text: i18nc("@option:radio Never use multi-column view for Task Manager", "Never")
        }

        QQC2.RadioButton {
            id: allowStripes
            onToggled: {
                if (checked) {
                    maxStripes.value = Math.max(2, maxStripes.value)
                }
            }
            text: i18nc("@option:radio completes sentence: Use multi-column/row view", "When panel is low on space and thick enough")
        }

        QQC2.RadioButton {
            id: forceStripes
            onToggled: {
                if (checked) {
                    maxStripes.value = Math.max(2, maxStripes.value)
                }
            }
            text: i18nc("@option:radio completes sentence: Use multi-column/row view", "Always when panel is thick enough")
        }

        QQC2.SpinBox {
            id: maxStripes
            enabled: maxStripes.value > 1
            Kirigami.FormData.label: root.plasmoidVertical
                ? i18nc("@label:spinbox maximum number of columns for tasks", "Maximum columns:")
                : i18nc("@label:spinbox maximum number of rows for tasks", "Maximum rows:")
            from: 1
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            visible: root.iconOnly
            Kirigami.FormData.label: i18nc("@label:listbox", "Spacing between icons:")

            model: [
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Small"),
                    "spacing": 0
                },
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Normal"),
                    "spacing": 1
                },
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Large"),
                    "spacing": 3
                },
            ]

            textRole: "label"

            currentIndex: switch (root.cfg_iconSpacing) {
                case 0: return 0; // Small
                case 1: return 1; // Normal
                case 3: return 2; // Large
            }
            onActivated: index => {
                root.cfg_iconSpacing = model[currentIndex]["spacing"];
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: miniTooltip
            Kirigami.FormData.label: i18nc("@label for checkbox", "Mini Tooltip:")
            text: i18nc("@option:check section Mini Tooltip", "Use compact tooltip style")
        }

        QQC2.CheckBox {
            id: useThemeDecorations
            Kirigami.FormData.label: i18nc("@label for checkbox", "Theme Decorations:")
            text: i18nc("@option:check", "Use KDE theme hover/active decorations")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: useCustomIndicator
            Kirigami.FormData.label: i18nc("@label for checkbox", "Indicator:")
            text: i18nc("@option:check", "Show custom indicator bar")
        }

        QQC2.ComboBox {
            id: indicatorPosition
            Kirigami.FormData.label: i18nc("@label:listbox", "Indicator position:")
            Layout.fillWidth: true
            enabled: useCustomIndicator.checked
            model: [
                i18nc("@item:inlistbox indicator position", "Bottom"),
                i18nc("@item:inlistbox indicator position", "Top"),
                i18nc("@item:inlistbox indicator position", "Left"),
                i18nc("@item:inlistbox indicator position", "Right")
            ]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            text: i18n("Animation")
            font.bold: true
        }

        QQC2.ComboBox {
            id: animationSpeed
            Kirigami.FormData.label: i18nc("@label:listbox", "Animation speed:")
            Layout.fillWidth: true
            model: [
                i18nc("@item:inlistbox animation speed", "Very Fast"),
                i18nc("@item:inlistbox animation speed", "Fast"),
                i18nc("@item:inlistbox animation speed", "Normal"),
                i18nc("@item:inlistbox animation speed", "Slow"),
                i18nc("@item:inlistbox animation speed", "Very Slow")
            ]
        }

        QQC2.CheckBox {
            id: hoverEffect
            text: i18n("Icon hover effect")
            checked: true
        }

        QQC2.ComboBox {
            id: hoverDirection
            Kirigami.FormData.label: i18nc("@label:listbox", "Hover direction:")
            Layout.fillWidth: true
            enabled: hoverEffect.checked
            model: [
                i18nc("@item:inlistbox hover direction", "Up"),
                i18nc("@item:inlistbox hover direction", "Down"),
                i18nc("@item:inlistbox hover direction", "Left"),
                i18nc("@item:inlistbox hover direction", "Right")
            ]
        }

        QQC2.SpinBox {
            id: iconScale
            Kirigami.FormData.label: i18n("Icon scale:")
            from: 20
            to: 150
            stepSize: 5
            value: 100
            editable: true
            textFromValue: function(val) { return val + "%" }
            valueFromText: function(txt) { return parseInt(txt) || 100 }
        }
    }
}
