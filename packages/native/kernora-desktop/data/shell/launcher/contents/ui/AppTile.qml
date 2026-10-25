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
    property url url
    property bool current: false
    property real reveal: 1
    property real enterDelay: 0

    signal clicked()
    signal menuRequested(real x, real y)
    signal dropped()

    readonly property real appear: Math.max(0, Math.min(1, (reveal - enterDelay) / 0.55))
    readonly property real pop: {
        if (M3.classic) {
            return appear;
        }
        const t = appear - 1;
        return 1 + 2.7 * t * t * t + 1.7 * t * t;
    }

    MMorph { id: pressMorph; active: mouse.pressed }

    Accessible.role: Accessible.Button
    Accessible.name: name

    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction
    Drag.proposedAction: Qt.CopyAction
    Drag.mimeData: ({ "text/uri-list": root.url.toString() })
    Drag.onDragFinished: dropAction => {
        root.Drag.active = false;
        if (dropAction !== Qt.IgnoreAction) {
            root.dropped();
        }
    }

    DragHandler {
        id: dragger
        target: null
        enabled: root.url.toString().startsWith("file:")
        onActiveChanged: {
            if (active) {
                icon.grabToImage(result => {
                    root.Drag.imageSource = result.url;
                    root.Drag.active = dragger.active;
                });
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 4
        opacity: root.appear
        transform: [
            Translate { y: (1 - root.pop) * 16 },
            Scale {
                origin.x: root.width / 2
                origin.y: root.height / 2
                xScale: M3.classic ? 1 : 0.85 + 0.15 * root.pop
                yScale: M3.classic ? 1 : 0.85 + 0.15 * root.pop
            }
        ]

        Rectangle {
            id: container
            anchors.fill: parent
            radius: M3.classic ? M3.cornerListItem : 20 + 10 * pressMorph.value
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
            scale: M3.classic ? (mouse.pressed ? 0.9 : 1) : 1 - 0.12 * pressMorph.value
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
