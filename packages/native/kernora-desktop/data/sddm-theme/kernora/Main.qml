/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kernora.m3

Rectangle {
    id: root

    color: M3.darkScheme.surface

    readonly property bool russian: Qt.locale().name.startsWith("ru")
    function tr(en: string, ru: string): string {
        return russian ? ru : en;
    }

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string failure: ""
    property bool busy: false
    property real exit: 0

    property bool open: false
    readonly property real reveal: Math.max(0, Math.min(1, revealSpring.value))
    readonly property real travel: Math.max(240, height * 0.4)
    property bool hinting: false

    function settle(show: bool, velocity: real): void {
        open = show;
        revealSpring.animateTo(show ? 1 : 0, velocity);
        if (show) {
            password.forceActiveFocus();
            idleTimer.restart();
        }
    }

    function endPeek(): void {
        if (!open && !swipe.dragging) {
            revealSpring.animateTo(0, 0);
        }
    }

    MSpring {
        id: revealSpring
        dampingRatio: 0.82
        response: 0.42
    }

    SequentialAnimation {
        id: nudge
        ScriptAction { script: revealSpring.animateTo(0.08, 0) }
        PauseAnimation { duration: 180 }
        ScriptAction { script: root.endPeek() }
    }

    Timer {
        id: hintTimer
        interval: 3000
        onTriggered: root.hinting = false
    }

    Timer {
        id: idleTimer
        interval: 15000
        onTriggered: {
            if (password.text.length === 0 && !root.busy) {
                root.settle(false, 0);
            }
        }
    }

    Keys.onEscapePressed: {
        password.text = "";
        root.settle(false, 0);
    }

    NumberAnimation {
        id: leave
        target: root
        property: "exit"
        to: 1
        duration: 320
        easing.type: Easing.Bezier
        easing.bezierCurve: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    }

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

    Timer {
        id: clearTimer
        interval: 400
        onTriggered: {
            password.text = "";
            password.forceActiveFocus();
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.failure = root.tr("Wrong password. Try again.", "Неверный пароль. Попробуйте ещё раз.");
            echo.shake();
            shake.restart();
            clearTimer.restart();
        }
        function onLoginSucceeded() {
            leave.start();
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
                readonly property real loop: status === Loader.Ready && item.loopSeconds > 0 ? item.loopSeconds : 180
                readonly property real offset: (parent.x / 7919 + parent.y / 104729) % 1
                property real phase: 0
                function clockPhase(): real {
                    return (offset + Date.now() / 1000 / loop) % 1;
                }
                Timer {
                    interval: 33
                    repeat: true
                    running: config.background !== "still" && scene.status === Loader.Ready
                    onTriggered: scene.phase = scene.clockPhase()
                }
                onLoaded: {
                    item.intro = 1;
                    scene.phase = scene.clockPhase();
                    item.phase = Qt.binding(() => scene.phase);
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
                color: M3.darkScheme.surface
                opacity: (0.25 + 0.2 * root.reveal) * (1 - root.exit)
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

    MouseArea {
        id: swipe

        property bool dragging: false
        property real pressY: 0
        property real pressReveal: 0
        property real lastY: 0
        property double lastTime: 0
        property real flick: 0

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onPressed: mouse => {
            pressY = mouse.y;
            lastY = mouse.y;
            lastTime = Date.now();
            pressReveal = root.reveal;
            flick = 0;
            dragging = false;
        }
        onPositionChanged: mouse => {
            if (!pressed) {
                if (!root.open) {
                    root.hinting = true;
                    hintTimer.restart();
                    if (!nudge.running && revealSpring.value < 0.01) {
                        nudge.start();
                    }
                }
                return;
            }
            const distance = pressY - mouse.y;
            if (!dragging && Math.abs(distance) > 8) {
                dragging = true;
                nudge.stop();
            }
            if (dragging) {
                revealSpring.jumpTo(Math.max(0, Math.min(1, pressReveal + distance / root.travel)));
                const now = Date.now();
                flick = (lastY - mouse.y) / Math.max(1, now - lastTime) * 1000;
                lastY = mouse.y;
                lastTime = now;
            }
        }
        onReleased: {
            if (!dragging) {
                root.settle(true, 0);
                return;
            }
            dragging = false;
            root.settle(flick > 600 || (flick > -600 && root.reveal > 0.4), flick / root.travel);
        }
        onCanceled: {
            dragging = false;
            root.settle(root.reveal > 0.4, 0);
        }
        onWheel: wheel => {
            if (root.open) {
                return;
            }
            const delta = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 2;
            revealSpring.jumpTo(Math.max(0, Math.min(1, root.reveal + Math.abs(delta) / root.travel)));
            wheelSettle.restart();
        }
        Timer {
            id: wheelSettle
            interval: 160
            onTriggered: root.settle(root.reveal > 0.3, 0)
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * (0.3 - 0.2 * root.reveal)
        spacing: 0
        scale: 1 - 0.18 * root.reveal
        transformOrigin: Item.Top
        opacity: 1 - root.exit
        transform: Translate { y: -64 * root.exit }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.now.toLocaleTimeString(Qt.locale(), Qt.locale().name === "C" ? "HH:mm" : Locale.ShortFormat)
            color: M3.darkScheme.surfaceContent
            font.family: "Roboto"
            font.weight: Font.Light
            font.pixelSize: 136
            renderType: Text.QtRendering
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
            color: M3.darkScheme.surfaceContent
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
            readonly property string picture: icon.indexOf("/faces/.face.icon") >= 0 ? "" : icon.startsWith("/") ? "file://" + icon : icon
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        spacing: 12
        opacity: Math.max(0, 1 - 2.5 * root.reveal) * (1 - root.exit)
        visible: opacity > 0
        transform: Translate { y: -root.travel * 0.5 * root.reveal }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.tr("Swipe up or start typing", "Проведите вверх или начните вводить пароль")
            color: M3.darkScheme.surfaceContent
            font.family: "Roboto"
            font.pixelSize: 15
            font.weight: Font.Medium
            opacity: root.hinting ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 56
            height: 56
            radius: 28
            color: Qt.alpha(M3.surfaceContainerHigh, 0.9)
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 24
                height: 24
                source: Qt.resolvedUrl("icons/lock.svg")
                isMask: true
                color: M3.surfaceContent
            }
        }
    }

    Rectangle {
        id: card
        readonly property bool shown: root.reveal > 0.5
        anchors.centerIn: parent
        anchors.verticalCenterOffset: parent.height * 0.08 + (1 - root.reveal) * root.travel * 0.6
        width: 400
        height: cardColumn.implicitHeight + 64
        radius: 36
        color: Qt.alpha(M3.surfaceContainer, 0.94)
        opacity: Math.max(0, Math.min(1, (root.reveal - 0.25) / 0.55)) * (1 - root.exit)
        transform: Translate { y: -96 * root.exit }

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
                    color: M3.primaryContainer
                    Text {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        text: parent.parent.user ? parent.parent.user.displayName.charAt(0).toUpperCase() : ""
                        color: M3.primaryContainerContent
                        font.family: "Roboto"
                        font.pixelSize: 44
                        font.weight: Font.Medium
                    }
                }
                Image {
                    id: face
                    anchors.fill: parent
                    source: parent.user ? parent.user.picture : ""
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
                color: M3.surfaceContent
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
                    color: M3.surfaceContainerHighest
                    border.width: password.activeFocus ? 2 : 0
                    border.color: root.failure.length > 0 ? M3.error : M3.primary

                    TextInput {
                        id: password
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 24
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        echoMode: TextInput.NoEcho
                        cursorDelegate: Item {}
                        focus: true
                        enabled: !root.busy
                        color: M3.surfaceContent
                        selectionColor: M3.primaryContainer
                        font.family: "Roboto"
                        font.pixelSize: 18
                        renderType: Text.QtRendering
                        clip: true
                        onAccepted: root.login()
                        onTextChanged: {
                            root.failure = "";
                            if (text.length > 0 && !root.open) {
                                root.settle(true, 0);
                            }
                            idleTimer.restart();
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: password.text.length === 0
                            text: root.tr("Password", "Пароль")
                            color: M3.surfaceVariantContent
                            font: password.font
                        }
                    }
                    MShapeEcho {
                        id: echo
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 20
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        count: password.text.length
                        color: M3.primary
                        size: 24
                        spacing: 9
                    }
                }
                Rectangle {
                    implicitWidth: 56
                    implicitHeight: 56
                    radius: loginMouse.pressed ? 16 : 28
                    color: M3.primary
                    opacity: root.busy ? 0.5 : 1
                    Behavior on radius { NumberAnimation { duration: 150 } }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        source: Qt.resolvedUrl("icons/login.svg")
                        isMask: true
                        color: M3.primaryContent
                    }
                    MouseArea {
                        id: loginMouse
                        enabled: card.shown
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
                color: root.failure.length > 0 ? M3.error : M3.surfaceVariantContent
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
                        color: index === root.userIndex ? M3.secondaryContainer : "transparent"
                        border.width: index === root.userIndex ? 0 : 1
                        border.color: M3.outline
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: realName.length > 0 ? realName : name
                            color: index === root.userIndex ? M3.secondaryContainerContent : M3.surfaceVariantContent
                            font.family: "Roboto"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: card.shown
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
        opacity: Math.max(0, Math.min(1, (root.reveal - 0.4) / 0.6)) * (1 - root.exit)
        visible: opacity > 0

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
            color: M3.darkScheme.surfaceVariantContent
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
        color: chipMouse.containsMouse ? Qt.alpha(M3.surfaceContainerHigh, 0.95) : Qt.alpha(M3.surfaceContainer, 0.85)
        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8
            Kirigami.Icon { source: Qt.resolvedUrl(chip.icon); isMask: true; color: M3.surfaceVariantContent; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
            Text { text: chip.label; color: M3.surfaceContent; font.family: "Roboto"; font.pixelSize: 14 }
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
        color: powerMouse.containsMouse ? Qt.alpha(M3.surfaceContainerHigh, 0.95) : Qt.alpha(M3.surfaceContainer, 0.85)
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 24
            height: 24
            source: Qt.resolvedUrl(button.icon)
            isMask: true
            color: M3.surfaceContent
        }
        Rectangle {
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            visible: powerMouse.containsMouse
            width: tip.implicitWidth + 16
            height: 28
            radius: 6
            color: M3.inverseSurface
            Text {
                id: tip
                anchors.centerIn: parent
                text: button.label
                color: M3.inverseOnSurface
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

    Component.onCompleted: {
        const colour = String(config.colour || "");
        M3.colourOverride = /^[a-z]+(-[a-z]+)*$/.test(colour) ? colour : "";
        M3.darkOverride = config.mode !== "light";
        M3.reloadGeneration();
        password.forceActiveFocus();
    }
}
