/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import "m3"

ColumnLayout {
    id: panel

    required property QtObject backend
    signal back()
    signal requestClose()

    spacing: 12

    Keyboards.KeyboardLayout {
        id: keyboard
    }

    PanelHeader {
        Layout.fillWidth: true
        title: i18n("Keyboard")
        onBack: panel.back()
    }

    PanelGroup {
        Layout.fillWidth: true

        Repeater {
            model: keyboard.layoutsList
            delegate: PanelRow {
                required property var modelData
                required property int index
                width: parent.width
                icon: "input-keyboard"
                title: modelData.longName || modelData.displayName || modelData.shortName
                subtitle: String(modelData.displayName || modelData.shortName).toUpperCase()
                active: keyboard.layout === index
                onClicked: keyboard.layout = index
            }
        }
    }

    MButton {
        Layout.alignment: Qt.AlignRight
        variant: "tonal"
        icon: "configure"
        text: i18n("Keyboard settings")
        onClicked: {
            panel.backend.openSettings("input");
            panel.requestClose();
        }
    }
}
