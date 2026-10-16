/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.components as PC3

Item {
    id: root

    property string icon
    property string variant: "standard"
    property bool checkable: false
    property bool checked: false
    property string text
    property int size: 40
    property int iconSize: 24

    signal clicked()

    implicitWidth: size
    implicitHeight: size
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.38

    Accessible.role: checkable ? Accessible.CheckBox : Accessible.Button
    Accessible.name: text
    Accessible.checkable: checkable
    Accessible.checked: checked
    Accessible.onPressAction: activate()

    function activate(): void {
        if (checkable) {
            checked = !checked;
        }
        clicked();
    }

    Keys.onSpacePressed: activate()
    Keys.onReturnPressed: activate()
    Keys.onEnterPressed: activate()

    readonly property bool selected: !checkable || checked

    readonly property color containerColor: {
        switch (variant) {
        case "filled":
            return selected ? M3.primary : M3.surfaceContainerHighest;
        case "tonal":
            return selected ? M3.secondaryContainer : M3.surfaceContainerHighest;
        case "outlined":
            return checkable && checked ? M3.inverseSurface : "transparent";
        default:
            return "transparent";
        }
    }

    readonly property color contentColor: {
        switch (variant) {
        case "filled":
            return selected ? M3.primaryContent : M3.primary;
        case "tonal":
            return selected ? M3.secondaryContainerContent : M3.surfaceVariantContent;
        case "outlined":
            return checkable && checked ? M3.inverseOnSurface : M3.surfaceVariantContent;
        default:
            return checkable && checked ? M3.primary : M3.surfaceVariantContent;
        }
    }

    MMorph { id: pressMorph; active: mouse.pressed }
    MMorph { id: checkMorph; active: root.checkable && root.checked }

    Rectangle {
        id: container
        anchors.fill: parent
        readonly property real rest: root.height / 2 + (Math.round(root.height * 0.3) - root.height / 2) * checkMorph.value
        radius: M3.classic ? root.height / 2 : Math.max(0, rest + (Math.round(root.height * 0.22) - rest) * pressMorph.value)
        color: root.containerColor
        border.width: root.variant === "outlined" && !(root.checkable && root.checked) ? 1 : 0
        border.color: M3.outlineVariant

        Behavior on color {
            ColorAnimation {
                duration: M3.durationMedium1
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
        }

        MIcon {
            anchors.centerIn: parent
            size: root.iconSize
            source: root.icon
            color: root.contentColor
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
        onClicked: root.activate()
    }

    PC3.ToolTip.text: root.text
    PC3.ToolTip.visible: root.text.length > 0 && mouse.containsMouse && !mouse.pressed
    PC3.ToolTip.delay: 600
}
