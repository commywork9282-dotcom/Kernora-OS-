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
    property string cfg_style

    function tr(text: string): string {
        return i18nd("plasma_applet_org.kernora.widget.clock", text);
    }

    UI.Group {
        Layout.fillWidth: true
        title: root.tr("Style")

        Repeater {
            model: [
                { value: "bold", title: root.tr("Bold digits"), subtitle: root.tr("Hours above minutes, in the colours of the theme") },
                { value: "analog", title: root.tr("Analog"), subtitle: root.tr("Hands on a Material shape") }
            ]
            delegate: UI.RadioRow {
                required property var modelData
                width: parent ? parent.width : implicitWidth
                title: modelData.title
                subtitle: modelData.subtitle
                checked: root.cfg_style === modelData.value
                onClicked: root.cfg_style = modelData.value
            }
        }
    }
}
