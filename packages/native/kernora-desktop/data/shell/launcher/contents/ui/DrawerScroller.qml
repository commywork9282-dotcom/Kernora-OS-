/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import "m3"

Item {
    id: root

    property Flickable flickable: null
    property var letterAt: null

    readonly property bool scrollable: flickable !== null && flickable.contentHeight > flickable.height + 1
    readonly property real travel: flickable ? Math.max(1, flickable.contentHeight + flickable.topMargin + flickable.bottomMargin - flickable.height) : 1
    readonly property real progress: flickable ? Math.max(0, Math.min(1, (flickable.contentY - flickable.originY + flickable.topMargin) / travel)) : 0
    readonly property real thumbLength: Math.max(48, Math.min(height, height * (flickable ? flickable.visibleArea.heightRatio : 1)))
    readonly property bool dragging: mouse.pressed
    property string letter: ""

    width: 28
    visible: scrollable

    function scrollTo(y: real): void {
        const fraction = Math.max(0, Math.min(1, (y - thumbLength / 2) / Math.max(1, height - thumbLength)));
        flickable.contentY = flickable.originY - flickable.topMargin + fraction * travel;
        if (typeof letterAt === "function") {
            letter = letterAt(fraction);
        }
    }

    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.rightMargin: 6
        width: 6
        height: parent.height
        radius: 3
        color: M3.withAlpha(M3.surfaceContent, 0.1)
    }

    Rectangle {
        id: thumb
        anchors.horizontalCenter: track.horizontalCenter
        y: root.progress * (root.height - height)
        width: 6
        height: root.thumbLength
        radius: 3
        color: M3.surfaceContent
    }

    Rectangle {
        id: bubble
        anchors.right: track.left
        anchors.rightMargin: 12
        y: Math.max(0, Math.min(root.height - height, thumb.y + thumb.height / 2 - height / 2))
        width: 56
        height: 56
        topLeftRadius: 28
        bottomLeftRadius: 28
        topRightRadius: 28
        bottomRightRadius: 6
        color: M3.primary
        visible: opacity > 0
        opacity: root.dragging && root.letter.length > 0 ? 1 : 0
        scale: root.dragging ? 1 : 0.6
        transformOrigin: Item.BottomRight

        Behavior on opacity {
            NumberAnimation {
                duration: M3.durationShort3
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: M3.durationShort4
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }
        }

        MText {
            anchors.centerIn: parent
            role: "headlineSmall"
            color: M3.primaryContent
            text: root.letter
        }
    }

    MouseArea {
        id: mouse
        anchors.right: parent.right
        width: 24
        height: parent.height
        hoverEnabled: true
        preventStealing: true
        onPressed: event => root.scrollTo(event.y)
        onPositionChanged: event => {
            if (pressed) {
                root.scrollTo(event.y);
            }
        }
    }
}
