/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "palette.js" as P

Rectangle {
    id: root

    color: P.surface

    readonly property bool russian: Qt.locale().name.startsWith("ru")
    function tr(en: string, ru: string): string {
        return russian ? ru : en;
    }

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string failure: ""
    property bool busy: false

    readonly property var user: users.count > userIndex ? users.objectAt(userIndex) : null
    function login(): void {
        const user = root.user;
        if (!user || busy) {
            return;
        }
        busy = true;
        failure = "";
        sddm.login(user.userName, password.text, sessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.failure = root.tr("Wrong password. Try again.", "Неверный пароль. Попробуйте ещё раз.");
            password.selectAll();
            password.forceActiveFocus();
            shake.restart();
        }
        function onLoginSucceeded() {
            root.busy = false;
        }
    }

    Repeater {
        model: screenModel
        delegate: Item {
            required property rect geometry
            x: geometry.x
            y: geometry.y
            width: geometry.width
            height: geometry.height

            readonly property string wallpaper: /^org\.kernora\.[a-z]+$/.test(config.wallpaper || "") ? config.wallpaper : "org.kernora.shapes"
            readonly property bool picture: config.wallpaper === "org.kde.image" && (config.wallpaperImage || "").length > 0

            Loader {
                id: scene
                anchors.fill: parent
                active: !parent.picture || backdrop.status === Image.Error
                source: "file:///usr/share/plasma/wallpapers/" + (parent.picture ? "org.kernora.shapes" : parent.wallpaper) + "/contents/ui/Scene.qml"
                property real phase: 0.4
                NumberAnimation on phase {
                    id: drift
                    running: config.background !== "still" && scene.status === Loader.Ready
                    from: 0.4
                    to: 1.4
                    duration: 420000
                    loops: Animation.Infinite
                }
                onLoaded: {
                    item.intro = 1;
                    item.phase = Qt.binding(() => scene.phase % 1);
                    if (item.loopSeconds > 0) {
                        drift.duration = item.loopSeconds * 1000;
                    }
                }
                onStatusChanged: {
                    if (status === Loader.Error && source.toString().indexOf("org.kernora.shapes") < 0) {
                        source = "file:///usr/share/plasma/wallpapers/org.kernora.shapes/contents/ui/Scene.qml";
                    }
                }
            }
            Image {
                id: backdrop
                anchors.fill: parent
                visible: parent.picture && status === Image.Ready
                source: parent.picture ? "file://" + config.wallpaperImage : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: parent.width
            }
            Rectangle {
                anchors.fill: parent
                color: P.surface
                opacity: 0.35
            }
        }
    }

    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.1
        spacing: 0
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.now.toLocaleTimeString(Qt.locale(), Qt.locale().name === "C" ? "HH:mm" : Locale.ShortFormat)
            color: P.surfaceContent
            font.family: "Roboto"
            font.weight: Font.Light
            font.pixelSize: 112
            renderType: Text.QtRendering
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
            color: P.surfaceContent
            font.family: "Roboto"
            font.pixelSize: 22
            renderType: Text.QtRendering
        }
    }

    Instantiator {
        id: users
        model: userModel
        delegate: QtObject {
            required property string name
            required property string realName
            required property string icon
            readonly property string userName: name
            readonly property string displayName: realName.length > 0 ? realName : name
            readonly property string picture: icon
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        anchors.verticalCenterOffset: parent.height * 0.08
        width: 400
        height: cardColumn.implicitHeight + 64
        radius: 36
        color: Qt.alpha(P.surfaceContainer, 0.94)

        SequentialAnimation {
            id: shake
            loops: 1
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
                readonly property var user: root.user
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: P.primaryContainer
                    Text {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        text: parent.parent.user ? parent.parent.user.displayName.charAt(0).toUpperCase() : ""
                        color: P.primaryContainerContent
                        font.family: "Roboto"
                        font.pixelSize: 44
                        font.weight: Font.Medium
                    }
                }
                Image {
                    id: face
                    anchors.fill: parent
                    source: parent.user && parent.user.picture.length > 0 ? "file://" + parent.user.picture : ""
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
                text: root.user ? root.user.displayName : ""
                color: P.surfaceContent
                font.family: "Roboto"
                font.pixelSize: 24
                elide: Text.ElideRight
                renderType: Text.QtRendering
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 56
                    radius: 28
                    color: P.surfaceContainerHighest
                    border.width: password.activeFocus ? 2 : 0
                    border.color: root.failure.length > 0 ? P.error : P.primary

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
                        enabled: !root.busy
                        color: P.surfaceContent
                        selectionColor: P.primaryContainer
                        font.family: "Roboto"
                        font.pixelSize: 18
                        renderType: Text.QtRendering
                        clip: true
                        onAccepted: root.login()
                        onTextChanged: root.failure = ""

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: password.text.length === 0
                            text: root.tr("Password", "Пароль")
                            color: P.surfaceVariantContent
                            font: password.font
                        }
                    }
                }
                Rectangle {
                    implicitWidth: 56
                    implicitHeight: 56
                    radius: loginMouse.pressed ? 16 : 28
                    color: P.primary
                    opacity: root.busy ? 0.5 : 1
                    Behavior on radius { NumberAnimation { duration: 150 } }
                    Image {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        sourceSize: Qt.size(52, 52)
                        source: "icons/login.svg"
                    }
                    MouseArea {
                        id: loginMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.login()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: text.length > 0
                text: root.failure.length > 0 ? root.failure
                    : keyboard.capsLock ? root.tr("Caps Lock is on", "Включён Caps Lock") : ""
                color: root.failure.length > 0 ? P.error : P.surfaceVariantContent
                font.family: "Roboto"
                font.pixelSize: 14
                wrapMode: Text.Wrap
            }

            Flow {
                Layout.alignment: Qt.AlignHCenter
                visible: userModel.count > 1
                spacing: 8
                Repeater {
                    model: userModel
                    delegate: Rectangle {
                        required property int index
                        required property string name
                        required property string realName
                        implicitWidth: chipText.implicitWidth + 28
                        implicitHeight: 34
                        radius: 17
                        color: index === root.userIndex ? P.secondaryContainer : "transparent"
                        border.width: index === root.userIndex ? 0 : 1
                        border.color: P.outline
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: realName.length > 0 ? realName : name
                            color: index === root.userIndex ? P.secondaryContainerContent : P.surfaceVariantContent
                            font.family: "Roboto"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.userIndex = index;
                                password.text = "";
                                password.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 8

        Chip {
            visible: sessionModel.rowCount() > 1
            icon: "icons/session.svg"
            label: sessionNames.count > 0 && sessionNames.objectAt(root.sessionIndex) ? sessionNames.objectAt(root.sessionIndex).label : ""
            onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount()
        }
        Instantiator {
            id: sessionNames
            model: sessionModel
            delegate: QtObject {
                required property string name
                readonly property string label: name.replace("Plasma (Wayland)", "Kernora").replace(/\bPlasma\b/, "Kernora")
            }
        }
        Chip {
            visible: keyboard.layouts.length > 1
            icon: "icons/keyboard.svg"
            label: keyboard.layouts.length > 0 ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase() : ""
            onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
        }
        Item { Layout.fillWidth: true }
        Text {
            text: sddm.hostName
            color: P.surfaceVariantContent
            font.family: "Roboto"
            font.pixelSize: 14
            Layout.rightMargin: 8
        }
        PowerButton { visible: sddm.canSuspend; icon: "icons/suspend.svg"; label: root.tr("Sleep", "Сон"); onClicked: sddm.suspend() }
        PowerButton { visible: sddm.canReboot; icon: "icons/reboot.svg"; label: root.tr("Restart", "Перезагрузка"); onClicked: sddm.reboot() }
        PowerButton { visible: sddm.canPowerOff; icon: "icons/shutdown.svg"; label: root.tr("Shut down", "Выключение"); onClicked: sddm.powerOff() }
    }

    component Chip: Rectangle {
        id: chip
        property string icon
        property string label
        signal clicked()
        implicitWidth: chipRow.implicitWidth + 28
        implicitHeight: 40
        radius: 20
        color: chipMouse.containsMouse ? Qt.alpha(P.surfaceContainerHigh, 0.95) : Qt.alpha(P.surfaceContainer, 0.85)
        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8
            Image { source: chip.icon; sourceSize: Qt.size(40, 40); Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
            Text { text: chip.label; color: P.surfaceContent; font.family: "Roboto"; font.pixelSize: 14 }
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
        color: powerMouse.containsMouse ? Qt.alpha(P.surfaceContainerHigh, 0.95) : Qt.alpha(P.surfaceContainer, 0.85)
        Image {
            anchors.centerIn: parent
            width: 24
            height: 24
            sourceSize: Qt.size(48, 48)
            source: button.icon
        }
        Rectangle {
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            visible: powerMouse.containsMouse
            width: tip.implicitWidth + 16
            height: 28
            radius: 6
            color: P.inverseSurface
            Text {
                id: tip
                anchors.centerIn: parent
                text: button.label
                color: P.inverseOnSurface
                font.family: "Roboto"
                font.pixelSize: 13
            }
        }
        MouseArea {
            id: powerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
