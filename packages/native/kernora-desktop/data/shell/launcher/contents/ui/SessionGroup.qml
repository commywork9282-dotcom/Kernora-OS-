/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.components as PC3
import "m3"

Row {
    id: group

    property var actions: []
    readonly property var shown: actions.filter(action => action.visible)

    spacing: 2

    Repeater {
        id: segments
        model: group.shown

        delegate: Item {
            id: segment

            required property var modelData
            required property int index
            readonly property bool first: index === 0
            readonly property bool last: index === segments.count - 1
            readonly property bool primary: modelData.primary === true

            MMorph { id: pressMorph; active: mouse.pressed }

            width: 44 + 8 * pressMorph.value
            height: 40

            Rectangle {
                id: surface
                anchors.fill: parent
                readonly property real outer: height / 2
                readonly property real inner: 6 + (height / 2 - 6) * pressMorph.value
                topLeftRadius: segment.first ? outer : inner
                bottomLeftRadius: segment.first ? outer : inner
                topRightRadius: segment.last ? outer : inner
                bottomRightRadius: segment.last ? outer : inner
                color: segment.primary ? M3.primary : M3.secondaryContainer

                MStateLayer {
                    topLeftRadius: surface.topLeftRadius
                    bottomLeftRadius: surface.bottomLeftRadius
                    topRightRadius: surface.topRightRadius
                    bottomRightRadius: surface.bottomRightRadius
                    color: segment.primary ? M3.primaryContent : M3.secondaryContainerContent
                    hovered: mouse.containsMouse
                    pressed: mouse.pressed
                    pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
                }
            }

            MIcon {
                anchors.centerIn: parent
                size: 20
                source: segment.modelData.icon
                color: segment.primary ? M3.primaryContent : M3.secondaryContainerContent
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: segment.modelData.trigger()
            }

            Accessible.role: Accessible.Button
            Accessible.name: modelData.text
            PC3.ToolTip.text: modelData.text
            PC3.ToolTip.visible: mouse.containsMouse && !mouse.pressed
            PC3.ToolTip.delay: 600
        }
    }
}
