/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import org.kernora.m3
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property QtObject terminal: null
    readonly property var tabs: terminal ? terminal.tabs : []
    readonly property int currentIndex: terminal ? terminal.currentIndex : -1
    readonly property bool active: terminal ? terminal.active : true
    readonly property color fieldColor: terminal ? terminal.fieldColor : "#000000"
    readonly property color fieldInk: terminal ? terminal.fieldInk : "#ffffff"
    readonly property int stripStart: 80
    readonly property int tabHeight: 34
    readonly property int tabWidth: Math.max(72, Math.min(168, Math.floor((tabArea.width - 44) / Math.max(1, tabs.length))))
    property int hoveredTab: -1

    color: active ? M3.surfaceContainerHighest : M3.surfaceContainerHigh
    Behavior on color { ColorAnimation { duration: M3.durationShort4 } }

    function tabColor(index) {
        return tabs[index] && tabs[index].settings ? M3.surface : fieldColor;
    }
    function tabInk(index) {
        return tabs[index] && tabs[index].settings ? M3.surfaceContent : fieldInk;
    }

    MouseArea {
        id: moveArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property point pressPoint
        property bool moving: false
        onPressed: mouse => {
            pressPoint = Qt.point(mouse.x, mouse.y);
            moving = false;
        }
        onPositionChanged: mouse => {
            if (!pressed || moving || !(mouse.buttons & Qt.LeftButton) || !root.terminal) {
                return;
            }
            if (Math.abs(mouse.x - pressPoint.x) + Math.abs(mouse.y - pressPoint.y) > 4) {
                moving = true;
                root.terminal.startMove();
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && root.terminal) {
                root.terminal.showWindowMenu(mouse.x, mouse.y);
            }
        }
        onDoubleClicked: mouse => {
            if (mouse.button === Qt.LeftButton && root.terminal) {
                root.terminal.toggleMaximize();
            }
        }
    }

    Item {
        id: appButton
        x: 8
        width: 60
        height: 32
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: M3.surfaceContent
            opacity: appMouse.pressed ? 0.12 : appMouse.containsMouse ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: M3.durationShort3 } }
        }
        Kirigami.Icon {
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            source: "org.kernora.terminal"
            roundToIconSize: false
        }
        MIcon {
            x: 34
            anchors.verticalCenter: parent.verticalCenter
            size: 18
            source: "arrow-down"
            color: M3.surfaceVariantContent
        }
        MouseArea {
            id: appMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (root.terminal) root.terminal.showWindowMenu(appButton.x, root.height)
        }
    }

    Item {
        id: tabArea
        anchors.left: parent.left
        anchors.leftMargin: root.stripStart
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: menuButton.left
        anchors.rightMargin: 12

        Repeater {
            model: root.tabs
            delegate: Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool current: index === root.currentIndex
                readonly property bool hovered: tabMouse.containsMouse || closeMouse.containsMouse
                x: index * root.tabWidth
                y: root.height - root.tabHeight
                z: current ? 3 : 1
                width: root.tabWidth
                height: root.tabHeight

                Shape {
                    visible: tab.current
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: -1
                        fillColor: root.tabColor(tab.index)
                        startX: -8
                        startY: tab.height
                        PathArc { x: 0; y: tab.height - 8; radiusX: 8; radiusY: 8; direction: PathArc.Counterclockwise }
                        PathLine { x: 0; y: 10 }
                        PathArc { x: 10; y: 0; radiusX: 10; radiusY: 10 }
                        PathLine { x: tab.width - 10; y: 0 }
                        PathArc { x: tab.width; y: 10; radiusX: 10; radiusY: 10 }
                        PathLine { x: tab.width; y: tab.height - 8 }
                        PathArc { x: tab.width + 8; y: tab.height; radiusX: 8; radiusY: 8; direction: PathArc.Counterclockwise }
                        PathLine { x: -8; y: tab.height }
                    }
                }

                Rectangle {
                    visible: !tab.current
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 4
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    radius: 10
                    color: M3.surfaceContent
                    opacity: tab.hovered ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: M3.durationShort3 } }
                }

                Rectangle {
                    x: -0.5
                    width: 1
                    height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    color: M3.outlineVariant
                    visible: tab.index > 0 && !tab.current && tab.index - 1 !== root.currentIndex && !tab.hovered && root.hoveredTab !== tab.index - 1
                }

                Item {
                    id: label
                    x: 14
                    width: parent.width - 14 - 34
                    height: parent.height
                    clip: true
                    MText {
                        id: title
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: tab.current ? 0 : -2
                        role: "bodyMedium"
                        text: tab.modelData.title
                        color: tab.current ? root.tabInk(tab.index) : M3.surfaceVariantContent
                        maximumLineCount: 1
                    }
                    Rectangle {
                        visible: title.implicitWidth > label.width
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 24
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: tab.current ? root.tabColor(tab.index) : root.color }
                        }
                    }
                }

                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onContainsMouseChanged: root.hoveredTab = containsMouse ? tab.index : (root.hoveredTab === tab.index ? -1 : root.hoveredTab)
                    onPressed: mouse => {
                        if (mouse.button === Qt.LeftButton && root.terminal) {
                            root.terminal.activateTab(tab.index);
                        }
                    }
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton && root.terminal) {
                            root.terminal.closeTab(tab.index);
                        }
                    }
                }

                Item {
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: tab.current ? 0 : -2
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: tab.current ? root.tabInk(tab.index) : M3.surfaceContent
                        opacity: closeMouse.pressed ? 0.16 : closeMouse.containsMouse ? 0.10 : 0
                    }
                    MIcon {
                        anchors.centerIn: parent
                        size: 16
                        source: "window-close"
                        color: tab.current ? root.tabInk(tab.index) : M3.surfaceVariantContent
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (root.terminal) root.terminal.closeTab(tab.index)
                    }
                }
            }
        }

        Item {
            id: plus
            x: root.tabs.length * root.tabWidth + 8
            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: M3.surfaceContent
                opacity: plusMouse.pressed ? 0.12 : plusMouse.containsMouse ? 0.08 : 0
                Behavior on opacity { NumberAnimation { duration: M3.durationShort3 } }
            }
            MIcon {
                anchors.centerIn: parent
                size: 20
                source: "list-add"
                color: M3.surfaceContent
            }
            MouseArea {
                id: plusMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: if (root.terminal) root.terminal.newTab()
            }
        }
    }

    Item {
        id: menuButton
        width: 34
        height: 34
        anchors.right: controls.left
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: M3.primaryContainer
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: M3.primaryContainerContent
            opacity: menuMouse.pressed ? 0.12 : menuMouse.containsMouse ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: M3.durationShort3 } }
        }
        MIcon {
            anchors.centerIn: parent
            size: 20
            source: "overflow-menu"
            color: M3.primaryContainerContent
        }
        MouseArea {
            id: menuMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (root.terminal) root.terminal.showAppMenu(menuButton.x + menuButton.width, root.height)
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: [
                { icon: "list-remove", action: "minimize" },
                { icon: root.terminal && root.terminal.maximized ? "window-restore" : "window-maximize", action: "maximize" },
                { icon: "window-close", action: "close" }
            ]
            delegate: Item {
                id: control
                required property var modelData
                width: 32
                height: 32
                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    radius: 13
                    color: M3.surfaceContent
                    opacity: controlMouse.pressed ? 0.18 : controlMouse.containsMouse ? 0.10 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                MIcon {
                    anchors.centerIn: parent
                    size: 18
                    source: control.modelData.icon
                    color: controlMouse.containsMouse ? M3.surfaceContent : root.active ? M3.surfaceVariantContent : M3.outline
                }
                MouseArea {
                    id: controlMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (!root.terminal) {
                            return;
                        }
                        if (control.modelData.action === "minimize") {
                            root.terminal.minimize();
                        } else if (control.modelData.action === "maximize") {
                            root.terminal.toggleMaximize();
                        } else {
                            root.terminal.close();
                        }
                    }
                }
            }
        }
    }
}
