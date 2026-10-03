/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3

Rectangle {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholderText
    signal accepted()

    function forceActiveFocus(): void {
        input.forceActiveFocus();
    }

    implicitWidth: 320
    implicitHeight: 52
    radius: M3.radius("field", height)
    color: M3.surfaceContainerHigh
    border.width: input.activeFocus ? 2 : 0
    border.color: M3.primary

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: input.forceActiveFocus(Qt.MouseFocusReason)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 8
        spacing: 12

        MIcon {
            size: 22
            source: "search"
            color: M3.surfaceVariantContent
        }

        TextInput {
            id: input
            Layout.fillWidth: true
            font: M3.bodyLarge
            renderType: Text.QtRendering
            color: M3.surfaceContent
            selectionColor: M3.primaryContainer
            selectedTextColor: M3.primaryContainerContent
            selectByMouse: true
            clip: true
            onAccepted: root.accepted()
            Keys.onEscapePressed: event => {
                if (text.length > 0) {
                    text = "";
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }

            MText {
                anchors.fill: parent
                role: "bodyLarge"
                text: root.placeholderText
                color: M3.surfaceVariantContent
                visible: input.text.length === 0
            }
        }

        IconButton {
            visible: input.text.length > 0
            iconName: "edit-clear"
            text: (typeof i18nd === "function" ? i18nd("kernora-ui", "Clear") : qsTr("Clear"))
            onClicked: {
                input.text = "";
                input.forceActiveFocus();
            }
        }
    }
}
