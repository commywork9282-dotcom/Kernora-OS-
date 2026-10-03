/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui as UI

ColumnLayout {
    id: root

    property real cfg_Speed
    property bool cfg_PauseWhenCovered
    property bool cfg_ColourCycle

    function tr(text: string): string {
        return i18nd("plasma_wallpaper_org.kernora.shapes", text);
    }

    spacing: 0

    Column {
        Layout.fillWidth: true
        spacing: M3.classic ? 0 : 2

        UI.SliderItem {
            width: parent.width
            title: root.tr("Motion")
            icon: "speedometer"
            from: 0.25
            to: 2.0
            stepSize: 0.05
            value: root.cfg_Speed
            formatValue: v => v < 0.7 ? root.tr("Calm") : v > 1.4 ? root.tr("Lively") : root.tr("Moderate")
            onMoved: v => root.cfg_Speed = v
        }
        UI.ListItem {
            title: root.tr("Changing colours")
            subtitle: root.tr("Change colour combinations over time")
            icon: "color-management"
            checkable: true
            checked: root.cfg_ColourCycle
            onToggled: checked => root.cfg_ColourCycle = checked
        }
        UI.ListItem {
            title: root.tr("Save energy")
            subtitle: root.tr("Pause while a window covers the desktop")
            icon: "battery-full"
            checkable: true
            checked: root.cfg_PauseWhenCovered
            onToggled: checked => root.cfg_PauseWhenCovered = checked
        }
    }
}
