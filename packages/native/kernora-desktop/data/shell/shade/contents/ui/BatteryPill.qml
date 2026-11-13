/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import "m3"

Item {
    id: root

    required property int percent
    required property bool charging
    required property color ink
    required property color knockout
    property bool saver: false

    readonly property bool low: !charging && percent <= 20
    readonly property bool tinted: charging || saver || low
    readonly property color fill: charging ? "#3ddc84" : saver ? "#fdd663" : low ? "#f28b82" : ink
    readonly property color label: tinted ? "#1f1f1f" : knockout
    readonly property color track: tinted ? Qt.alpha(fill, 0.5) : Qt.alpha(ink, 0.38)
    readonly property string badge: charging ? "power-profile-performance" : saver ? "list-add" : ""

    implicitWidth: body.width + nub.width + 1 + (badge.length > 0 ? sign.width + 1 : 0)
    implicitHeight: 15

    Behavior on implicitWidth {
        NumberAnimation {
            duration: M3.durationMedium2 * M3.motionScale
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasizedDecelerate
        }
    }

    Rectangle {
        id: body
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(26, digits.implicitWidth + 8)
        height: 15
        radius: 5
        color: root.track
        clip: true

        Behavior on color {
            ColorAnimation {
                duration: M3.durationMedium2 * M3.motionScale
            }
        }

        Rectangle {
            width: Math.round(parent.width * Math.max(0.12, Math.min(1, root.percent / 100)))
            height: parent.height
            radius: parent.radius
            color: root.fill

            Behavior on width {
                NumberAnimation {
                    duration: M3.durationLong2 * M3.motionScale
                    easing.type: Easing.Bezier
                    easing.bezierCurve: M3.easingEmphasizedDecelerate
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: M3.durationMedium2 * M3.motionScale
                }
            }
        }

        Text {
            id: digits
            anchors.centerIn: parent
            text: root.percent
            color: root.label
            font.family: M3.typeface
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            font.variableAxes: { "ROND": 100, "opsz": 11 }

            Behavior on color {
                ColorAnimation {
                    duration: M3.durationMedium2 * M3.motionScale
                }
            }
        }
    }

    Rectangle {
        id: nub
        anchors.left: body.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 6
        radius: 1
        color: root.percent >= 99 ? root.fill : root.track
    }

    MIcon {
        id: sign
        anchors.left: nub.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        visible: root.badge.length > 0
        size: 14
        source: root.badge
        color: root.ink
        scale: visible ? 1 : 0.4

        Behavior on scale {
            NumberAnimation {
                duration: M3.durationMedium4 * M3.motionScale
                easing.type: Easing.OutBack
                easing.overshoot: 2.2
            }
        }
    }
}
