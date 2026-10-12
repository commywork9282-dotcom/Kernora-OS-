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

    property string title
    property bool cfg_showWeather

    function tr(text: string): string {
        return i18nd("plasma_applet_org.kernora.widget.glance", text);
    }

    spacing: 16

    UI.Group {
        Layout.fillWidth: true

        UI.ListItem {
            title: root.tr("Show the weather")
            icon: "weather-few-clouds"
            iconStyle: "plain"
            checkable: true
            checked: root.cfg_showWeather
            onToggled: on => root.cfg_showWeather = on
        }
    }

    signal configurationChanged()

    function saveConfig(): void {
        picker.commit();
    }

    CityPicker {
        id: picker
        Layout.fillWidth: true
        visible: root.cfg_showWeather
        onChanged: root.configurationChanged()
        domain: "plasma_applet_org.kernora.widget.glance"
    }
    Item {
        Layout.fillHeight: true
    }
}
