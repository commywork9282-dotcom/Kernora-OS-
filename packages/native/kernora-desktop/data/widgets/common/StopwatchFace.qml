/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kernora.m3

Item {
    id: face

    property real elapsed: 0
    property bool running: false
    property int laps: 0
    property bool interactive: true
    property string lapText

    signal toggled()
    signal lapped()
    signal cleared()

    readonly property bool dark: M3.dark
    readonly property bool started: running || elapsed > 0
    readonly property real side: Math.min(width, height)

    readonly property color surface: dark ? M3.accent2_800 : M3.accent1_50
    readonly property color digits: dark ? M3.accent1_100 : M3.accent1_600
    readonly property color label: dark ? M3.neutral2_200 : M3.neutral2_700
    readonly property color button: dark ? M3.accent1_200 : M3.accent1_600
    readonly property color buttonInk: dark ? M3.accent1_700 : M3.accent1_10

    readonly property string playPath: "M320-200v-560l440 280-440 280Z"
    readonly property string pausePath: "M560-200v-560h160v560H560Zm-320 0v-560h160v560H240Z"
    readonly property string lapPath: "M360-840v-80h240v80H360Zm80 440h80v-240h-80v240Zm40 320q-74 0-139.5-28.5T226-186q-49-49-77.5-114.5T120-440q0-74 28.5-139.5T226-694q49-49 114.5-77.5T480-800q62 0 119 20t107 58l56-56 56 56-56 56q38 50 58 107t20 119q0 74-28.5 139.5T734-186q-49 49-114.5 77.5T480-80Zm0-80q116 0 198-82t82-198q0-116-82-198t-198-82q-116 0-198 82t-82 198q0 116 82 198t198 82Zm0-280Z"
    readonly property string resetPath: "M440-122q-121-15-200.5-105.5T160-440q0-66 26-126.5T260-672l57 57q-38 34-57.5 79T240-440q0 88 56 155.5T440-202v80Zm80 0v-80q87-16 143.5-83T720-440q0-100-70-170t-170-70h-3l44 44-56 56-140-140 140-140 56 56-44 44h3q134 0 227 93t93 227q0 121-79.5 211.5T520-122Z"

    function timeText(): string {
        const total = Math.floor(Math.max(0, face.elapsed) / 1000);
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor(total % 3600 / 60);
        const seconds = total % 60;
        const tail = String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0");
        return hours > 0 ? hours + ":" + tail : tail;
    }

    FontMetrics {
        id: metrics
        font.family: M3.typeface
        font.pixelSize: 200
    }

    readonly property real digitRatio: Math.max(0.5, metrics.tightBoundingRect("0").height / 200)
    readonly property real capRatio: Math.max(0.5, metrics.tightBoundingRect("L").height / 200)

    Item {
        id: box
        anchors.centerIn: parent
        width: face.side
        height: face.side

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: face.surface
        }

        Text {
            id: time
            anchors.horizontalCenter: parent.horizontalCenter
            y: box.height * 0.5 + box.height * 0.0815 - baselineOffset
            width: box.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            text: face.timeText()
            color: face.digits
            font.family: M3.typeface
            font.pixelSize: Math.max(1, Math.round(box.height * 0.163 / face.digitRatio))
            font.features: { "tnum": 1 }
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 6
            textFormat: Text.PlainText
        }

        Rectangle {
            id: toggle
            x: 0
            y: box.height - height
            width: box.width * 0.3
            height: width
            radius: width * 0.27
            color: face.button
            scale: toggleMouse.pressed ? 0.94 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: face.buttonInk
                opacity: toggleMouse.pressed ? 0.12 : toggleMouse.containsMouse ? 0.08 : 0
            }

            SymbolIcon {
                anchors.centerIn: parent
                size: box.width * 0.15
                color: face.buttonInk
                path: face.running ? face.pausePath : face.playPath
            }

            MouseArea {
                id: toggleMouse
                anchors.fill: parent
                enabled: face.interactive
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: face.toggled()
            }
        }

        Text {
            visible: face.laps > 0
            x: toggle.width + box.width * 0.105
            y: toggle.y + toggle.height / 2 + box.height * 0.021 - baselineOffset
            width: box.width - x - box.width * 0.04
            text: face.lapText
            color: face.label
            font.family: M3.typeface
            font.pixelSize: Math.max(1, Math.round(box.height * 0.042 / face.capRatio))
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        Rectangle {
            id: pill
            x: box.width - width
            y: 0
            width: box.width * 0.49
            height: box.height * 0.24
            radius: height / 2
            color: M3.accent3_100
            opacity: face.started ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: 2

                Item {
                    id: action

                    required property int index
                    readonly property bool lap: index === 0
                    readonly property bool usable: face.interactive && (lap ? face.running : face.started)

                    x: index * pill.width / 2
                    width: pill.width / 2
                    height: pill.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.86
                        height: width
                        radius: width / 2
                        color: M3.accent3_800
                        opacity: actionMouse.pressed ? 0.12 : actionMouse.containsMouse && action.usable ? 0.08 : 0
                    }

                    SymbolIcon {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: action.lap ? pill.width * 0.035 : -pill.width * 0.035
                        size: box.width * 0.11
                        color: M3.accent3_700
                        opacity: action.lap && !face.running ? 0.38 : 1
                        path: action.lap ? face.lapPath : face.resetPath
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        enabled: action.usable
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: action.lap ? face.lapped() : face.cleared()
                    }
                }
            }
        }
    }
}
