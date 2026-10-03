/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property bool checked: false
    property string text

    signal toggled()

    implicitWidth: 52
    implicitHeight: 32
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.38

    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onPressAction: toggle()

    function toggle(): void {
        checked = !checked;
        toggled();
    }

    Keys.onSpacePressed: toggle()
    Keys.onReturnPressed: toggle()

    readonly property real position: travel.value
    onCheckedChanged: if (!mouse.dragging) travel.animateTo(checked ? 1 : 0, travel.velocity)
    Component.onCompleted: travel.jumpTo(checked ? 1 : 0)

    MSpring {
        id: travel
        dampingRatio: 0.72
        response: M3.springSpatialFastResponse
    }

    Rectangle {
        id: track
        anchors.centerIn: parent
        width: M3.classic ? 34 : root.width
        height: M3.classic ? 14 : root.height
        radius: height / 2
        color: M3.classic
            ? (root.checked ? M3.withAlpha(M3.secondary, 0.5) : M3.withAlpha(M3.surfaceContent, 0.38))
            : root.checked ? M3.primary : M3.surfaceContainerHighest
        border.width: root.checked || M3.classic ? 0 : 2
        border.color: M3.outline

        Behavior on color {
            ColorAnimation {
                duration: M3.durationShort4
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
        }
    }

    Item {
        id: handleSlot
        readonly property real centerX: track.x + track.height / 2 + root.position * (track.width - track.height)
        x: centerX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.checked ? M3.primary : M3.surfaceContent
            opacity: mouse.pressed ? M3.statePressed
                   : root.activeFocus ? M3.stateFocus
                   : mouse.containsMouse ? M3.stateHover : 0
            Behavior on opacity {
                NumberAnimation { duration: M3.durationShort4 }
            }
        }

        Kirigami.ShadowedRectangle {
            id: handle
            anchors.centerIn: parent
            readonly property real diameter: M3.classic ? 20 : mouse.pressed ? 28 : 16 + 8 * root.position
            width: diameter
            height: diameter
            radius: diameter / 2
            color: M3.classic
                ? (root.checked ? M3.secondary : M3.dark ? "#bdbdbd" : "#fafafa")
                : root.checked ? M3.primaryContent : M3.outline
            shadow.size: M3.classic ? 3 : 0
            shadow.yOffset: M3.classic ? 1 : 0
            shadow.color: Qt.rgba(0, 0, 0, 0.35)
            Behavior on width { NumberAnimation { duration: M3.durationShort3 } }
            Behavior on height { NumberAnimation { duration: M3.durationShort3 } }
            Behavior on color { ColorAnimation { duration: M3.durationShort4 } }

            MIcon {
                anchors.centerIn: parent
                size: 16
                source: "checkmark"
                color: M3.primaryContainerContent
                opacity: Math.max(0, root.position * 2 - 1)
                visible: opacity > 0 && !M3.classic
            }
        }
    }

    MouseArea {
        id: mouse

        property bool dragging: false
        property real pressX: 0
        property real startPosition: 0

        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: dragging

        onPressed: event => {
            pressX = event.x;
            startPosition = root.position;
            dragging = false;
        }
        onPositionChanged: event => {
            if (!pressed) {
                return;
            }
            const dx = event.x - pressX;
            if (!dragging && Math.abs(dx) > 4) {
                dragging = true;
            }
            if (dragging) {
                const span = track.width - track.height;
                travel.jumpTo(Math.max(0, Math.min(1, startPosition + dx / span)));
            }
        }
        onReleased: {
            if (!dragging) {
                root.toggle();
                return;
            }
            dragging = false;
            const wanted = root.position > 0.5;
            if (wanted !== root.checked) {
                root.checked = wanted;
                root.toggled();
            }
            travel.animateTo(root.checked ? 1 : 0, 0);
        }
        onCanceled: {
            dragging = false;
            travel.animateTo(root.checked ? 1 : 0, 0);
        }
    }
}
