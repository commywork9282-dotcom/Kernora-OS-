/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string text
    property string icon
    property string variant: "filled"

    signal clicked()

    implicitHeight: M3.classic ? 36 : 40
    implicitWidth: row.implicitWidth + (icon.length > 0 ? 16 + 24 : 24 + 24)
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.38

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()

    readonly property color containerColor: {
        switch (variant) {
        case "filled":
            return M3.primary;
        case "tonal":
            return M3.secondaryContainer;
        default:
            return "transparent";
        }
    }
    readonly property color contentColor: {
        switch (variant) {
        case "filled":
            return M3.primaryContent;
        case "tonal":
            return M3.secondaryContainerContent;
        case "outlined":
            return M3.surfaceVariantContent;
        default:
            return M3.primary;
        }
    }

    readonly property var shadowSpec: M3.elevationOf("button")
    readonly property bool raised: M3.classic && (variant === "filled" || variant === "tonal")

    MMorph { id: pressMorph; active: mouse.pressed }

    Kirigami.ShadowedRectangle {
        id: container
        anchors.fill: parent
        radius: M3.classic ? M3.radius("button", height) : Math.max(0, height / 2 + (12 - height / 2) * pressMorph.value)
        color: root.containerColor
        border.width: root.variant === "outlined" ? 1 : 0
        border.color: M3.outlineVariant
        shadow.size: root.raised ? root.shadowSpec.blur * (mouse.pressed ? 2 : 1) : 0
        shadow.yOffset: root.raised ? root.shadowSpec.offset * (mouse.pressed ? 2 : 1) : 0
        shadow.color: Qt.rgba(0, 0, 0, root.shadowSpec.opacity)

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.icon.length > 0
                size: 20
                source: root.icon
                color: root.contentColor
            }
            MText {
                anchors.verticalCenter: parent.verticalCenter
                role: "button"
                text: root.text
                color: root.contentColor
            }
        }

        MStateLayer {
            radius: container.radius
            color: root.contentColor
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            focused: root.activeFocus
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
