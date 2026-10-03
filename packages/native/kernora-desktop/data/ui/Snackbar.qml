/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3

Item {
    id: root

    property var action: null

    function show(text: string, actionText: string, callback: var): void {
        label.text = text;
        actionButton.text = actionText || "";
        root.action = callback || null;
        shown = true;
        hideTimer.restart();
    }

    property bool shown: false

    anchors.fill: parent

    Rectangle {
        id: bar

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shown ? parent.height - height - 24 : parent.height + 8
        width: Math.min(parent.width - 48, Math.max(320, row.implicitWidth + 32))
        height: Math.max(52, row.implicitHeight + 24)
        radius: M3.classic ? M3.cornerSnackbar : 12
        color: M3.inverseSurface
        opacity: root.shown ? 1 : 0
        visible: opacity > 0

        Behavior on y { NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: root.shown ? M3.easingEmphasizedDecelerate : M3.easingEmphasizedAccelerate } }
        Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }

        RowLayout {
            id: row
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 8
            spacing: 8
            MText {
                id: label
                Layout.fillWidth: true
                role: "bodyMedium"
                color: M3.inverseOnSurface
                wrapMode: Text.Wrap
            }
            Rectangle {
                id: actionButton
                property string text
                visible: text.length > 0
                implicitWidth: actionLabel.implicitWidth + 24
                implicitHeight: 40
                radius: M3.classic ? M3.cornerButton : 20
                color: "transparent"
                MText {
                    id: actionLabel
                    anchors.centerIn: parent
                    role: "labelLarge"
                    text: actionButton.text
                    color: M3.inversePrimary
                }
                MStateLayer {
                    radius: M3.classic ? M3.cornerButton : 20
                    color: M3.inversePrimary
                    hovered: actionMouse.containsMouse
                    pressed: actionMouse.pressed
                    pressPoint: Qt.point(actionMouse.mouseX, actionMouse.mouseY)
                }
                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.shown = false;
                        if (typeof root.action === "function") {
                            root.action();
                        }
                    }
                }
            }
        }

        HoverHandler {
            onHoveredChanged: hovered ? hideTimer.stop() : hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 4500
        onTriggered: root.shown = false
    }
}
