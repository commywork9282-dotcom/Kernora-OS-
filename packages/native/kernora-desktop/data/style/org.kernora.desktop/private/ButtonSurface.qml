/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import "../impl"

Item {
    id: surface

    property T.AbstractButton control
    property string variant: "tonal"
    property real restRadius: height / 2
    property real pressedRadius: Math.min(restRadius, 10)

    implicitWidth: 40
    implicitHeight: 36

    readonly property bool hasContainer: variant === "filled" || variant === "tonal"
    readonly property color containerColor: {
        if (!control.enabled) {
            return hasContainer ? M3.withAlpha(M3.surfaceContent, M3.stateDisabledContainer) : "transparent";
        }
        switch (variant) {
        case "filled":
            return M3.primary;
        case "tonal":
            return M3.secondaryContainer;
        default:
            return M3.withAlpha(M3.secondaryContainer, 0);
        }
    }
    readonly property color contentColor: {
        if (!control.enabled) {
            return M3.withAlpha(M3.surfaceContent, M3.stateDisabledContent);
        }
        switch (variant) {
        case "filled":
            return M3.primaryContent;
        case "tonal":
            return M3.secondaryContainerContent;
        case "text":
            return M3.primary;
        case "outlined":
            return M3.surfaceVariantContent;
        default:
            return M3.surfaceContent;
        }
    }

    function updateItem(): void {
    }

    readonly property var shadowSpec: M3.elevationOf("button")
    readonly property bool raised: M3.classic && hasContainer && control.enabled

    Kirigami.ShadowedRectangle {
        id: container

        anchors.fill: parent
        radius: M3.classic ? Math.min(M3.radius("button", height), surface.restRadius)
              : surface.control.down ? surface.pressedRadius : surface.restRadius
        shadow.size: surface.raised ? surface.shadowSpec.blur * (surface.control.down ? 2 : 1) : 0
        shadow.yOffset: surface.raised ? surface.shadowSpec.offset * (surface.control.down ? 2 : 1) : 0
        shadow.color: Qt.rgba(0, 0, 0, surface.shadowSpec.opacity)
        color: surface.containerColor
        border.width: surface.variant === "outlined" ? 1 : 0
        border.color: surface.control.enabled ? M3.outlineVariant : M3.withAlpha(M3.surfaceContent, M3.stateDisabledContainer)

        Behavior on radius {
            enabled: M3.motionScale > 0 && !M3.classic
            NumberAnimation {
                duration: surface.control.down ? M3.durationShort3 : M3.durationMedium2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }
        }
        Behavior on color {
            enabled: M3.motionScale > 0
            ColorAnimation {
                duration: M3.durationShort4
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
        }

        MStateLayer {
            radius: container.radius
            color: surface.contentColor
            visible: surface.control.enabled
            hovered: surface.control.hovered
            pressed: surface.control.down
            focused: surface.control.visualFocus
            pressPoint: Qt.point(surface.control.pressX - surface.x, surface.control.pressY - surface.y)
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: container.radius + 3
        color: "transparent"
        border.width: 2
        border.color: M3.secondary
        visible: surface.control.visualFocus
    }
}
