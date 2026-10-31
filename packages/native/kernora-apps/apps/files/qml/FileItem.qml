/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "kinds.js" as Kinds

Item {
    id: root

    required property int index
    required property string fileName
    required property url fileUrl
    required property bool fileIsDir
    required property var fileModified
    required property var fileSize

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
    property string appIcon: ""
    readonly property Component preview: thumbnail ? picture : (appIcon.length > 0 ? packageIcon : symbol)

    function loadAppIcon(): void {
        appIcon = "";
        if (kind !== "android") {
            return;
        }
        const wanted = String(fileUrl);
        Android.iconOf(fileUrl, icon => {
            if (String(root.fileUrl) === wanted) {
                root.appIcon = icon;
            }
        });
    }

    onFileUrlChanged: loadAppIcon()
    Component.onCompleted: loadAppIcon()

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

    Component {
        id: packageIcon
        Rectangle {
            radius: root.list ? width / 2 : (M3.classic ? M3.cornerImage : 16)
            color: root.list ? "transparent" : M3.surfaceContainerHighest
            Image {
                anchors.centerIn: parent
                width: root.list ? parent.width : Math.round(parent.height * 0.72)
                height: width
                source: root.appIcon
                sourceSize: Qt.size(192, 192)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
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
            sourceComponent: root.preview
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
        anchors.rightMargin: 16
        spacing: 16

        Loader {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            sourceComponent: root.preview
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onPressed: event => root.pressed(event)
        onDoubleClicked: event => {
            if (event.button === Qt.LeftButton) {
                root.activated();
            }
        }
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                root.menuRequested(event.x, event.y);
            }
        }
    }
}
