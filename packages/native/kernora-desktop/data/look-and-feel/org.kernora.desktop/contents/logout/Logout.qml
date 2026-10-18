/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.coreaddons 1.0 as KCoreAddons
import org.kde.plasma.private.sessions
import org.kernora.m3
import "timer.js" as AutoTriggerTimer

Item {
    id: root
    height: screenGeometry.height
    width: screenGeometry.width
    focus: true

    signal logoutRequested()
    signal haltRequested()
    signal haltUpdateRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal rebootUpdateRequested()
    signal cancelRequested()
    signal lockScreenRequested()
    signal cancelSoftwareUpdateRequested()

    property alias backgroundColor: scrim.color

    property real timeout: 30
    property real remainingTime: root.timeout

    readonly property bool showAllOptions: sdtype === ShutdownType.ShutdownTypeDefault

    function tr(text: string): string {
        return i18nd("plasma_lookandfeel_org.kde.lookandfeel", text).replace("&", "");
    }
    function trc(context: string, text: string): string {
        return i18ndc("plasma_lookandfeel_org.kde.lookandfeel", context, text).replace("&", "");
    }

    property var currentAction: {
        switch (sdtype) {
        case ShutdownType.ShutdownTypeReboot:
            return () => softwareUpdatePending ? rebootUpdateRequested() : rebootRequested();
        case ShutdownType.ShutdownTypeHalt:
            return () => softwareUpdatePending ? haltUpdateRequested() : haltRequested();
        default:
            return () => logoutRequested();
        }
    }
    onRemainingTimeChanged: {
        if (remainingTime <= 0) {
            (currentAction)();
        }
    }
    Timer {
        id: countDown
        running: !root.showAllOptions
        repeat: true
        interval: 1000
        onTriggered: root.remainingTime--
        Component.onCompleted: AutoTriggerTimer.addCancelAutoTriggerCallback(() => countDown.running = false)
    }

    readonly property var actions: {
        const all = [];
        const halt = sdtype === ShutdownType.ShutdownTypeHalt;
        const reboot = sdtype === ShutdownType.ShutdownTypeReboot;
        const none = sdtype === ShutdownType.ShutdownTypeNone;
        if (spdMethods.SuspendState && showAllOptions) {
            all.push({ icon: "system-suspend", text: trc("Suspend to RAM", "Slee&p"), run: () => root.suspendRequested(2) });
        }
        if (spdMethods.HibernateState && showAllOptions) {
            all.push({ icon: "system-suspend-hibernate", text: tr("&Hibernate"), run: () => root.suspendRequested(4) });
        }
        if (maysd && (reboot || halt || showAllOptions)) {
            all.push({
                icon: softwareUpdatePending ? "system-reboot-update" : "system-reboot",
                text: softwareUpdatePending ? trc("@action:button Keep short", "Install Updates and Restart")
                                            : (showAllOptions ? tr("&Restart") : tr("&Restart Now")),
                run: () => softwareUpdatePending ? root.rebootUpdateRequested() : root.rebootRequested(),
                primary: reboot
            });
            if (softwareUpdatePending) {
                all.push({ icon: "system-reboot", text: showAllOptions ? tr("&Restart") : tr("&Restart Now"), run: () => root.rebootRequested() });
            }
        }
        if (maysd && (halt || showAllOptions)) {
            all.push({
                icon: softwareUpdatePending ? "system-shutdown-update" : "system-shutdown",
                text: softwareUpdatePending ? trc("@action:button Keep short", "Install Updates and Shut Down")
                                            : (showAllOptions ? tr("&Shut Down") : tr("&Shut Down Now")),
                run: () => softwareUpdatePending ? root.haltUpdateRequested() : root.haltRequested(),
                primary: halt || showAllOptions
            });
            if (softwareUpdatePending) {
                all.push({ icon: "system-shutdown", text: showAllOptions ? tr("&Shut Down") : tr("&Shut Down Now"), run: () => root.haltRequested() });
            }
        }
        if (canLogout && (none || showAllOptions)) {
            all.push({ icon: "system-log-out", text: showAllOptions ? tr("&Log Out") : tr("&Log Out Now"), run: () => root.logoutRequested(), primary: none });
        }
        return all;
    }
    property int focusIndex: Math.max(0, actions.findIndex(action => action.primary))

    Keys.onPressed: event => {
        AutoTriggerTimer.cancelAutoTrigger();
        if (event.key === Qt.Key_Escape) {
            root.cancelRequested();
        } else if (event.key === Qt.Key_Left) {
            focusIndex = Math.max(0, focusIndex - 1);
        } else if (event.key === Qt.Key_Right) {
            focusIndex = Math.min(actions.length - 1, focusIndex + 1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (actions.length > 0) {
                actions[focusIndex].run();
            }
        } else {
            return;
        }
        event.accepted = true;
    }

    KCoreAddons.KUser {
        id: user
    }
    SessionsModel {
        id: sessionsModel
        includeUnusedSessions: false
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: "black"
        opacity: 0.55
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.cancelRequested()
    }

    MultiEffect {
        source: card
        anchors.fill: card
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.4
        shadowBlur: 1.0
        shadowVerticalOffset: 8
        blurMax: 48
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.max(content.implicitWidth, 360) + 64
        height: content.implicitHeight + 64
        radius: M3.classic ? M3.cornerDialog : 36
        color: M3.surfaceContainerHigh
        scale: 0.94
        opacity: 0
        Component.onCompleted: {
            scale = 1;
            opacity = 1;
        }
        Behavior on scale { NumberAnimation { duration: M3.durationMedium4; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate } }
        Behavior on opacity { NumberAnimation { duration: M3.durationMedium2 } }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors.centerIn: parent
            spacing: 20

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16
                Item {
                    implicitWidth: 56
                    implicitHeight: 56
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: M3.primaryContainer
                        Text {
                            anchors.centerIn: parent
                            visible: face.status !== Image.Ready
                            text: (user.fullName || user.loginName).charAt(0).toUpperCase()
                            color: M3.primaryContainerContent
                            font.family: M3.typeface
                            font.pixelSize: 24
                            font.weight: Font.Medium
                        }
                    }
                    Image {
                        id: face
                        anchors.fill: parent
                        source: user.faceIconUrl
                        sourceSize: Qt.size(112, 112)
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
                ColumnLayout {
                    spacing: 2
                    MText {
                        role: "titleLarge"
                        text: user.fullName || user.loginName
                    }
                    MText {
                        role: "bodyMedium"
                        color: M3.surfaceVariantContent
                        visible: countDown.running
                        text: {
                            switch (sdtype) {
                            case ShutdownType.ShutdownTypeReboot:
                                return softwareUpdatePending
                                    ? i18ndp("plasma_lookandfeel_org.kde.lookandfeel", "Installing software updates and restarting in 1 second", "Installing software updates and restarting in %1 seconds", root.remainingTime)
                                    : i18ndp("plasma_lookandfeel_org.kde.lookandfeel", "Restarting in 1 second", "Restarting in %1 seconds", root.remainingTime);
                            case ShutdownType.ShutdownTypeNone:
                                return i18ndp("plasma_lookandfeel_org.kde.lookandfeel", "Logging out in 1 second", "Logging out in %1 seconds", root.remainingTime);
                            default:
                                return softwareUpdatePending
                                    ? i18ndp("plasma_lookandfeel_org.kde.lookandfeel", "Installing software updates and shutting down in 1 second", "Installing software updates and shutting down in %1 seconds", root.remainingTime)
                                    : i18ndp("plasma_lookandfeel_org.kde.lookandfeel", "Shutting down in 1 second", "Shutting down in %1 seconds", root.remainingTime);
                            }
                        }
                    }
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                Repeater {
                    model: root.actions
                    delegate: Tile {}
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 480
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                Note {
                    visible: sessionsModel.count > 1 && (sdtype !== ShutdownType.ShutdownTypeNone || root.showAllOptions)
                    text: i18ndp("plasma_lookandfeel_org.kde.lookandfeel",
                                 "One other user is currently logged in. If the computer is shut down or restarted, that user may lose work.",
                                 "%1 other users are currently logged in. If the computer is shut down or restarted, those users may lose work.",
                                 sessionsModel.count - 1)
                }
                Note {
                    visible: rebootToFirmwareSetup
                    text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "When restarted, the computer will enter the firmware setup screen.")
                }
                Note {
                    visible: rebootToBootLoaderMenu
                    text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "When restarted, the computer will enter the boot loader menu.")
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: cancelLabel.implicitWidth + 32
                implicitHeight: 40
                radius: M3.radius("button", 40)
                color: cancelMouse.containsMouse ? Qt.alpha(M3.primary, 0.08) : "transparent"
                MText {
                    id: cancelLabel
                    anchors.centerIn: parent
                    role: "labelLarge"
                    color: M3.primary
                    text: root.tr("&Cancel")
                }
                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelRequested()
                }
            }
        }
    }

    component Note: MText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        role: "bodySmall"
        color: M3.surfaceVariantContent
    }

    component Tile: Rectangle {
        id: tile
        required property var modelData
        required property int index
        readonly property bool primary: modelData.primary === true
        readonly property bool focused: root.focusIndex === index

        width: 128
        height: 128
        radius: M3.classic ? M3.cornerCard : Math.max(0, 28 + 12 * hoverMorph.value - (28 + 12 * hoverMorph.value - 20) * pressMorph.value)
        color: primary ? M3.primary : M3.secondaryContainer
        clip: true
        MMorph { id: hoverMorph; active: tileMouse.containsMouse || tile.focused }
        MMorph { id: pressMorph; active: tileMouse.pressed }

        readonly property color ink: primary ? M3.primaryContent : M3.secondaryContainerContent

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: tile.ink
            opacity: tileMouse.pressed ? 0.12 : (tileMouse.containsMouse || tile.focused ? 0.08 : 0)
        }
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 16
            spacing: 10
            MIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 32
                source: tile.modelData.icon
                color: tile.ink
            }
            MText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                role: "labelLarge"
                color: tile.ink
                text: tile.modelData.text
            }
        }
        Rectangle {
            visible: tile.primary && countDown.running
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            height: 4
            width: parent.width * root.remainingTime / root.timeout
            color: M3.primaryContent
            opacity: 0.4
            Behavior on width { NumberAnimation { duration: 1000 } }
        }
        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.focusIndex = tile.index
            onClicked: tile.modelData.run()
        }
    }
}
