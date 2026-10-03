/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import org.kernora.m3

import "global"

MouseArea {
    id: compactRoot

    Layout.minimumWidth: Plasmoid.formFactor === PlasmaCore.Types.Horizontal ? height : 24
    Layout.minimumHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? width : 24 + 2 * 12

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    property int activeCount: 0
    property int unreadCount: 0

    property int jobsCount: 0
    property int jobsPercentage: 0

    property bool inhibited: false

    property bool wasExpanded: false
    onPressed: wasExpanded = root.expanded
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) {
            Globals.toggleDoNotDisturbMode();
        } else {
            root.expanded = !wasExpanded;
        }
    }

    hoverEnabled: true

    Rectangle {
        id: container
        anchors.centerIn: parent
        width: Math.min(40, compactRoot.width, compactRoot.height)
        height: width
        radius: width / 2
        color: root.expanded ? M3.secondaryContainer : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: M3.durationMedium1
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
        }

        MStateLayer {
            radius: container.radius
            color: M3.surfaceContent
            hovered: compactRoot.containsMouse
            pressed: compactRoot.pressed
            pressPoint: Qt.point(compactRoot.mouseX - container.x, compactRoot.mouseY - container.y)
        }
    }

    Shape {
        id: ring
        anchors.fill: container
        visible: compactRoot.jobsCount > 0
        preferredRendererType: Shape.CurveRenderer

        readonly property real stroke: 3
        readonly property real r: width / 2 - stroke / 2 - 1
        readonly property bool indeterminate: compactRoot.jobsPercentage <= 0
        readonly property real sweep: indeterminate ? 90 : 360 * compactRoot.jobsPercentage / 100
        readonly property real gap: sweep > 0 && sweep < 360 ? 24 : 0

        property real spin: 0
        rotation: indeterminate ? spin : 0
        NumberAnimation on spin {
            running: ring.visible && ring.indeterminate
            from: 0
            to: 360
            duration: 1200
            loops: Animation.Infinite
        }

        ShapePath {
            strokeColor: M3.secondaryContainer
            strokeWidth: ring.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.r
                radiusY: ring.r
                startAngle: -90 + ring.sweep + ring.gap / 2
                sweepAngle: Math.max(0, 360 - ring.sweep - ring.gap)
            }
        }
        ShapePath {
            strokeColor: M3.primary
            strokeWidth: ring.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.r
                radiusY: ring.r
                startAngle: -90
                sweepAngle: ring.sweep
            }
        }
    }

    MIcon {
        id: bell
        anchors.centerIn: container
        size: compactRoot.jobsCount > 0 ? 18 : 24
        color: root.expanded ? M3.secondaryContainerContent : M3.surfaceContent
        source: compactRoot.inhibited ? "notifications-disabled" : "notification-inactive"
        Behavior on size {
            NumberAnimation {
                duration: M3.durationMedium2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }
        }

        Rectangle {
            x: parent.width - width * 0.75
            y: -height * 0.1
            width: 8
            height: 8
            radius: 4
            color: M3.error
            visible: compactRoot.unreadCount > 0 && !compactRoot.inhibited && compactRoot.jobsCount === 0
            scale: visible ? 1 : 0
            Behavior on scale {
                NumberAnimation {
                    duration: M3.durationMedium2
                    easing.type: Easing.Bezier
                    easing.bezierCurve: M3.easingEmphasizedDecelerate
                }
            }
        }
    }
}
