/*
    SPDX-FileCopyrightText: 2019 Kai Uwe Broulik <kde@broulik.de>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3

import org.kernora.m3

import "../global"

RowLayout {
    id: replyRow

    Layout.maximumWidth: Globals.popupWidth
    required property ModelInterface modelInterface

    signal beginReplyRequested

    spacing: 8

    function activate() {
        replyTextField.forceActiveFocus(Qt.ActiveWindowFocusReason);
    }

    Binding {
        target: modelInterface
        property: "hasPendingReply"
        value: replyTextField.text !== ""
    }
    PlasmaComponents3.TextField {
        id: replyTextField
        Layout.fillWidth: true
        implicitHeight: 40
        leftPadding: 16
        rightPadding: 16
        font: M3.bodyLarge
        color: M3.surfaceContent
        placeholderTextColor: M3.surfaceVariantContent
        selectionColor: M3.primary
        selectedTextColor: M3.primaryContent
        placeholderText: modelInterface.replyPlaceholderText
                         || i18ndc("plasma_applet_org.kde.plasma.notifications", "Text field placeholder", "Type a reply…")
        Accessible.name: placeholderText
        background: Rectangle {
            radius: height / 2
            color: M3.surfaceContainerHighest
            border.width: replyTextField.activeFocus ? 2 : 0
            border.color: M3.primary
        }
        onAccepted: {
            if (replyButton.enabled) {
                modelInterface.replied(text);
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            visible: !modelInterface.replying
            Accessible.name: "begin reply"
            Accessible.role: Accessible.Button
            Accessible.onPressAction: replyRow.beginReplyRequested()
            onClicked: mouse => {
                mouse.accepted = true
                replyRow.beginReplyRequested()
            }
        }
    }

    MIconButton {
        id: replyButton
        variant: "filled"
        icon: modelInterface.replySubmitButtonIconName || "document-send"
        text: modelInterface.replySubmitButtonText
              || i18ndc("plasma_applet_org.kde.plasma.notifications", "@action:button", "Send")
        enabled: replyTextField.length > 0
        onClicked: modelInterface.replied(replyTextField.text)
    }
}
