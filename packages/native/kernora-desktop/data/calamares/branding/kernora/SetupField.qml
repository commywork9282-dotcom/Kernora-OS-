/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import org.kernora.m3

Item {
    id: field

    property string symbol
    property string label
    property alias text: input.text
    property alias input: input
    property bool password: false
    property bool first: false
    property bool last: false
    property string errorText
    property string supportingText
    property bool revealed: false

    readonly property bool focused: input.activeFocus
    readonly property bool hasError: errorText.length > 0
    readonly property bool raised: focused || input.text.length > 0
    readonly property string note: hasError ? errorText : supportingText

    signal accepted()

    function forceActiveFocus(): void {
        input.forceActiveFocus();
    }

    width: parent ? parent.width : 400
    height: 72 + (note.length > 0 ? noteText.implicitHeight + 8 : 0)

    Rectangle {
        id: box

        width: parent.width
        height: 72
        color: field.focused ? M3.surfaceContainerHighest : M3.surfaceContainerHigh
        topLeftRadius: field.first ? 24 : 6
        topRightRadius: field.first ? 24 : 6
        bottomLeftRadius: field.last ? 24 : 6
        bottomRightRadius: field.last ? 24 : 6
        border.width: field.focused || field.hasError ? 2 : 0
        border.color: field.hasError ? M3.error : M3.primary

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onPressed: input.forceActiveFocus(Qt.MouseFocusReason)
        }

        MIcon {
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            size: 24
            source: Qt.resolvedUrl("symbols/" + field.symbol + "_24px.svg")
            color: field.hasError ? M3.error : field.focused ? M3.primary : M3.surfaceVariantContent
        }

        MText {
            x: 60
            y: field.raised ? 14 : (box.height - implicitHeight) / 2
            role: field.raised ? "bodySmall" : "bodyLarge"
            text: field.label
            color: field.hasError ? M3.error : field.focused ? M3.primary : M3.surfaceVariantContent

            Behavior on y {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }

        TextInput {
            id: input

            x: 60
            y: 34
            width: parent.width - x - (field.password ? 72 : 24)
            height: 26
            visible: field.raised
            font: M3.bodyLarge
            renderType: Text.QtRendering
            color: M3.surfaceContent
            selectionColor: M3.primaryContainer
            selectedTextColor: M3.primaryContainerContent
            selectByMouse: true
            clip: true
            echoMode: field.password && !field.revealed ? TextInput.Password : TextInput.Normal
            passwordCharacter: "●"
            verticalAlignment: TextInput.AlignVCenter
            onAccepted: field.accepted()
        }

        Item {
            visible: field.password
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40

            Rectangle {
                anchors.fill: parent
                radius: 20
                color: M3.surfaceContainerHigh
            }

            MIcon {
                anchors.centerIn: parent
                size: 22
                source: Qt.resolvedUrl("symbols/" + (field.revealed ? "visibility_off" : "visibility") + "_24px.svg")
                color: M3.surfaceVariantContent
            }

            MStateLayer {
                anchors.fill: parent
                radius: 20
                color: M3.surfaceContent
                hovered: eyeMouse.containsMouse
                pressed: eyeMouse.pressed
            }

            MouseArea {
                id: eyeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: field.revealed = !field.revealed
            }
        }
    }

    MText {
        id: noteText

        visible: field.note.length > 0
        x: 24
        y: box.height + 6
        width: parent.width - 48
        role: "bodySmall"
        text: field.note
        color: field.hasError ? M3.error : M3.surfaceVariantContent
        wrapMode: Text.Wrap
    }
}
