pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui

RowLayout {
    id: root
    property var tabs: []
    property int currentIndex: 0
    property var labelFor
    signal chosen(int index)
    signal closed(int index)
    signal newRequested()
    signal filesDropped(var urls, url destination, int actions, point position)
    spacing: 4
    ListView {
        id: strip
        objectName: "fileTabs"
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        orientation: ListView.Horizontal
        spacing: 4
        clip: true
        model: root.tabs
        currentIndex: root.currentIndex
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        onCountChanged: Qt.callLater(() => positionViewAtIndex(currentIndex, ListView.Contain))
        delegate: Rectangle {
            id: tab
            required property var modelData
            required property int index
            readonly property bool active: index === root.currentIndex
            width: Math.max(140, Math.min(220, (strip.width - (root.tabs.length - 1) * 4) / Math.min(4, root.tabs.length)))
            height: 48
            radius: 16
            color: active ? M3.secondaryContainer : tabMouse.containsMouse ? M3.surfaceContainerHigh : "transparent"
            Behavior on color { ColorAnimation { duration: M3.durationShort3 } }
            Accessible.role: Accessible.PageTab
            Accessible.name: root.labelFor(modelData.folder)
            Accessible.onPressAction: root.chosen(index)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 44
                spacing: 8
                MIcon { source: "folder-symbolic"; size: 20; color: tab.active ? M3.secondaryContainerContent : M3.surfaceVariantContent }
                MText {
                    Layout.fillWidth: true
                    role: "labelLarge"
                    text: root.labelFor(tab.modelData.folder)
                    color: tab.active ? M3.secondaryContainerContent : M3.surfaceContent
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                id: tabMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: mouse => mouse.button === Qt.MiddleButton ? root.closed(tab.index) : root.chosen(tab.index)
                QQC2.ToolTip.visible: containsMouse
                QQC2.ToolTip.text: decodeURIComponent(String(tab.modelData.folder).replace(/^file:\/\//, ""))
                QQC2.ToolTip.delay: 700
            }
            FileDropArea {
                id: target
                anchors.fill: parent
                destination: tab.modelData.folder
                onFilesDropped: (urls, destination, actions, position) => root.filesDropped(urls, destination, actions, position)
                Timer { interval: 650; running: target.containsDrag && !tab.active; onTriggered: root.chosen(tab.index) }
            }
            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 36
                implicitHeight: 36
                iconName: "window-close"
                text: i18n("Close tab")
                onClicked: root.closed(tab.index)
            }
        }
    }
    IconButton { iconName: "list-add"; text: i18n("New tab"); onClicked: root.newRequested() }
}
