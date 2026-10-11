/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.private.sessions 2.0
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.workspace.components 2.0 as PW
import org.kernora.m3

Item {
    id: root

    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()
    property bool viewVisible: false
    property bool suspendToRamSupported: false
    property bool suspendToDiskSupported: false
    signal suspendToDisk()
    signal suspendToRam()

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    implicitWidth: 800
    implicitHeight: 600

    function tr(text: string): string {
        return i18nd("plasma_shell_org.kde.plasma.desktop", text).replace("&", "");
    }

    function handleMessage(message: string): void {
        if (!message) {
            return;
        }
        if (!root.notification) {
            root.notification = message;
        } else if (root.notification.includes(message)) {
            root.notificationRepeated();
        } else {
            root.notification += "\n" + message;
        }
    }

    property bool passwordless: false

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) {
                return;
            }
            root.handleMessage(root.tr("Unlocking failed"));
            graceLockTimer.restart();
            notificationRemoveTimer.restart();
            shake.restart();
        }
        function onSucceeded() {
            if (authenticator.hadPrompt) {
                Qt.quit();
            } else {
                root.passwordless = true;
                unlockButton.forceActiveFocus();
            }
        }
        function onInfoMessageChanged() {
            root.handleMessage(authenticator.infoMessage);
        }
        function onErrorMessageChanged() {
            root.handleMessage(authenticator.errorMessage);
        }
        function onPromptChanged(msg) {
            root.handleMessage(authenticator.prompt);
        }
        function onPromptForSecretChanged(msg) {
            password.forceActiveFocus();
        }
    }

    onClearPassword: {
        password.text = "";
        password.forceActiveFocus();
    }

    SessionManagement {
        id: sessionManagement
    }
    Connections {
        target: sessionManagement
        function onAboutToSuspend() {
            root.clearPassword();
        }
    }

    KeyboardIndicator.KeyState {
        id: capsLock
        key: Qt.Key_CapsLock
    }

    Timer {
        id: notificationRemoveTimer
        interval: 3000
        onTriggered: root.notification = ""
    }
    Timer {
        id: graceLockTimer
        interval: 3000
        onTriggered: {
            root.clearPassword();
            authenticator.startAuthenticating();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: M3.darkScheme.surface
    }
    Loader {
        id: scene
        anchors.fill: parent
        source: "file:///usr/share/plasma/wallpapers/org.kernora.shapes/contents/ui/Scene.qml"
        property real phase: 0.4
        NumberAnimation on phase {
            from: 0.4
            to: 1.4
            duration: 420000
            loops: Animation.Infinite
        }
        onLoaded: {
            item.intro = 1;
            item.phase = Qt.binding(() => scene.phase % 1);
        }
    }
    Rectangle {
        anchors.fill: parent
        color: M3.darkScheme.surface
        opacity: lockScreen.uiVisible ? 0.55 : 0.3
        Behavior on opacity { NumberAnimation { duration: M3.durationMedium4 } }
    }

    MouseArea {
        id: lockScreen

        property bool uiVisible: false
        readonly property bool blockUI: password.text.length > 0 || root.passwordless

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        onPressed: uiVisible = true
        onPositionChanged: uiVisible = true
        onUiVisibleChanged: {
            if (blockUI) {
                fadeoutTimer.running = false;
            } else if (uiVisible) {
                fadeoutTimer.restart();
            }
            if (uiVisible) {
                password.forceActiveFocus();
            }
            authenticator.startAuthenticating();
        }
        onBlockUIChanged: {
            if (blockUI) {
                fadeoutTimer.running = false;
                uiVisible = true;
            } else {
                fadeoutTimer.restart();
            }
        }
        Keys.onEscapePressed: {
            if (uiVisible) {
                uiVisible = false;
                root.clearPassword();
            }
        }
        Keys.onPressed: event => {
            uiVisible = true;
            event.accepted = false;
        }
        Timer {
            id: fadeoutTimer
            interval: 10000
            onTriggered: {
                if (!lockScreen.blockUI) {
                    lockScreen.uiVisible = false;
                }
            }
        }

        property date now: new Date()
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: lockScreen.now = new Date()
        }
        ColumnLayout {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: lockScreen.uiVisible ? parent.height * 0.1 : parent.height * 0.3
            spacing: 0
            Behavior on y { NumberAnimation { duration: M3.durationLong2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate } }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: lockScreen.now.toLocaleTimeString(Qt.locale(), Qt.locale().name === "C" ? "HH:mm" : Locale.ShortFormat)
                color: M3.darkScheme.surfaceContent
                font.family: M3.typeface
                font.weight: Font.Light
                font.pixelSize: lockScreen.uiVisible ? 112 : 136
                renderType: Text.QtRendering
                Behavior on font.pixelSize { NumberAnimation { duration: M3.durationLong2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate } }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: lockScreen.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
                color: M3.darkScheme.surfaceContent
                font.family: M3.typeface
                font.pixelSize: 22
                renderType: Text.QtRendering
            }
        }

        KernoraMediaControls {
            id: media
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            opacity: active ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: M3.durationMedium4 } }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: media.active ? 24 + media.height + 24 : 48
            width: 56
            height: 56
            radius: 28
            color: Qt.alpha(M3.darkScheme.surfaceContainerHigh, 0.9)
            opacity: lockScreen.uiVisible ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: M3.durationMedium2 } }
            MIcon {
                anchors.centerIn: parent
                size: 24
                source: "system-lock-screen"
                color: M3.darkScheme.surfaceContent
            }
        }

        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            y: lockScreen.uiVisible ? parent.height * 0.5 - height * 0.25 : parent.height * 0.5 + 24
            width: 400
            height: cardColumn.implicitHeight + 64
            radius: M3.classic ? M3.cornerDialog : 36
            color: Qt.alpha(M3.darkScheme.surfaceContainer, 0.94)
            opacity: lockScreen.uiVisible ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: M3.durationMedium4 } }
            Behavior on y { NumberAnimation { duration: M3.durationLong2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate } }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -14; duration: 50 }
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 14; duration: 80 }
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -8; duration: 70 }
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
            }

            ColumnLayout {
                id: cardColumn
                anchors.centerIn: parent
                width: parent.width - 64
                spacing: 14

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 104
                    implicitHeight: 104
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: M3.darkScheme.primaryContainer
                        Text {
                            anchors.centerIn: parent
                            visible: face.status !== Image.Ready
                            text: kscreenlocker_userName.charAt(0).toUpperCase()
                            color: M3.darkScheme.primaryContainerContent
                            font.family: M3.typeface
                            font.pixelSize: 44
                            font.weight: Font.Medium
                        }
                    }
                    Image {
                        id: face
                        anchors.fill: parent
                        source: kscreenlocker_userImage !== ""
                            ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/") : ""
                        sourceSize: Qt.size(208, 208)
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    Rectangle {
                        id: faceMask
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                        layer.enabled: true
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: face
                        visible: face.status === Image.Ready
                        maskEnabled: true
                        maskSource: faceMask
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: kscreenlocker_userName
                    color: M3.darkScheme.surfaceContent
                    font.family: M3.typeface
                    font.pixelSize: 24
                    elide: Text.ElideRight
                    renderType: Text.QtRendering
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 10
                    visible: !root.passwordless

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: M3.radius("field", 56)
                        color: M3.darkScheme.surfaceContainerHighest
                        border.width: password.activeFocus ? 2 : 0
                        border.color: root.notification.length > 0 ? M3.darkScheme.error : M3.darkScheme.primary

                        TextInput {
                            id: password
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 24
                            anchors.rightMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            focus: true
                            enabled: !authenticator.graceLocked && !graceLockTimer.running
                            color: M3.darkScheme.surfaceContent
                            selectionColor: M3.darkScheme.primaryContainer
                            font.family: M3.typeface
                            font.pixelSize: 18
                            renderType: Text.QtRendering
                            clip: true
                            onAccepted: authenticator.respond(text)
                            onTextChanged: notificationRemoveTimer.restart()

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: password.text.length === 0
                                text: root.tr("Password")
                                color: M3.darkScheme.surfaceVariantContent
                                font: password.font
                            }
                        }
                    }
                    Rectangle {
                        implicitWidth: 56
                        implicitHeight: 56
                        radius: loginMouse.pressed && !M3.classic ? 16 : 28
                        color: M3.darkScheme.primary
                        opacity: password.enabled ? 1 : 0.5
                        Behavior on radius { NumberAnimation { duration: M3.durationShort3 } }
                        MIcon {
                            anchors.centerIn: parent
                            size: 26
                            source: "go-next"
                            color: M3.darkScheme.primaryContent
                        }
                        MouseArea {
                            id: loginMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: password.accepted()
                        }
                    }
                }

                Rectangle {
                    id: unlockButton
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.passwordless
                    implicitWidth: unlockLabel.implicitWidth + 48
                    implicitHeight: 48
                    radius: M3.radius("button", 48)
                    color: M3.darkScheme.primary
                    activeFocusOnTab: true
                    Keys.onReturnPressed: Qt.quit()
                    Keys.onEnterPressed: Qt.quit()
                    Text {
                        id: unlockLabel
                        anchors.centerIn: parent
                        text: root.tr("Unlock")
                        color: M3.darkScheme.primaryContent
                        font.family: M3.typeface
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.quit()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: text.length > 0
                    text: {
                        const parts = [];
                        if (capsLock.locked) {
                            parts.push(root.tr("Caps Lock is on"));
                        }
                        if (root.notification) {
                            parts.push(root.notification);
                        }
                        return parts.join(" • ");
                    }
                    color: root.notification.length > 0 ? M3.darkScheme.error : M3.darkScheme.surfaceVariantContent
                    font.family: M3.typeface
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                }
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 24
            spacing: 8
            opacity: lockScreen.uiVisible ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: M3.durationMedium4 } }

            PW.KeyboardLayoutSwitcher {
                id: keyboardLayouts
                acceptedButtons: Qt.NoButton
                visible: false
            }
            Chip {
                visible: keyboardLayouts.hasMultipleKeyboardLayouts
                icon: "input-keyboard"
                label: keyboardLayouts.layoutNames.shortName ? keyboardLayouts.layoutNames.shortName.toUpperCase() : ""
                onClicked: {
                    keyboardLayouts.keyboardLayout.switchToNextLayout();
                    password.forceActiveFocus();
                }
            }
            Item { Layout.fillWidth: true }
            PowerButton {
                visible: root.suspendToRamSupported
                icon: "system-suspend"
                label: root.tr("Slee&p")
                onClicked: root.suspendToRam()
            }
            PowerButton {
                visible: root.suspendToDiskSupported
                icon: "system-suspend-hibernate"
                label: root.tr("&Hibernate")
                onClicked: root.suspendToDisk()
            }
            PowerButton {
                visible: sessionManagement.canSwitchUser
                icon: "system-switch-user"
                label: root.tr("Switch &User")
                onClicked: sessionManagement.switchUser()
            }
        }
    }

    component Chip: Rectangle {
        id: chip
        property string icon
        property string label
        signal clicked()
        implicitWidth: chipRow.implicitWidth + 28
        implicitHeight: 40
        radius: 20
        color: chipMouse.containsMouse ? Qt.alpha(M3.darkScheme.surfaceContainerHigh, 0.95) : Qt.alpha(M3.darkScheme.surfaceContainer, 0.85)
        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8
            MIcon { size: 20; source: chip.icon; color: M3.darkScheme.surfaceVariantContent }
            Text { text: chip.label; color: M3.darkScheme.surfaceContent; font.family: M3.typeface; font.pixelSize: 14 }
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component PowerButton: Rectangle {
        id: button
        property string icon
        property string label
        signal clicked()
        implicitWidth: 48
        implicitHeight: 48
        radius: 24
        color: buttonMouse.containsMouse ? Qt.alpha(M3.darkScheme.surfaceContainerHighest, 0.95) : Qt.alpha(M3.darkScheme.surfaceContainerHigh, 0.85)
        Accessible.role: Accessible.Button
        Accessible.name: label
        MIcon {
            anchors.centerIn: parent
            size: 22
            source: button.icon
            color: M3.darkScheme.surfaceContent
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
        Rectangle {
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: tipText.implicitWidth + 16
            height: 28
            radius: 4
            color: M3.darkScheme.surfaceContent
            opacity: buttonMouse.containsMouse ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: M3.durationShort3 } }
            Text {
                id: tipText
                anchors.centerIn: parent
                text: button.label
                color: M3.darkScheme.surface
                font.family: M3.typeface
                font.pixelSize: 12
            }
        }
    }
}
