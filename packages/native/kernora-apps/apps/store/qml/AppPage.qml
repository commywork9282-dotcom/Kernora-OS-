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
import org.kernora.store
import "components"

Item {
    id: page

    property string appId

    readonly property var app: QQC2.ApplicationWindow.window
    readonly property real contentWidth: Math.min(width - 48, 920)
    readonly property bool canGoBack: app ? app.canGoBack && (QQC2.StackView.index > 0 || app.narrow) : false

    property int revision: 0
    property int stateRevision: 0
    readonly property var info: { revision; return Store.details(appId); }
    readonly property var status: { stateRevision; return Store.state(appId); }
    readonly property var sources: info.sources || []
    property string chosenSource: ""
    readonly property string source: chosenSource.length > 0 ? chosenSource
        : (status.installedSource || "").length > 0 ? status.installedSource
        : sources.length > 0 ? sources[0].key : ""
    readonly property var sourceInfo: (info.perSource || {})[source] || {}
    readonly property bool installed: status.installed === true
    readonly property bool busy: status.busy === true

    Connections {
        target: Store
        function onAppChanged(id: string): void {
            if (id === page.appId) {
                page.stateRevision += 1;
                if (page.info.local) {
                    page.revision += 1;
                }
            }
        }
        function onCatalogChanged(): void {
            page.revision += 1;
            page.stateRevision += 1;
        }
    }

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + 56
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column

            x: (flick.width - page.contentWidth) / 2
            y: 20
            width: page.contentWidth
            spacing: 28

            Item {
                width: parent.width
                height: page.canGoBack ? 40 : 0
                visible: page.canGoBack
                IconButton {
                    x: -8
                    iconName: Qt.application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
                    text: i18n("Back")
                    onClicked: page.app.goBack()
                }
            }

            RowLayout {
                width: parent.width
                spacing: 24

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 128
                    Layout.preferredHeight: 128
                    radius: 36
                    color: M3.surfaceContainerLow

                    AppIcon {
                        anchors.centerIn: parent
                        size: 96
                        name: page.info.icon || ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6

                    MText {
                        Layout.fillWidth: true
                        role: "headlineLarge"
                        text: page.info.name || ""
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        spacing: 6
                        visible: (page.info.developer || "").length > 0
                        MText {
                            role: "titleMedium"
                            text: page.info.developer || ""
                            color: M3.primary
                        }
                        MIcon {
                            size: 18
                            visible: page.info.verified === true
                            source: "kernora-verified"
                            color: M3.primary
                        }
                    }
                    MText {
                        Layout.fillWidth: true
                        role: "bodyLarge"
                        text: page.info.summary || ""
                        color: M3.surfaceVariantContent
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        spacing: 8
                        visible: (page.info.ratingCount || 0) > 0
                        MText {
                            role: "titleSmall"
                            text: Number(page.info.rating || 0).toLocaleString(Qt.locale(), "f", 1)
                        }
                        Stars {
                            value: page.info.rating || 0
                            size: 16
                        }
                        MText {
                            role: "bodySmall"
                            color: M3.surfaceVariantContent
                            text: i18np("%1 rating", "%1 ratings", page.info.ratingCount || 0)
                        }
                    }
                }
            }

            ColumnLayout {
                width: parent.width
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: !page.busy

                    MButton {
                        variant: "filled"
                        icon: page.installed ? "" : "download"
                        text: page.installed ? i18n("Open") : i18n("Install")
                        onClicked: {
                            if (page.installed) {
                                if (!Store.launch(page.appId)) {
                                    page.app.showMessage(i18n("%1 is installed. Open it from the app menu.", page.info.name), "", null);
                                }
                            } else {
                                Store.install(page.appId, page.source);
                            }
                        }
                    }
                    MButton {
                        variant: "tonal"
                        icon: "system-software-update"
                        text: i18n("Update")
                        visible: page.installed && page.status.update === true
                        onClicked: Store.update(page.appId)
                    }
                    MButton {
                        variant: "text"
                        text: i18n("Remove")
                        visible: page.installed
                        onClicked: removeDialog.open()
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    SegmentedButtons {
                        visible: !page.installed && page.sources.length > 1
                        options: page.sources.map(entry => ({value: entry.key, label: entry.title}))
                        currentValue: page.source
                        onSelected: value => page.chosenSource = value
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    visible: page.busy

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MText {
                            Layout.fillWidth: true
                            role: "titleSmall"
                            text: page.status.status || ""
                            elide: Text.ElideRight
                        }
                        LinearProgress {
                            Layout.fillWidth: true
                            indeterminate: page.status.progress === undefined || page.status.progress < 0
                            value: Math.max(0, page.status.progress || 0) / 100
                        }
                    }
                    MButton {
                        variant: "tonal"
                        text: i18n("Cancel")
                        onClicked: Store.cancel(page.appId)
                    }
                }

                MText {
                    Layout.fillWidth: true
                    role: "bodySmall"
                    color: M3.surfaceVariantContent
                    wrapMode: Text.Wrap
                    visible: !page.installed && !page.busy && text.length > 0
                    text: page.source === "flatpak" && !page.info.local
                        ? i18n("From Flathub. The app runs in its own sandbox and updates on its own.")
                        : page.source === "debian" && !page.info.local
                        ? i18n("From Debian. Installing it asks for your password.")
                        : ""
                }
            }

            Banner {
                width: parent.width
                visible: page.info.local === true && page.source === "debian"
                tone: "warning"
                icon: "dialog-warning"
                title: i18n("Only install packages you trust")
                text: i18n("This package comes from a file, not from a checked source. It gets full access to your computer.")
            }

            Banner {
                width: parent.width
                visible: Store.live && !page.installed
                icon: "dialog-information"
                title: i18n("You are trying Kernora")
                text: i18n("Apps you install now disappear after a restart.")
            }

            ListView {
                id: shots

                width: parent.width
                height: count > 0 ? 300 : 0
                visible: count > 0
                orientation: ListView.Horizontal
                spacing: 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: page.info.screenshots || []

                delegate: Item {
                    id: shot

                    required property var modelData
                    required property int index

                    height: shots.height
                    width: image.status === Image.Ready && image.implicitHeight > 0
                        ? Math.min(shots.width * 0.9, height * image.implicitWidth / image.implicitHeight) : height * 16 / 10

                    Rectangle {
                        anchors.fill: parent
                        radius: M3.classic ? M3.cornerCard : 20
                        color: M3.surfaceContainerHigh
                    }

                    RoundedClip {
                        anchors.fill: parent
                        radius: M3.classic ? M3.cornerCard : 20

                        Image {
                            id: image
                            anchors.fill: parent
                            source: shot.modelData.thumb
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                            sourceSize.height: 600
                        }
                    }

                    LinearProgress {
                        anchors.centerIn: parent
                        width: parent.width * 0.4
                        visible: image.status === Image.Loading
                        indeterminate: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: viewer.show(shot.index)
                    }
                }
            }

            ColumnLayout {
                width: parent.width
                spacing: 12
                visible: (page.info.description || "").length > 0

                MText {
                    role: "titleLarge"
                    text: i18n("About this app")
                }
                Text {
                    id: description
                    Layout.fillWidth: true
                    text: page.info.description || ""
                    textFormat: Text.RichText
                    wrapMode: Text.Wrap
                    font: M3.bodyLarge
                    color: M3.surfaceContent
                    linkColor: M3.primary
                    lineHeight: 1.15
                    maximumLineCount: expanded ? 10000 : 8
                    elide: Text.ElideRight
                    property bool expanded: false
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
                MButton {
                    variant: "text"
                    visible: description.truncated || description.expanded
                    text: description.expanded ? i18n("Show less") : i18n("Read more")
                    onClicked: description.expanded = !description.expanded
                }
            }

            Group {
                width: parent.width
                title: i18n("Details")

                ListItem {
                    title: i18n("Version")
                    icon: "dialog-information"
                    iconStyle: "plain"
                    interactive: false
                    value: (page.installed ? page.status.installedVersion : "") || page.sourceInfo.version || page.info.version || i18n("Unknown")
                    visible: value !== i18n("Unknown") || page.installed
                }
                ListItem {
                    title: i18n("Source")
                    icon: page.source === "flatpak" ? "applications-internet" : "package-x-generic"
                    iconStyle: "plain"
                    interactive: false
                    value: {
                        const entry = page.sources.find(item => item.key === page.source);
                        return entry ? entry.title : "";
                    }
                }
                ListItem {
                    title: i18n("Size on disk")
                    icon: "drive-harddisk"
                    iconStyle: "plain"
                    interactive: false
                    visible: (page.status.installedSize || "").length > 0
                    value: page.status.installedSize || ""
                }
                ListItem {
                    title: i18n("Licence")
                    icon: "license"
                    iconStyle: "plain"
                    interactive: false
                    visible: (page.info.license || "").length > 0
                    value: page.info.license || ""
                }
                ListItem {
                    title: i18n("Website")
                    subtitle: page.info.homepage || ""
                    icon: "link"
                    iconStyle: "plain"
                    chevron: true
                    visible: (page.info.homepage || "").length > 0
                    onClicked: Qt.openUrlExternally(page.info.homepage)
                }
                ListItem {
                    title: i18n("File")
                    icon: "package-x-generic"
                    iconStyle: "plain"
                    interactive: false
                    visible: (page.info.file || "").length > 0
                    value: page.info.file || ""
                }
            }

            Flow {
                width: parent.width
                spacing: 8
                visible: (page.info.categories || []).length > 0

                Repeater {
                    model: page.info.categories || []
                    delegate: Rectangle {
                        id: tag
                        required property var modelData
                        implicitWidth: tagLabel.implicitWidth + 32
                        implicitHeight: 36
                        radius: M3.classic ? M3.cornerButton : 10
                        color: "transparent"
                        border.width: 1
                        border.color: M3.outlineVariant

                        MText {
                            id: tagLabel
                            anchors.centerIn: parent
                            role: "labelLarge"
                            text: tag.modelData.name
                            color: M3.surfaceVariantContent
                        }
                        MStateLayer {
                            radius: tag.radius
                            color: M3.surfaceContent
                            hovered: tagMouse.containsMouse
                            pressed: tagMouse.pressed
                            pressPoint: Qt.point(tagMouse.mouseX, tagMouse.mouseY)
                        }
                        MouseArea {
                            id: tagMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.app.showSection("category:" + tag.modelData.id)
                        }
                    }
                }
            }
        }
    }

    MScrollIndicator {
        flickable: flick
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    Dialog {
        id: removeDialog
        icon: "user-trash"
        title: i18n("Remove %1?", page.info.name || "")
        text: page.status.installedSource === "flatpak"
            ? i18n("The app and its files in the sandbox are removed. Your documents stay.")
            : i18n("The app is removed from the computer. Your documents stay.")
        acceptText: i18n("Remove")
        destructive: true
        onAccepted: Store.remove(page.appId)
    }

    QQC2.Popup {
        id: viewer

        property int current: 0

        function show(index: int): void {
            current = index;
            open();
        }

        parent: QQC2.Overlay.overlay
        x: 0
        y: 0
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        modal: true
        padding: 0
        background: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.88)
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: M3.durationMedium2 }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: M3.durationShort4 }
        }

        contentItem: Item {
            focus: true
            Keys.onLeftPressed: viewer.current = Math.max(0, viewer.current - 1)
            Keys.onRightPressed: viewer.current = Math.min((page.info.screenshots || []).length - 1, viewer.current + 1)
            Keys.onEscapePressed: viewer.close()

            MouseArea {
                anchors.fill: parent
                onClicked: viewer.close()
            }

            Image {
                id: full
                anchors.fill: parent
                anchors.margins: 64
                source: ((page.info.screenshots || [])[viewer.current] || {}).full || ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
            }

            LinearProgress {
                anchors.centerIn: parent
                width: 200
                visible: full.status === Image.Loading
                indeterminate: true
            }

            MIconButton {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: viewer.current > 0
                variant: "filled"
                icon: "go-previous"
                text: i18n("Previous")
                onClicked: viewer.current -= 1
            }
            MIconButton {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: viewer.current < (page.info.screenshots || []).length - 1
                variant: "filled"
                icon: "go-next"
                text: i18n("Next")
                onClicked: viewer.current += 1
            }
            MIconButton {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                variant: "filled"
                icon: "window-close"
                text: i18n("Close")
                onClicked: viewer.close()
            }
        }
    }
}
