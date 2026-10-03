/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3

Item {
    id: root

    property string title
    property string icon
    property int accent: -1
    property string startIcon
    property string endIcon
    property alias from: slider.from
    property alias to: slider.to
    property alias value: slider.value
    property alias stepSize: slider.stepSize
    property var formatValue: v => Math.round(100 * (v - from) / Math.max(to - from, 1e-9)) + "%"
    property bool showValue: true
    signal moved(real value)

    readonly property bool segmented: true
    readonly property var segmentSiblings: parent
        ? Array.prototype.filter.call(parent.visibleChildren, item => item.segmented === true)
        : []
    readonly property bool first: segmentSiblings.length === 0 || segmentSiblings[0] === root
    readonly property bool last: segmentSiblings.length === 0 || segmentSiblings[segmentSiblings.length - 1] === root

    width: parent ? parent.width : implicitWidth
    implicitWidth: 360
    implicitHeight: layout.implicitHeight + 28
    opacity: enabled ? 1 : 0.38

    Rectangle {
        anchors.fill: parent
        color: M3.surfaceContainer
        topLeftRadius: root.first ? (M3.classic ? M3.cornerCard : 20) : (M3.classic ? 0 : 4)
        topRightRadius: root.first ? (M3.classic ? M3.cornerCard : 20) : (M3.classic ? 0 : 4)
        bottomLeftRadius: root.last ? (M3.classic ? M3.cornerCard : 20) : (M3.classic ? 0 : 4)
        bottomRightRadius: root.last ? (M3.classic ? M3.cornerCard : 20) : (M3.classic ? 0 : 4)
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            IconCircle {
                visible: root.icon.length > 0
                icon: root.icon
                accent: root.accent
            }
            MText {
                Layout.fillWidth: true
                role: "bodyLarge"
                text: root.title
            }
            MText {
                role: "labelLarge"
                visible: root.showValue
                text: root.formatValue(slider.shownValue)
                color: M3.primary
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            MIcon {
                visible: root.startIcon.length > 0
                size: 20
                source: root.startIcon
            }
            MSlider {
                id: slider
                Layout.fillWidth: true
                trackHeight: 16
                text: root.title
                formatValue: root.formatValue
                onMoved: value => root.moved(value)
            }
            MIcon {
                visible: root.endIcon.length > 0
                size: 20
                source: root.endIcon
            }
        }
    }
}
