/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.components as PC3

Item {
    id: root

    property string icon
    property string iconOn
    property string title
    property string subtitle
    property bool checked: false
    property bool available: true
    property bool hasDetails: false
    property bool compact: false
    property bool googlebook: false

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

    MMorph { id: onMorph; active: root.on; dampingRatio: M3.springExpressiveDefaultDamping; response: M3.springExpressiveDefaultResponse }
    MMorph { id: bodyPress; active: mouse.pressed && !mouse.onIcon }
    MMorph { id: iconPress; active: mouse.pressed && mouse.onIcon }

    readonly property bool split: hasDetails && !compact && available
    readonly property color offColor: M3.dark ? M3.surfaceContainer : M3.surfaceContainerLowest
    readonly property bool filled: on && (compact || !split)
    readonly property color bodyColor: googlebook ? (filled ? M3.primary : offColor)
                                     : compact ? (on ? M3.primary : M3.surfaceContainerHighest)
                                               : (on ? M3.primaryContainer : M3.surfaceContainerHighest)
    readonly property color bodyContent: googlebook ? (filled ? M3.primaryContent : M3.surfaceContent)
                                       : compact ? (on ? M3.primaryContent : M3.surfaceContent)
                                                 : (on ? M3.primaryContainerContent : M3.surfaceContent)
    readonly property color bodySupporting: googlebook ? (filled ? M3.withAlpha(M3.primaryContent, 0.8) : M3.surfaceVariantContent)
                                          : on ? bodyContent : M3.surfaceVariantContent
    readonly property color iconBoxColor: on ? M3.primary : M3.withAlpha(M3.surfaceContent, googlebook ? 0.12 : 0.1)
    readonly property color iconColor: compact ? bodyContent : googlebook ? (filled || (on && split) ? M3.primaryContent : M3.surfaceContent)
                                                 : on ? M3.primaryContent : M3.surfaceContent

    Rectangle {
        id: container

        visible: !M3.classic
        anchors.fill: parent
        readonly property real rest: root.googlebook ? height / 2 : height / 2 + (20 - height / 2) * onMorph.value
        radius: Math.max(0, rest + (14 - rest) * bodyPress.value)
        color: root.bodyColor
        opacity: root.available ? 1 : 0.5

        Behavior on color {
            ColorAnimation {
                duration: M3.durationMedium2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasized
            }
        }

        MStateLayer {
            radius: container.radius
            color: root.bodyContent
            hovered: mouse.containsMouse && !mouse.onIcon
            pressed: mouse.pressed && !mouse.onIcon
            focused: root.activeFocus
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
        }

        Rectangle {
            id: iconBox
            visible: !root.compact && (!root.googlebook || root.split)
            x: root.googlebook ? 8 : 12
            anchors.verticalCenter: parent.verticalCenter
            width: root.googlebook ? 48 : 40
            height: width
            readonly property real rest: width / 2 + ((root.googlebook ? 14 : 12) - width / 2) * onMorph.value
            radius: Math.max(0, rest + (8 - rest) * iconPress.value)
            color: root.iconBoxColor
            Behavior on color { ColorAnimation { duration: M3.durationMedium2 } }

            MStateLayer {
                radius: iconBox.radius
                color: root.iconColor
                hovered: mouse.containsMouse && mouse.onIcon
                pressed: mouse.pressed && mouse.onIcon
                pressPoint: Qt.point(width / 2, height / 2)
            }
        }

        Item {
            id: iconSlot
            anchors.centerIn: root.compact ? parent : iconBox
            width: 24
            height: 24

            MIcon {
                anchors.fill: parent
                source: root.icon
                color: root.iconColor
                opacity: root.on && root.iconOn.length > 0 ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }
            }
            MIcon {
                anchors.fill: parent
                source: root.iconOn
                color: root.iconColor
                visible: root.iconOn.length > 0
                opacity: root.on ? 1 : 0
                scale: 0.7 + 0.3 * Math.min(1, onMorph.value)
                Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }
            }
        }

        Column {
            visible: !root.compact
            anchors.left: iconBox.right
            anchors.leftMargin: 12
            anchors.right: chevron.visible ? chevron.left : parent.right
            anchors.rightMargin: chevron.visible ? 0 : 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Item {
                id: titleClip
                width: parent.width
                height: titleText.implicitHeight
                clip: root.googlebook
                readonly property real overflow: Math.max(0, titleText.implicitWidth - width)

                MText {
                    id: titleText
                    width: root.googlebook ? implicitWidth : parent.width
                    role: "titleSmallEmphasized"
                    text: root.title
                    color: root.bodyContent
                    elide: root.googlebook ? Text.ElideNone : Text.ElideRight

                    SequentialAnimation on x {
                        running: root.googlebook && titleClip.overflow > 0 && mouse.containsMouse
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) titleText.x = 0
                        PauseAnimation { duration: 600 }
                        NumberAnimation { to: -titleClip.overflow; duration: titleClip.overflow * 25; easing.type: Easing.InOutSine }
                        PauseAnimation { duration: 900 }
                        NumberAnimation { to: 0; duration: titleClip.overflow * 25; easing.type: Easing.InOutSine }
                    }
                }
            }
            MText {
                width: parent.width
                role: "labelMedium"
                text: root.subtitle
                color: root.bodySupporting
                opacity: root.on ? 0.85 : 1
                visible: text.length > 0
            }
        }

        Item {
            id: chevron
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 36
            visible: root.split && !root.googlebook

            MIcon {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -4
                size: 20
                source: "arrow-right"
                color: root.bodySupporting
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available || root.hasDetails
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        readonly property bool onIcon: !M3.classic && root.split && mouseX < iconBox.x + iconBox.width + 6
        onClicked: event => {
            if (M3.classic) {
                const onLabel = root.hasDetails && event.y >= classicLabel.y - 2;
                if (event.button === Qt.RightButton || onLabel) {
                    if (root.hasDetails) {
                        root.detailsRequested();
                    }
                    return;
                }
                root.activate();
                return;
            }
            if (event.button === Qt.RightButton || (root.split && !onIcon) || (!root.available && root.hasDetails)) {
                if (root.hasDetails) {
                    root.detailsRequested();
                }
                return;
            }
            root.activate();
        }
    }

    PC3.ToolTip.text: root.subtitle.length > 0 ? root.title + " · " + root.subtitle : root.title
    PC3.ToolTip.visible: root.compact && mouse.containsMouse && !mouse.pressed
    PC3.ToolTip.delay: 600
}
