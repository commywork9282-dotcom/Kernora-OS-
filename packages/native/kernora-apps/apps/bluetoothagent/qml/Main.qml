/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui

QQC2.ApplicationWindow {
    id: window

    readonly property string kind: agent.kind
    readonly property bool entering: kind === "enterPin" || kind === "enterPasskey"
    readonly property bool showing: kind === "showPin" || kind === "showPasskey"
    readonly property bool confirming: kind === "confirmPasskey" || kind === "authorizePairing" || kind === "authorizeService"
    readonly property bool valid: kind === "enterPin" ? /^[0-9A-Za-z]{1,16}$/.test(entry.text)
        : kind === "enterPasskey" ? /^[0-9]{1,6}$/.test(entry.text) : true

    width: 400
    height: content.implicitHeight + 48
    minimumWidth: 360
    maximumHeight: height
    minimumHeight: height
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint
    color: M3.surfaceContainerHigh
    title: i18n("Bluetooth pairing")
    visible: false

    Connections {
        target: agent
        function onChanged(): void {
            entry.text = "";
            if (!agent.active) {
                window.hide();
                return;
            }
            window.show();
            window.raise();
            window.requestActivate();
            if (window.entering) {
                entry.forceActiveFocus();
            }
        }
    }
    onClosing: close => {
        if (agent.active) {
            agent.decline();
        }
    }

    function heading(): string {
        switch (kind) {
        case "enterPin":
        case "enterPasskey":
            return i18n("Enter the pairing code");
        case "showPin":
        case "showPasskey":
            return i18n("Type this code on %1", agent.deviceName);
        case "confirmPasskey":
            return i18n("Does the code match?");
        case "authorizePairing":
            return i18n("Pair with %1?", agent.deviceName);
        case "authorizeService":
            return i18n("Allow %1 to connect?", agent.deviceName);
        }
        return "";
    }

    function explanation(): string {
        switch (kind) {
        case "enterPin":
            return i18n("%1 asks for a PIN. It is often 0000 or 1234, or it is shown on the device or in its manual.", agent.deviceName);
        case "enterPasskey":
            return i18n("Type the 6-digit code that %1 shows.", agent.deviceName);
        case "showPin":
        case "showPasskey":
            return i18n("Then press Enter on the device, if it asks.");
        case "confirmPasskey":
            return i18n("Make sure %1 shows the same code, then pair.", agent.deviceName);
        case "authorizePairing":
            return i18n("%1 wants to pair with this computer.", agent.deviceAddress);
        case "authorizeService":
            return i18n("The device is not trusted yet.");
        }
        return "";
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        MIcon {
            Layout.alignment: Qt.AlignHCenter
            size: 24
            source: "preferences-system-bluetooth"
            color: M3.secondary
        }
        MText {
            Layout.fillWidth: true
            role: "headlineSmall"
            text: window.heading()
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            horizontalAlignment: Text.AlignHCenter
        }
        MText {
            Layout.fillWidth: true
            role: "bodyMedium"
            text: window.explanation()
            color: M3.surfaceVariantContent
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            horizontalAlignment: Text.AlignHCenter
        }
        MText {
            Layout.alignment: Qt.AlignHCenter
            visible: agent.code.length > 0
            role: "displaySmall"
            text: agent.code.replace(/^(\d{3})(\d{3})$/, "$1 $2")
            color: M3.primary
            font.letterSpacing: 4
        }
        Row {
            Layout.alignment: Qt.AlignHCenter
            visible: agent.kind === "showPasskey"
            spacing: 8
            Repeater {
                model: 6
                delegate: Rectangle {
                    required property int index
                    width: 10
                    height: 10
                    radius: 5
                    color: index < agent.entered ? M3.primary : M3.surfaceContainerHighest
                }
            }
        }
        InputField {
            id: entry
            Layout.fillWidth: true
            visible: window.entering
            label: agent.kind === "enterPasskey" ? i18n("Code") : i18n("PIN")
            input.inputMethodHints: agent.kind === "enterPasskey" ? Qt.ImhDigitsOnly : Qt.ImhNoPredictiveText
            input.maximumLength: agent.kind === "enterPasskey" ? 6 : 16
            onAccepted: {
                if (window.valid) {
                    agent.respond(entry.text);
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8
            Item { Layout.fillWidth: true }
            QQC2.Button {
                text: window.showing ? i18n("Cancel pairing") : i18n("Cancel")
                flat: true
                onClicked: agent.decline()
            }
            QQC2.Button {
                visible: !window.showing
                text: agent.kind === "authorizeService" ? i18n("Allow") : i18n("Pair")
                highlighted: true
                enabled: window.valid
                onClicked: agent.respond(entry.text)
            }
        }
    }
}
