/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import "kinds.js" as Kinds

Item {
    id: root

    required property int index
    required property string fileName
    required property url fileUrl
    required property bool fileIsDir
    required property var fileModified
    required property var fileSize

    property bool selectionEnabled: false
    property bool selectionMode: false
    property bool dragEnabled: false
    property bool dropEnabled: false
    property bool dragStarted: false
    property point pressPoint
    signal clicked(var mouse)
    signal selectionToggled()
    signal selectionHeld()
    signal dragRequested()
    signal tabRequested()
    signal filesDropped(var urls, url destination, int actions, point position)

    property bool list: false
    property bool selected: false
    property bool current: false
    property bool showFocus: false
    property bool cut: false
    property string details

    signal pressed(var mouse)
    signal activated()
    signal menuRequested(real x, real y)

    readonly property string kind: Kinds.kindOf(fileName, fileIsDir)
    readonly property bool thumbnail: !fileIsDir && Kinds.hasThumbnail(fileName)

    opacity: cut ? 0.5 : 1

    Rectangle {
        id: surface
        anchors.fill: parent
        anchors.margins: root.list ? 0 : 4
        radius: M3.classic ? (root.list ? M3.cornerListItem : M3.cornerCard) : root.list ? 16 : 20
        color: root.selected ? M3.secondaryContainer : "transparent"
        Behavior on color { ColorAnimation { duration: M3.durationShort3 } }
        MStateLayer {
            radius: surface.radius
            color: root.selected ? M3.secondaryContainerContent : M3.surfaceContent
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            focused: false
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 2
            border.color: M3.primary
            visible: root.current && root.showFocus
        }
    }

    Component {
        id: symbol
        Rectangle {
            radius: root.list ? width / 2 : (M3.classic ? M3.cornerImage : 16)
            color: root.kind === "folder" ? M3.primaryContainer : (Kinds.accentOf(root.kind) >= 0 ? M3.accent(Kinds.accentOf(root.kind)).container : M3.surfaceContainerHighest)
            MIcon {
                anchors.centerIn: parent
                size: root.list ? 22 : Math.round(parent.height * 0.46)
                source: Kinds.iconOf(root.kind)
                color: root.kind === "folder" ? M3.primaryContainerContent : (Kinds.accentOf(root.kind) >= 0 ? M3.accent(Kinds.accentOf(root.kind)).content : M3.surfaceVariantContent)
            }
        }
    }
    Component {
        id: picture
        RoundedClip {
            radius: root.list ? width / 2 : (M3.classic ? M3.cornerImage : 16)
            Rectangle {
                anchors.fill: parent
                color: M3.surfaceContainerHighest
            }
            Image {
                anchors.fill: parent
                source: root.fileUrl
                sourceSize: Qt.size(256, 256)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
        }
    }

    ColumnLayout {
        visible: !root.list
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: width * 0.78
            sourceComponent: root.thumbnail ? picture : symbol
        }
        MText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            role: "bodyMedium"
            text: root.fileName
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 2
            elide: Text.ElideMiddle
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.05
            color: root.selected ? M3.secondaryContainerContent : M3.surfaceContent
        }
    }

    RowLayout {
        visible: root.list
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: root.selectionEnabled ? 52 : 16
        spacing: 16

        Loader {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            sourceComponent: root.thumbnail ? picture : symbol
        }
        MText {
            Layout.fillWidth: true
            role: "bodyLarge"
            text: root.fileName
            elide: Text.ElideMiddle
            color: root.selected ? M3.secondaryContainerContent : M3.surfaceContent
        }
        MText {
            Layout.preferredWidth: 180
            role: "bodyMedium"
            text: root.details
            horizontalAlignment: Text.AlignRight
            color: M3.surfaceVariantContent
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: root.list ? 0 : 4
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | (root.selectionEnabled ? Qt.MiddleButton : Qt.NoButton)
        cursorShape: Qt.PointingHandCursor
        onPressed: event => {
            root.dragStarted = false;
            root.pressPoint = Qt.point(event.x, event.y);
            root.pressed(event);
        }
        onPositionChanged: event => {
            if (root.dragEnabled && pressedButtons === Qt.LeftButton && !root.dragStarted
                && Math.hypot(event.x - root.pressPoint.x, event.y - root.pressPoint.y) >= Qt.styleHints.startDragDistance) {
                root.dragStarted = true;
                root.dragRequested();
            }
        }
        onPressAndHold: event => {
            if (root.selectionEnabled && !root.dragStarted && event.button === Qt.LeftButton) {
                root.selectionHeld();
                root.dragStarted = true;
            }
        }
        onDoubleClicked: event => {
            if (event.button === Qt.LeftButton && !root.selectionMode && !root.dragStarted) {
                root.activated();
            }
        }
        onClicked: event => {
            if (root.dragStarted) return;
            if (event.button === Qt.RightButton) {
                root.menuRequested(event.x, event.y);
            } else if (event.button === Qt.MiddleButton && root.fileIsDir) {
                root.tabRequested();
            } else {
                root.clicked(event);
            }
        }
    }
    FileDropArea {
        anchors.fill: parent
        enabled: root.dropEnabled && root.fileIsDir
        destination: root.fileUrl
        onFilesDropped: (urls, destination, actions, position) => root.filesDropped(urls, destination, actions, position)
    }
    QQC2.CheckBox {
        objectName: "fileSelection"
        anchors.right: parent.right
        anchors.top: root.list ? undefined : parent.top
        anchors.verticalCenter: root.list ? parent.verticalCenter : undefined
        anchors.margins: 6
        visible: root.selectionEnabled && (root.selectionMode || root.selected || mouse.containsMouse || hovered)
        checked: root.selected
        text: ""
        Accessible.name: i18n("Select %1", root.fileName)
        onClicked: root.selectionToggled()
    }
}
