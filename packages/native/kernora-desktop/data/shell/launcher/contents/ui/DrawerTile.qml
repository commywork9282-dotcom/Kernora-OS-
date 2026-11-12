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
    property url url
    property bool current: false

    signal clicked()
    signal menuRequested(real x, real y)
    signal dragStarted()
    signal dragFinished(bool dropped)

    Accessible.role: Accessible.Button
    Accessible.name: name

    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction | Qt.LinkAction
    Drag.proposedAction: Qt.CopyAction
    Drag.mimeData: ({ "text/uri-list": root.url.toString() })
    Drag.onDragFinished: dropAction => {
        root.Drag.active = false;
        root.dragFinished(dropAction !== Qt.IgnoreAction);
    }

    DragHandler {
        id: dragger
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: root.url.toString().startsWith("file:")
        onActiveChanged: {
            if (active) {
                icon.grabToImage(result => {
                    root.Drag.imageSource = result.url;
                    if (dragger.active) {
                        root.dragStarted();
                        root.Drag.active = true;
                    }
                });
            }
        }
    }

    Rectangle {
        id: highlight
        anchors.fill: parent
        anchors.margins: 4
        radius: 20
        color: root.current ? M3.withAlpha(M3.surfaceContent, 0.12) : "transparent"

        MStateLayer {
            radius: highlight.radius
            color: M3.surfaceContent
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            pressPoint: Qt.point(mouse.mouseX - highlight.x, mouse.mouseY - highlight.y)
        }
    }

    Kirigami.Icon {
        id: icon
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        width: 48
        height: 48
        source: root.iconSource
        animated: false
        scale: mouse.pressed ? 0.92 : 1

        Behavior on scale {
            NumberAnimation {
                duration: M3.durationShort3
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
        }
    }

    Text {
        anchors.top: icon.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        text: root.name
        color: M3.surfaceContent
        font.family: M3.bodySmall.family
        font.pixelSize: Math.round(13 * M3.scale)
        font.weight: Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        lineHeight: 1.1
        renderType: Text.QtRendering
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
