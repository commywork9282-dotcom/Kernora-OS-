/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3

Item {
    id: root

    property var options: []
    property var currentValue
    signal selected(var value)

    implicitWidth: row.implicitWidth
    implicitHeight: 44

    Rectangle {
        anchors.fill: parent
        radius: M3.radius("button", height)
        color: "transparent"
        border.width: 1
        border.color: M3.outline
    }

    Row {
        id: row
        anchors.fill: parent

        Repeater {
            model: root.options

            delegate: Item {
                id: segment

                required property var modelData
                required property int index
                readonly property bool chosen: modelData.value === root.currentValue
                readonly property bool isFirst: index === 0
                readonly property bool isLast: index === root.options.length - 1

                width: root.width > 0 ? root.width / root.options.length : implicitWidth
                implicitWidth: content.implicitWidth + 32
                height: parent.height

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    topLeftRadius: segment.isFirst ? Math.max(0, M3.radius("button", height)) : 0
                    bottomLeftRadius: segment.isFirst ? Math.max(0, M3.radius("button", height)) : 0
                    topRightRadius: segment.isLast ? Math.max(0, M3.radius("button", height)) : 0
                    bottomRightRadius: segment.isLast ? Math.max(0, M3.radius("button", height)) : 0
                    color: segment.chosen ? M3.secondaryContainer : M3.withAlpha(M3.secondaryContainer, 0)
                    Behavior on color { ColorAnimation { duration: M3.durationShort4 } }
                    MStateLayer {
                        topLeftRadius: parent.topLeftRadius
                        bottomLeftRadius: parent.bottomLeftRadius
                        topRightRadius: parent.topRightRadius
                        bottomRightRadius: parent.bottomRightRadius
                        color: M3.surfaceContent
                        hovered: mouse.containsMouse
                        pressed: mouse.pressed
                        pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
                    }
                }
                Rectangle {
                    visible: !segment.isLast
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: M3.outline
                }

                RowLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: 8
                    MIcon {
                        size: 18
                        visible: segment.chosen || (segment.modelData.icon || "").length > 0
                        source: segment.chosen ? "checkmark" : (segment.modelData.icon || "")
                        color: segment.chosen ? M3.secondaryContainerContent : M3.surfaceContent
                    }
                    MText {
                        role: "labelLarge"
                        text: segment.modelData.label
                        color: segment.chosen ? M3.secondaryContainerContent : M3.surfaceContent
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(segment.modelData.value)
                }
            }
        }
    }
}
