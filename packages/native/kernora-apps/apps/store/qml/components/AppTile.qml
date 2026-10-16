/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3

Item {
    id: root

    property string appId
    property string name
    property string summary
    property string iconSource
    property bool installed
    property bool busy
    property bool hasUpdate
    property int progress: -1
    property real rating: 0

    signal clicked()

    implicitWidth: 120
    implicitHeight: plate.height + 8 + title.lineHeight * 2 + 4 + 20
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: name
    Accessible.description: summary
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    Item {
        anchors.fill: parent
        anchors.margins: -8
        MStateLayer {
            radius: M3.classic ? M3.cornerCard : 16
            color: M3.surfaceContent
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            focused: root.activeFocus
            pressPoint: Qt.point(mouse.mouseX + 8, mouse.mouseY + 8)
        }
    }

    AppPlate {
        id: plate
        size: root.width
        iconName: root.iconSource
    }

    MText {
        id: title
        anchors.top: plate.bottom
        anchors.topMargin: 8
        width: parent.width
        role: "bodyMedium"
        text: root.name
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        verticalAlignment: Text.AlignTop
    }

    Item {
        anchors.top: title.bottom
        anchors.topMargin: 2
        width: parent.width
        height: 20

        MText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            visible: root.busy || root.installed || root.hasUpdate
            role: "bodySmall"
            elide: Text.ElideRight
            color: root.hasUpdate && !root.busy ? M3.primary : M3.surfaceVariantContent
            text: root.busy ? (root.progress >= 0 ? i18n("%1%", root.progress) : i18n("Working…"))
                : root.hasUpdate ? i18n("Update available") : i18n("Installed")
        }
        RatingLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.busy && !root.installed && !root.hasUpdate && value > 0
            value: root.rating
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
