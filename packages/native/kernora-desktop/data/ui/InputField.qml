/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3

ColumnLayout {
    id: root

    property string label
    property alias text: input.text
    property alias input: input
    property string supportingText
    property string errorText
    property bool password: false
    property string icon
    signal accepted()

    readonly property bool floated: input.activeFocus || input.text.length > 0
    readonly property bool hasError: errorText.length > 0
    property bool revealed: false

    spacing: 4

    function forceActiveFocus(): void {
        input.forceActiveFocus();
    }

    Rectangle {
        id: field
        Layout.fillWidth: true
        implicitHeight: 56
        radius: M3.classic ? M3.cornerField : 12
        color: M3.surfaceContainerHighest
        border.width: input.activeFocus || root.hasError ? 2 : 0
        border.color: root.hasError ? M3.error : M3.primary

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onPressed: input.forceActiveFocus(Qt.MouseFocusReason)
        }

        MIcon {
            id: leading
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon.length > 0
            size: 22
            source: root.icon
        }

        MText {
            id: floating
            x: root.icon.length > 0 ? 44 : 16
            y: root.floated ? 8 : (field.height - height) / 2
            role: root.floated ? "bodySmall" : "bodyLarge"
            text: root.label
            color: root.hasError ? M3.error : (input.activeFocus ? M3.primary : M3.surfaceVariantContent)
            Behavior on y { NumberAnimation { duration: M3.durationShort4; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingStandard } }
        }

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.right: reveal.visible ? reveal.left : parent.right
            anchors.leftMargin: root.icon.length > 0 ? 44 : 16
            anchors.rightMargin: 12
            y: root.label.length > 0 ? 26 : (field.height - height) / 2
            font: M3.bodyLarge
            renderType: Text.QtRendering
            color: M3.surfaceContent
            selectionColor: M3.primaryContainer
            selectedTextColor: M3.primaryContainerContent
            echoMode: root.password && !root.revealed ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            selectByMouse: true
            clip: true
            onAccepted: root.accepted()
        }

        IconButton {
            id: reveal
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: root.password
            iconName: root.revealed ? "view-hidden" : "view-visible"
            text: root.revealed ? (typeof i18nd === "function" ? i18nd("kernora-ui", "Hide password") : qsTr("Hide password")) : (typeof i18nd === "function" ? i18nd("kernora-ui", "Show password") : qsTr("Show password"))
            focusPolicy: Qt.NoFocus
            onClicked: root.revealed = !root.revealed
        }

    }

    MText {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        role: "bodySmall"
        text: root.hasError ? root.errorText : root.supportingText
        visible: text.length > 0
        color: root.hasError ? M3.error : M3.surfaceVariantContent
        wrapMode: Text.Wrap
    }
}
