/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

Window {
    id: splash

    readonly property int margin: 40
    readonly property string packageName: String(startArguments[0] || "")
    readonly property string readyFile: String(startArguments[1] || "")
    readonly property var app: Process.application("waydroid." + packageName)
    property bool leaving: false

    flags: Qt.SplashScreen | Qt.FramelessWindowHint
    color: "transparent"
    width: 320 + margin * 2
    height: content.implicitHeight + 64 + margin * 2
    visible: true
    title: app.name || ""

    function leave(): void {
        if (leaving) {
            return;
        }
        leaving = true;
        exit.start();
    }

    Timer {
        interval: 150
        repeat: true
        running: splash.readyFile.length > 0 && !splash.leaving
        onTriggered: {
            if (Files.exists("file://" + splash.readyFile)) {
                Files.remove(["file://" + splash.readyFile]);
                splash.leave();
            }
        }
    }

    Timer {
        interval: 360000
        running: true
        onTriggered: splash.leave()
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
        opacity: card.opacity
        scale: card.scale
    }

    Rectangle {
        id: card
        x: splash.margin
        y: splash.margin
        width: splash.width - splash.margin * 2
        height: splash.height - splash.margin * 2
        radius: M3.classic ? M3.cornerCard : 36
        color: M3.surfaceContainerHigh
        opacity: 0
        scale: 0.9

        MSpring {
            id: enter
            dampingRatio: M3.springExpressiveDefaultDamping
            response: M3.springExpressiveDefaultResponse
            onValueChanged: {
                card.opacity = Math.min(1, value);
                card.scale = 0.9 + 0.1 * value;
            }
            Component.onCompleted: animateTo(1)
        }

        ParallelAnimation {
            id: exit
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: M3.durationShort4; easing.type: Easing.InCubic }
            NumberAnimation { target: card; property: "scale"; to: 1.04; duration: M3.durationShort4; easing.type: Easing.InCubic }
            onFinished: Qt.quit()
        }

        ColumnLayout {
            id: content
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 0

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 144
                implicitHeight: 144

                MShape {
                    id: halo
                    anchors.fill: parent
                    shape: M3.classic ? "circle" : "cookie12"
                    color: M3.primaryContainer
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 12000
                        loops: Animation.Infinite
                        running: halo.visible && M3.motionScale > 0 && !M3.classic
                    }
                }
                AppIcon {
                    anchors.centerIn: parent
                    size: 96
                    name: splash.app.icon || "org.kernora.android"
                }
            }

            MText {
                Layout.fillWidth: true
                Layout.topMargin: 20
                horizontalAlignment: Text.AlignHCenter
                role: "titleLarge"
                text: splash.app.name || ""
                elide: Text.ElideRight
            }

            MLoadingIndicator {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 16
                implicitWidth: 48
                implicitHeight: 48
                contained: true
            }
        }
    }
}
