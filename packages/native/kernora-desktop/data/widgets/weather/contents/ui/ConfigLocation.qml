/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property string title

    signal configurationChanged()

    function saveConfig(): void {
        picker.commit();
    }

    CityPicker {
        id: picker
        Layout.fillWidth: true
        onChanged: page.configurationChanged()
        domain: "plasma_applet_org.kernora.widget.weather"
    }
    Item {
        Layout.fillHeight: true
    }
}
