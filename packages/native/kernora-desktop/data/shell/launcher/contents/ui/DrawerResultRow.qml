/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import "m3"

Item {
    id: root

    property string title
    property string subtitle
    property var iconSource
    property bool current: false
    property bool first: true
    property bool last: true

    signal clicked()

    implicitHeight: 64

    Accessible.role: Accessible.ListItem
    Accessible.name: title
    Accessible.description: subtitle

    Rectangle {
        id: container
        anchors.fill: parent
        topLeftRadius: root.first ? 20 : 4
        topRightRadius: root.first ? 20 : 4
        bottomLeftRadius: root.last ? 20 : 4
        bottomRightRadius: root.last ? 20 : 4
        color: {
            const base = root.current ? M3.secondaryContainer : M3.dark ? M3.surfaceContainer : M3.withAlpha(M3.surfaceContainerLowest, 0.85);
            const ink = root.current ? M3.secondaryContainerContent : M3.surfaceContent;
            const layer = mouse.pressed ? M3.statePressed : mouse.containsMouse ? M3.stateHover : 0;
            return layer > 0 ? Qt.tint(base, M3.withAlpha(ink, layer)) : base;
        }

        Behavior on color {
            ColorAnimation {
                duration: M3.durationShort3
            }
        }
    }

    Kirigami.Icon {
        id: icon
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        source: root.iconSource
        animated: false
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter

        MText {
            width: parent.width
            role: "bodyLarge"
            text: root.title
            elide: Text.ElideRight
            maximumLineCount: 1
            color: root.current ? M3.secondaryContainerContent : M3.surfaceContent
        }
        MText {
            width: parent.width
            role: "bodyMedium"
            text: root.subtitle
            elide: Text.ElideRight
            maximumLineCount: 1
            visible: text.length > 0 && text !== root.title
            color: root.current ? M3.secondaryContainerContent : M3.surfaceVariantContent
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
