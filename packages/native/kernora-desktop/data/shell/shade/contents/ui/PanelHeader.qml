/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import "m3"

RowLayout {
    id: header

    property string title
    property bool switchVisible: false
    property bool switchChecked: false

    signal back()
    signal switched(bool checked)

    spacing: 8

    MIconButton {
        icon: "go-previous"
        text: i18n("Back")
        onClicked: header.back()
    }
    MText {
        Layout.fillWidth: true
        role: "titleLarge"
        text: header.title
        elide: Text.ElideRight
    }
    MSwitch {
        visible: header.switchVisible
        Layout.rightMargin: 8
        checked: header.switchChecked
        text: header.title
        onToggled: header.switched(!header.switchChecked)
    }
}
