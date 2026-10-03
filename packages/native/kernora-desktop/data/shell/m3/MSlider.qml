/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property string icon
    property string text
    property var formatValue: v => Math.round(100 * (v - from) / Math.max(to - from, 1e-9)) + "%"

    property int trackHeight: 40
    readonly property int outerRadius: Math.min(12, trackHeight / 2)
    readonly property int innerRadius: 2
    readonly property int gap: trackHeight >= 32 ? 6 : 4
    readonly property bool iconInTrack: trackHeight >= 32

    readonly property bool pressed: mouse.pressed

    signal moved(real value)

    implicitWidth: 280
    implicitHeight: M3.classic ? 40 : trackHeight + (trackHeight >= 32 ? 12 : 20)
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.38

    Accessible.role: Accessible.Slider
    Accessible.name: text
    Accessible.description: formatValue(shownValue)

    property real userValue: 0
    property bool userOwnsValue: false

    readonly property real shownValue: userOwnsValue ? userValue : value
    readonly property real targetPosition: Math.max(0, Math.min(1,
        (shownValue - from) / Math.max(to - from, 1e-9)))

    property real position: targetPosition
    Behavior on position {
        enabled: !mouse.dragging
        NumberAnimation {
            duration: M3.durationMedium2
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasizedDecelerate
        }
    }

    function snap(v: real): real {
        const clamped = Math.max(from, Math.min(to, v));
        if (stepSize <= 0) {
            return clamped;
        }
        return from + Math.round((clamped - from) / stepSize) * stepSize;
    }

    function setUserValue(v: real): void {
        const snapped = snap(v);
        userOwnsValue = true;
        releaseTimer.restart();
        if (snapped !== userValue) {
            userValue = snapped;
            moved(snapped);
        }
    }

    function nudge(steps: real): void {
        const unit = stepSize > 0 ? Math.max(stepSize, (to - from) / 20) : (to - from) / 20;
        setUserValue(shownValue + steps * unit);
        bubble.flash();
    }

    Timer {
        id: releaseTimer
        interval: 600
        onTriggered: if (!mouse.pressed) root.userOwnsValue = false
    }

    Keys.onLeftPressed: nudge(-1)
    Keys.onDownPressed: nudge(-1)
    Keys.onRightPressed: nudge(1)
    Keys.onUpPressed: nudge(1)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_PageUp) {
            nudge(2);
        } else if (event.key === Qt.Key_PageDown) {
            nudge(-2);
        } else if (event.key === Qt.Key_Home) {
            setUserValue(from);
        } else if (event.key === Qt.Key_End) {
            setUserValue(to);
        } else {
            return;
        }
        event.accepted = true;
    }

    readonly property real handleWidth: mouse.pressed ? 2 : 4
    readonly property real handleSlot: 4
    readonly property real trackLeft: M3.classic && icon.length > 0 ? 40 : 0
    readonly property real handleX: trackLeft + position * (width - trackLeft - handleSlot)
    readonly property real activeWidth: Math.max(0, handleX - gap)
    readonly property real inactiveX: handleX + handleSlot + gap
    readonly property real inactiveWidth: Math.max(0, width - inactiveX)
    readonly property real iconRoom: 12 + 24 + 8

    Item {
        anchors.fill: parent
        visible: M3.classic

        MIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon.length > 0
            source: root.icon
            color: M3.surfaceVariantContent
        }

        readonly property real trackStart: root.trackLeft + root.handleSlot / 2
        readonly property real thumbCenter: root.handleX + root.handleSlot / 2

        Rectangle {
            x: parent.trackStart
            width: root.width - root.handleSlot / 2 - x
            height: 2
            anchors.verticalCenter: parent.verticalCenter
            color: M3.withAlpha(M3.primary, 0.26)
        }
        Rectangle {
            x: parent.trackStart
            width: Math.max(0, parent.thumbCenter - x)
            height: M3.generation === "md2" ? 4 : 2
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: M3.primary
        }
        Rectangle {
            width: 40
            height: 40
            radius: 20
            x: parent.thumbCenter - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: M3.primary
            opacity: mouse.pressed ? M3.statePressed + 0.06 : root.activeFocus ? M3.stateFocus
                   : mouse.containsMouse ? M3.stateHover : 0
            Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }
        }
        Kirigami.ShadowedRectangle {
            readonly property real diameter: mouse.pressed ? 20 : 12
            width: diameter
            height: diameter
            radius: diameter / 2
            x: parent.thumbCenter - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: M3.primary
            shadow.size: M3.generation === "md2" ? 2 : 0
            shadow.yOffset: 1
            shadow.color: Qt.rgba(0, 0, 0, 0.3)
            Behavior on width { NumberAnimation { duration: M3.durationShort3 } }
            Behavior on height { NumberAnimation { duration: M3.durationShort3 } }
        }
    }

    Item {
        id: trackArea
        visible: !M3.classic
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.trackHeight

        Rectangle {
            id: activeTrack
            width: root.activeWidth
            height: parent.height
            visible: width > 0.5
            color: M3.primary
            topLeftRadius: Math.min(root.outerRadius, width / 2)
            bottomLeftRadius: Math.min(root.outerRadius, width / 2)
            topRightRadius: Math.min(root.innerRadius, width / 2)
            bottomRightRadius: Math.min(root.innerRadius, width / 2)
        }

        Rectangle {
            id: inactiveTrack
            x: root.inactiveX
            width: root.inactiveWidth
            height: parent.height
            visible: width > 0.5
            color: M3.secondaryContainer
            topLeftRadius: Math.min(root.innerRadius, width / 2)
            bottomLeftRadius: Math.min(root.innerRadius, width / 2)
            topRightRadius: Math.min(root.outerRadius, width / 2)
            bottomRightRadius: Math.min(root.outerRadius, width / 2)

            Rectangle {
                width: 4
                height: 4
                radius: 2
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 8
                color: M3.primary
                visible: parent.width > 24
            }
        }

        readonly property bool iconOnActive: root.activeWidth >= root.iconRoom

        MIcon {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            source: root.icon
            color: M3.primaryContent
            visible: root.icon.length > 0 && root.iconInTrack
            opacity: trackArea.iconOnActive ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: M3.durationShort3 } }
        }
        MIcon {
            x: root.inactiveX + 12
            anchors.verticalCenter: parent.verticalCenter
            source: root.icon
            color: M3.secondaryContainerContent
            visible: root.icon.length > 0 && root.iconInTrack && root.inactiveWidth >= root.iconRoom
            opacity: trackArea.iconOnActive ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: M3.durationShort3 } }
        }
    }

    Rectangle {
        visible: !M3.classic
        x: root.handleX + root.handleSlot / 2 - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: root.height + 4
        radius: 8
        color: M3.primary
        opacity: root.activeFocus ? M3.stateFocus + 0.06 : mouse.containsMouse ? M3.stateHover : 0
        Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }
    }

    Rectangle {
        id: handle
        visible: !M3.classic
        x: root.handleX + (root.handleSlot - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.handleWidth
        height: root.height
        radius: width / 2
        color: M3.primary
        Behavior on width {
            NumberAnimation {
                duration: M3.durationShort3
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
        }
    }

    Rectangle {
        id: bubble

        readonly property bool shown: mouse.pressed || flashTimer.running

        function flash(): void {
            flashTimer.restart();
        }

        width: Math.max(48, label.implicitWidth + 24)
        height: M3.classic ? 32 : 44
        radius: M3.classic ? M3.cornerSnackbar : height / 2
        x: root.handleX + root.handleSlot / 2 - width / 2
        y: -height - 4
        color: M3.inverseSurface
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.6
        transformOrigin: Item.Bottom
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: bubble.shown ? M3.durationShort4 : M3.durationShort3
                easing.type: Easing.Bezier
                easing.bezierCurve: bubble.shown ? M3.easingEmphasizedDecelerate : M3.easingEmphasizedAccelerate
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: bubble.shown ? M3.durationMedium1 : M3.durationShort3
                easing.type: Easing.Bezier
                easing.bezierCurve: bubble.shown ? M3.easingEmphasizedDecelerate : M3.easingEmphasizedAccelerate
            }
        }

        MText {
            id: label
            anchors.centerIn: parent
            role: "labelLarge"
            color: M3.inverseOnSurface
            text: root.formatValue(root.shownValue)
        }

        Timer {
            id: flashTimer
            interval: 900
        }
    }

    MouseArea {
        id: mouse

        property bool dragging: false
        property real pressX: 0

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        function positionAt(x: real): real {
            return Math.max(0, Math.min(1, (x - root.trackLeft - root.handleSlot / 2)
                                           / (root.width - root.trackLeft - root.handleSlot)));
        }
        function valueAt(x: real): real {
            return root.from + positionAt(x) * (root.to - root.from);
        }

        onPressed: event => {
            root.forceActiveFocus(Qt.MouseFocusReason);
            pressX = event.x;
            dragging = false;
            root.setUserValue(valueAt(event.x));
        }
        onPositionChanged: event => {
            if (!pressed) {
                return;
            }
            if (!dragging && Math.abs(event.x - pressX) > 2) {
                dragging = true;
            }
            if (dragging) {
                root.setUserValue(valueAt(event.x));
                root.position = positionAt(event.x);
            }
        }
        onReleased: {
            dragging = false;
            root.position = Qt.binding(() => root.targetPosition);
            releaseTimer.restart();
        }
        onCanceled: {
            dragging = false;
            root.position = Qt.binding(() => root.targetPosition);
            releaseTimer.restart();
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real accumulated: 0
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
            accumulated += (event.inverted ? -delta : delta);
            while (accumulated >= 120) {
                accumulated -= 120;
                root.nudge(1);
            }
            while (accumulated <= -120) {
                accumulated += 120;
                root.nudge(-1);
            }
        }
    }
}
