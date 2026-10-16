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

    readonly property bool expressive: !M3.classic
    readonly property real gap: expressive ? 2 : 0
    readonly property real totalWeight: {
        let sum = 0;
        for (let i = 0; i < row.children.length; ++i) {
            const child = row.children[i];
            if (child.weight !== undefined) {
                sum += child.weight;
            }
        }
        return Math.max(sum, 1);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: 44

    Rectangle {
        visible: !root.expressive
        anchors.fill: parent
        radius: M3.radius("button", height)
        color: "transparent"
        border.width: 1
        border.color: M3.outline
    }

    Row {
        id: row
        anchors.fill: parent
        spacing: root.gap

        Repeater {
            model: root.options

            delegate: Item {
                id: segment

                required property var modelData
                required property int index
                readonly property bool chosen: modelData.value === root.currentValue
                readonly property bool isFirst: index === 0
                readonly property bool isLast: index === root.options.length - 1

                property real weight: root.expressive && mouse.pressed ? 1.15 : 1
                Behavior on weight {
                    enabled: root.expressive
                    NumberAnimation {
                        duration: M3.durationMedium2
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.6
                    }
                }

                readonly property real full: height / 2
                readonly property real inner: mouse.pressed ? 4 : 8
                property real startRadius: root.expressive ? (chosen || isFirst ? full : inner) : (isFirst ? Math.max(0, M3.radius("button", height)) : 0)
                property real endRadius: root.expressive ? (chosen || isLast ? full : inner) : (isLast ? Math.max(0, M3.radius("button", height)) : 0)
                Behavior on startRadius {
                    enabled: root.expressive
                    NumberAnimation {
                        duration: M3.durationMedium4
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }
                Behavior on endRadius {
                    enabled: root.expressive
                    NumberAnimation {
                        duration: M3.durationMedium4
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }

                readonly property color contentColor: root.expressive
                    ? (chosen ? M3.primaryContent : M3.surfaceVariantContent)
                    : (chosen ? M3.secondaryContainerContent : M3.surfaceContent)

                width: root.width > 0
                    ? (root.width - root.gap * (root.options.length - 1)) * weight / root.totalWeight
                    : implicitWidth
                implicitWidth: content.implicitWidth + 32
                height: parent.height

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: root.expressive ? 0 : 1
                    topLeftRadius: Math.min(segment.startRadius, height / 2)
                    bottomLeftRadius: Math.min(segment.startRadius, height / 2)
                    topRightRadius: Math.min(segment.endRadius, height / 2)
                    bottomRightRadius: Math.min(segment.endRadius, height / 2)
                    color: root.expressive
                        ? (segment.chosen ? M3.primary : M3.surfaceContainerHighest)
                        : (segment.chosen ? M3.secondaryContainer : M3.withAlpha(M3.secondaryContainer, 0))
                    Behavior on color { ColorAnimation { duration: M3.durationShort4 } }
                    MStateLayer {
                        topLeftRadius: parent.topLeftRadius
                        bottomLeftRadius: parent.bottomLeftRadius
                        topRightRadius: parent.topRightRadius
                        bottomRightRadius: parent.bottomRightRadius
                        color: segment.contentColor
                        hovered: mouse.containsMouse
                        pressed: mouse.pressed
                        pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
                    }
                }
                Rectangle {
                    visible: !root.expressive && !segment.isLast
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
                        visible: root.expressive ? (segment.modelData.icon || "").length > 0
                                                 : segment.chosen || (segment.modelData.icon || "").length > 0
                        source: !root.expressive && segment.chosen ? "checkmark" : (segment.modelData.icon || "")
                        color: segment.contentColor
                    }
                    MText {
                        role: "labelLarge"
                        text: segment.modelData.label
                        color: segment.contentColor
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
