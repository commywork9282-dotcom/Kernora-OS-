/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

Item {
    id: root

    property string icon
    property string iconOn
    property string title
    property string subtitle
    property bool checked: false
    property bool available: true
    property bool hasDetails: false

    signal toggled()
    signal detailsRequested()

    implicitWidth: M3.classic ? 80 : 180
    implicitHeight: M3.classic ? 100 : 64
    activeFocusOnTab: true

    Accessible.role: Accessible.CheckBox
    Accessible.name: title
    Accessible.description: subtitle
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onPressAction: activate()

    function activate(): void {
        if (available) {
            toggled();
        }
    }

    Keys.onSpacePressed: activate()
    Keys.onReturnPressed: activate()
    Keys.onMenuPressed: if (hasDetails) detailsRequested()

    readonly property bool on: checked && available

    readonly property color containerColor: on ? M3.primary : M3.surfaceContainerHighest
    readonly property color contentColor: on ? M3.primaryContent : M3.surfaceContent
    readonly property color supportingColor: on ? M3.primaryContent : M3.surfaceVariantContent

    Item {
        id: classicTile
        anchors.fill: parent
        visible: M3.classic
        opacity: root.available ? 1 : 0.5

        readonly property bool round: M3.tileStyle === "circle"

        Item {
            id: classicIcon
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            width: 48
            height: 48

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                visible: classicTile.round
                color: root.containerColor
                Behavior on color { ColorAnimation { duration: M3.durationMedium2 } }
            }
            MIcon {
                anchors.centerIn: parent
                source: root.on && root.iconOn.length > 0 ? root.iconOn : root.icon
                color: classicTile.round ? root.contentColor
                     : root.on ? M3.primary : M3.surfaceVariantContent
            }
            MStateLayer {
                radius: width / 2
                color: classicTile.round ? root.contentColor : M3.surfaceContent
                hovered: mouse.containsMouse && mouse.mouseY < classicIcon.height + 8
                pressed: mouse.pressed && mouse.mouseY < classicIcon.height + 8
                focused: root.activeFocus
                pressPoint: Qt.point(width / 2, height / 2)
            }
        }

        Row {
            id: classicLabel
            anchors.top: classicIcon.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            readonly property real room: classicTile.width - 4
            readonly property bool arrowFits: root.hasDetails && root.available
                && classicTitle.implicitWidth + 16 <= room

            MText {
                id: classicTitle
                width: Math.min(implicitWidth, classicLabel.room - (classicLabel.arrowFits ? 16 : 0))
                role: "labelMedium"
                text: root.title
                color: M3.surfaceContent
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 14
                source: "arrow-down"
                visible: classicLabel.arrowFits
            }
        }
    }

    Rectangle {
        id: container

        visible: !M3.classic
        anchors.fill: parent
        radius: mouse.pressed ? 16 : root.on ? 20 : height / 2
        color: root.containerColor
        opacity: root.available ? 1 : 0.5
        scale: mouse.pressed ? 0.97 : 1

        Behavior on radius {
            NumberAnimation {
                duration: M3.durationMedium2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: M3.durationMedium2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasized
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: M3.durationShort4
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
        }

        Item {
            id: iconSlot
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24

            MIcon {
                anchors.fill: parent
                source: root.icon
                color: root.contentColor
                opacity: root.on && root.iconOn.length > 0 ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }
            }
            MIcon {
                anchors.fill: parent
                source: root.iconOn
                color: root.contentColor
                visible: root.iconOn.length > 0
                opacity: root.on ? 1 : 0
                scale: root.on ? 1 : 0.7
                Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }
                Behavior on scale {
                    NumberAnimation {
                        duration: M3.durationMedium2
                        easing.type: Easing.Bezier
                        easing.bezierCurve: M3.easingEmphasizedDecelerate
                    }
                }
            }
        }

        Column {
            anchors.left: iconSlot.right
            anchors.leftMargin: 12
            anchors.right: chevron.visible ? chevron.left : parent.right
            anchors.rightMargin: chevron.visible ? 0 : 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            MText {
                width: parent.width
                role: "titleSmall"
                text: root.title
                color: root.contentColor
            }
            MText {
                width: parent.width
                role: "bodySmall"
                text: root.subtitle
                color: root.supportingColor
                opacity: root.on ? 0.85 : 1
                visible: text.length > 0
            }
        }

        Item {
            id: chevron
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 40
            visible: root.hasDetails && root.available

            MIcon {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -4
                size: 20
                source: "arrow-right"
                color: root.supportingColor
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
        enabled: root.available
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => {
            const onChevron = M3.classic
                ? root.hasDetails && event.y >= classicLabel.y - 2
                : chevron.visible && event.x >= chevron.x;
            if (event.button === Qt.RightButton || onChevron) {
                if (root.hasDetails) {
                    root.detailsRequested();
                }
                return;
            }
            root.activate();
        }
    }
}
