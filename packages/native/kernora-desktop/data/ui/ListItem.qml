/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3

Item {
    id: root

    property string title
    property string subtitle
    property string icon
    property int accent: -1
    property string iconStyle: "circle"
    property Component leading
    property Component trailing
    property string value
    property bool chevron: false
    property bool checkable: false
    property bool checked: false
    property bool interactive: true
    property bool destructive: false
    property int maximumSubtitleLines: 2

    signal clicked()
    signal toggled(bool checked)

    readonly property bool segmented: true

    readonly property var segmentSiblings: parent
        ? Array.prototype.filter.call(parent.visibleChildren, item => item.segmented === true)
        : []
    readonly property bool first: segmentSiblings.length === 0 || segmentSiblings[0] === root
    readonly property bool last: segmentSiblings.length === 0 || segmentSiblings[segmentSiblings.length - 1] === root
    readonly property int outerRadius: M3.classic ? M3.cornerCard : 20
    readonly property int innerRadius: M3.classic ? 0 : 4

    width: parent ? parent.width : implicitWidth
    implicitWidth: 360
    implicitHeight: Math.max(subtitle.length > 0 ? 72 : 56, content.implicitHeight + 24)
    activeFocusOnTab: interactive
    opacity: enabled ? 1 : 0.38

    Accessible.role: checkable ? Accessible.CheckBox : (interactive ? Accessible.Button : Accessible.StaticText)
    Accessible.name: title
    Accessible.description: subtitle.length > 0 ? subtitle : value
    Accessible.checkable: checkable
    Accessible.checked: checked
    Accessible.onPressAction: activate()

    function activate(): void {
        if (!interactive || !enabled) {
            return;
        }
        if (checkable) {
            toggled(!checked);
        }
        clicked();
    }

    Keys.onSpacePressed: activate()
    Keys.onReturnPressed: activate()
    Keys.onEnterPressed: activate()

    Rectangle {
        id: surface

        anchors.fill: parent
        color: M3.surfaceContainer
        topLeftRadius: root.first ? root.outerRadius : root.innerRadius
        topRightRadius: root.first ? root.outerRadius : root.innerRadius
        bottomLeftRadius: root.last ? root.outerRadius : root.innerRadius
        bottomRightRadius: root.last ? root.outerRadius : root.innerRadius

        Behavior on topLeftRadius { NumberAnimation { duration: M3.durationShort4 } }
        Behavior on topRightRadius { NumberAnimation { duration: M3.durationShort4 } }
        Behavior on bottomLeftRadius { NumberAnimation { duration: M3.durationShort4 } }
        Behavior on bottomRightRadius { NumberAnimation { duration: M3.durationShort4 } }

        Rectangle {
            visible: M3.classic && !root.first
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            height: 1
            color: M3.outlineVariant
        }

        MStateLayer {
            visible: root.interactive
            topLeftRadius: surface.topLeftRadius
            topRightRadius: surface.topRightRadius
            bottomLeftRadius: surface.bottomLeftRadius
            bottomRightRadius: surface.bottomRightRadius
            color: root.destructive ? M3.error : M3.surfaceContent
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            focused: root.activeFocus
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
        }
    }

    RowLayout {
        id: content

        z: 1
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 16

        Loader {
            Layout.alignment: Qt.AlignVCenter
            active: root.leading !== null || root.icon.length > 0
            visible: active
            sourceComponent: root.leading !== null ? root.leading : (root.iconStyle === "circle" ? circleIcon : plainIcon)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            MText {
                Layout.fillWidth: true
                role: "bodyLarge"
                text: root.title
                color: root.destructive ? M3.error : M3.surfaceContent
                elide: Text.ElideRight
            }
            MText {
                Layout.fillWidth: true
                role: "bodyMedium"
                text: root.subtitle
                visible: text.length > 0
                color: M3.surfaceVariantContent
                wrapMode: Text.Wrap
                maximumLineCount: root.maximumSubtitleLines
                lineHeightMode: Text.ProportionalHeight
                lineHeight: 1.0
            }
        }

        MText {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: root.width * 0.4
            role: "bodyMedium"
            text: root.value
            visible: text.length > 0
            color: M3.surfaceVariantContent
            horizontalAlignment: Text.AlignRight
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            active: root.trailing !== null
            visible: active
            sourceComponent: root.trailing
        }

        QQC2.Switch {
            Layout.alignment: Qt.AlignVCenter
            visible: root.checkable
            checked: root.checked
            focusPolicy: Qt.NoFocus
            onToggled: root.toggled(checked)
            Accessible.ignored: true

            MouseArea {
                anchors.fill: parent
                enabled: root.interactive
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.forceActiveFocus(Qt.MouseFocusReason);
                    root.activate();
                }
            }
        }

        MIcon {
            Layout.alignment: Qt.AlignVCenter
            visible: root.chevron
            size: 20
            source: Qt.application.layoutDirection === Qt.RightToLeft ? "arrow-left" : "arrow-right"
            color: M3.surfaceVariantContent
        }
    }

    Component {
        id: circleIcon
        IconCircle {
            icon: root.icon
            accent: root.accent
        }
    }
    Component {
        id: plainIcon
        MIcon {
            size: 24
            source: root.icon
            color: root.destructive ? M3.error : M3.surfaceVariantContent
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.activate();
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: surface.topLeftRadius + 2
        color: "transparent"
        border.width: 2
        border.color: M3.secondary
        visible: root.activeFocus && root.interactive && !mouse.pressed && !mouse.containsMouse
    }
}
