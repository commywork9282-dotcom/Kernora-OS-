/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kernora.m3

Item {
    id: root

    property var tabs: []
    property string current
    signal selected(string value)

    implicitWidth: row.implicitWidth
    implicitHeight: 48

    readonly property Item currentTab: {
        repeater.count;
        for (let i = 0; i < repeater.count; ++i) {
            const tab = repeater.itemAt(i);
            if (tab && tab.value === root.current) {
                return tab;
            }
        }
        return null;
    }

    Row {
        id: row
        height: parent.height

        Repeater {
            id: repeater
            model: root.tabs

            delegate: Item {
                id: tab

                required property var modelData
                readonly property string value: modelData.value
                readonly property bool chosen: value === root.current
                readonly property real labelWidth: label.implicitWidth

                width: label.implicitWidth + 32
                height: row.height
                activeFocusOnTab: true
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.label
                Accessible.selected: chosen
                Accessible.onPressAction: root.selected(value)
                Keys.onReturnPressed: root.selected(value)
                Keys.onSpacePressed: root.selected(value)

                Item {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    MStateLayer {
                        radius: 8
                        color: M3.surfaceContent
                        hovered: mouse.containsMouse
                        pressed: mouse.pressed
                        focused: tab.activeFocus
                        pressPoint: Qt.point(mouse.mouseX, mouse.mouseY - 4)
                    }
                }

                MText {
                    id: label
                    anchors.centerIn: parent
                    role: "titleSmall"
                    text: tab.modelData.label
                    color: tab.chosen ? M3.primary : M3.surfaceVariantContent
                    Behavior on color { ColorAnimation { duration: M3.durationShort4 } }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(tab.value)
                }
            }
        }
    }

    Rectangle {
        y: root.height - height
        height: 3
        width: root.currentTab ? root.currentTab.labelWidth + 8 : 0
        x: root.currentTab ? root.currentTab.x + (root.currentTab.width - width) / 2 : 0
        visible: root.currentTab !== null
        topLeftRadius: 3
        topRightRadius: 3
        color: M3.primary
        Behavior on x { NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasized } }
        Behavior on width { NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasized } }
    }
}
