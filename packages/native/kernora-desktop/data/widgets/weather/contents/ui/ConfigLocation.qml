/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    property string title

    CityPicker {
        Layout.fillWidth: true
        domain: "plasma_applet_org.kernora.widget.weather"
    }
}
