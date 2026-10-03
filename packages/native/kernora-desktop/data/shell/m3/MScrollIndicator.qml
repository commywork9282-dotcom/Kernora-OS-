/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

Item {
    id: root

    required property Flickable flickable

    anchors.top: flickable.top
    anchors.bottom: flickable.bottom
    anchors.right: flickable.right
    width: 12

    readonly property bool scrollable: flickable.visibleArea.heightRatio < 0.999
    readonly property bool active: flickable.moving || drag.pressed || hover.hovered

    visible: scrollable
    opacity: active ? 1 : 0
    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.active ? 0 : 700 }
            NumberAnimation { duration: M3.durationMedium2 }
        }
    }

    HoverHandler {
        id: hover
    }

    Rectangle {
        x: parent.width - width - 2
        y: root.flickable.visibleArea.yPosition * root.height
        width: drag.pressed || hover.hovered ? 6 : 4
        height: Math.max(24, root.flickable.visibleArea.heightRatio * root.height)
        radius: width / 2
        color: M3.surfaceVariantContent
        opacity: drag.pressed ? 0.8 : 0.5
        Behavior on width { NumberAnimation { duration: M3.durationShort3 } }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        onPositionChanged: event => {
            if (!pressed) {
                return;
            }
            const f = root.flickable;
            const ratio = Math.max(0, Math.min(1, event.y / height));
            f.contentY = f.originY + ratio * (f.contentHeight - f.height);
        }
    }
}
