/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

Rectangle {
    id: root

    property url folder
    property string homePath
    property string trashPath
    property bool editing: false
    signal chosen(url folder)

    implicitHeight: 48
    radius: height / 2
    color: M3.surfaceContainerHigh

    function toUrl(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function edit(): void {
        field.text = String(folder).replace(/^file:\/\//, "");
        editing = true;
        field.forceActiveFocus();
        field.selectAll();
    }

    readonly property var crumbs: {
        const path = decodeURIComponent(String(folder).replace(/^file:\/\//, "")).replace(/\/$/, "") || "/";
        if (path === trashPath) {
            return [{ label: i18n("Trash"), path: path }];
        }
        let base = "";
        let rest = path;
        const list = [];
        if (homePath.length > 0 && (path === homePath || path.startsWith(homePath + "/"))) {
            list.push({ label: i18n("Home"), path: homePath });
            base = homePath;
            rest = path.slice(homePath.length);
        } else {
            list.push({ label: i18n("Computer"), path: "/" });
        }
        for (const part of rest.split("/").filter(p => p.length > 0)) {
            base = base + "/" + part;
            list.push({ label: part, path: base });
        }
        return list;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.edit()
    }

    ListView {
        id: chips
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        visible: !root.editing
        orientation: ListView.Horizontal
        clip: true
        spacing: 0
        model: root.crumbs
        interactive: contentWidth > width
        boundsBehavior: Flickable.StopAtBounds
        onCountChanged: positionViewAtEnd()
        onWidthChanged: positionViewAtEnd()

        delegate: RowLayout {
            id: crumb
            required property var modelData
            required property int index
            readonly property bool last: index === root.crumbs.length - 1
            height: ListView.view.height
            spacing: 0

            MIcon {
                visible: crumb.index > 0
                size: 18
                source: "arrow-right"
                color: M3.surfaceVariantContent
            }
            Item {
                implicitWidth: label.implicitWidth + 24
                implicitHeight: 36
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: crumb.last ? M3.secondaryContainer : "transparent"
                    MStateLayer {
                        radius: parent.radius
                        hovered: crumbMouse.containsMouse
                        pressed: crumbMouse.pressed
                        pressPoint: Qt.point(crumbMouse.mouseX, crumbMouse.mouseY)
                    }
                }
                MText {
                    id: label
                    anchors.centerIn: parent
                    role: crumb.last ? "labelLarge" : "bodyMedium"
                    text: crumb.modelData.label
                    color: crumb.last ? M3.secondaryContainerContent : M3.surfaceVariantContent
                }
                MouseArea {
                    id: crumbMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chosen(root.toUrl(crumb.modelData.path))
                }
            }
        }
    }

    TextInput {
        id: field
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        visible: root.editing
        font: M3.bodyLarge
        renderType: Text.QtRendering
        color: M3.surfaceContent
        selectionColor: M3.primaryContainer
        selectedTextColor: M3.primaryContainerContent
        selectByMouse: true
        clip: true
        onAccepted: {
            let path = text.trim().replace(/^~/, root.homePath);
            const url = path.startsWith("/") ? root.toUrl(path) : path;
            if (Files.exists(url) && Files.info(url).isDir) {
                root.chosen(url);
                root.editing = false;
            } else {
                QQC2.ApplicationWindow.window.showMessage(i18n("There is no folder “%1”.", path), "", null);
            }
        }
        onActiveFocusChanged: {
            if (!activeFocus) {
                root.editing = false;
            }
        }
        Keys.onEscapePressed: root.editing = false
    }
}
