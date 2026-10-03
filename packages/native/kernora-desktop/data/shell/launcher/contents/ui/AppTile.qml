/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import "m3"

Item {
    id: root

    property string name
    property var iconSource
    property string favoriteId
    property bool current: false
    property real reveal: 1
    property real enterDelay: 0

    signal clicked()
    signal menuRequested(real x, real y)

    readonly property real appear: Math.max(0, Math.min(1, (reveal - enterDelay) / 0.55))

    Accessible.role: Accessible.Button
    Accessible.name: name

    Item {
        anchors.fill: parent
        anchors.margins: 4
        opacity: root.appear
        transform: Translate { y: (1 - root.appear) * 16 }

        Rectangle {
            id: container
            anchors.fill: parent
            radius: M3.classic ? M3.cornerListItem : 20
            color: root.current ? M3.secondaryContainer : "transparent"
            Behavior on color { ColorAnimation { duration: M3.durationShort4 } }

            MStateLayer {
                radius: container.radius
                color: root.current ? M3.secondaryContainerContent : M3.surfaceContent
                hovered: mouse.containsMouse
                pressed: mouse.pressed
                pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
            }
        }

        Kirigami.Icon {
            id: icon
            anchors.horizontalCenter: parent.horizontalCenter
            y: 12
            width: 48
            height: 48
            source: root.iconSource
            animated: false
            scale: mouse.pressed ? 0.9 : 1
            Behavior on scale {
                NumberAnimation {
                    duration: M3.durationShort4
                    easing.type: Easing.Bezier
                    easing.bezierCurve: M3.easingEmphasizedDecelerate
                }
            }
        }

        MText {
            anchors.top: icon.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            role: "bodySmall"
            text: root.name
            color: root.current ? M3.secondaryContainerContent : M3.surfaceContent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: 4
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                root.menuRequested(event.x + anchors.margins, event.y + anchors.margins);
            } else {
                root.clicked();
            }
        }
        onPressAndHold: event => root.menuRequested(event.x + anchors.margins, event.y + anchors.margins)
    }
}
