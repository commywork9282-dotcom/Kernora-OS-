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
    readonly property real contentWidth: Math.min(width - 48, 1040)
    readonly property bool compact: width < 640
    readonly property bool canGoBack: QQC2.StackView.index > 0

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
    readonly property string sourceTitle: {
        const entry = sources.find(item => item.key === source);
        return entry ? entry.title : "";
    }
    readonly property bool installed: status.installed === true
    readonly property bool busy: status.busy === true
    readonly property string version: (installed ? status.installedVersion : "") || sourceInfo.version || info.version || ""
    readonly property string updated: {
        const stamp = sourceInfo.released;
        if (!stamp) {
            return "";
        }
        const date = new Date(stamp);
        return isNaN(date.getTime()) || date.getFullYear() < 2000 ? "" : date.toLocaleDateString(Qt.locale(), "d MMMM yyyy");
    }
    readonly property var votes: info.ratingVotes || []
    readonly property int mostVotes: Math.max(1, ...votes.map(value => Number(value)))

    function primaryAction(): void {
        if (page.installed && page.status.update === true) {
            Store.update(page.appId);
        } else if (page.installed) {
            if (!Store.launch(page.appId)) {
                page.app.showMessage(i18n("%1 is installed. Open it from the app menu.", page.info.name), "", null);
            }
        } else {
            Store.install(page.appId, page.source);
        }
    }

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

    component Stat: ColumnLayout {
        id: stat
        property string value
        property string label
        property string icon
        spacing: 2
        Layout.preferredWidth: Math.max(96, implicitWidth)
        Layout.alignment: Qt.AlignTop

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            MText {
                role: "titleSmall"
                text: stat.value
                elide: Text.ElideRight
                Layout.maximumWidth: 160
            }
            MIcon {
                visible: stat.icon.length > 0
                size: 14
                source: stat.icon
                color: M3.surfaceContent
            }
        }
        MText {
            Layout.alignment: Qt.AlignHCenter
            role: "bodySmall"
            text: stat.label
            color: M3.surfaceVariantContent
        }
    }

    component Divider: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 24
        Layout.alignment: Qt.AlignVCenter
        color: M3.outlineVariant
    }

    component SectionTitle: MText {
        role: "titleLarge"
        Layout.fillWidth: true
    }

    component Fact: ColumnLayout {
        id: fact
        property string label
        property string value
        property string link
        spacing: 2
        visible: value.length > 0
        Layout.fillWidth: true
        Layout.preferredWidth: 100
        Layout.alignment: Qt.AlignTop

        MText {
            Layout.fillWidth: true
            role: "bodyMedium"
            text: fact.label
            color: M3.surfaceVariantContent
        }
        MText {
            Layout.fillWidth: true
            role: "bodyLarge"
            text: fact.value
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 3
            color: fact.link.length > 0 ? M3.primary : M3.surfaceContent
            MouseArea {
                id: linkMouse
                anchors.fill: parent
                enabled: fact.link.length > 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(fact.link)
            }
        }
    }

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + 64
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column

            x: (flick.width - page.contentWidth) / 2
            y: 16
            width: page.contentWidth
            spacing: 24

            IconButton {
                Layout.leftMargin: -8
                visible: page.canGoBack
                iconName: Qt.application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
                text: i18n("Back")
                onClicked: page.app.goBack()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: page.compact ? 16 : 28

                AppPlate {
                    Layout.alignment: Qt.AlignTop
                    size: page.compact ? 72 : 112
                    iconName: page.info.icon || ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    MText {
                        Layout.fillWidth: true
                        role: page.compact ? "headlineSmall" : "headlineLarge"
                        text: page.info.name || ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: (page.info.developer || "").length > 0
                        MText {
                            Layout.maximumWidth: column.width - 160
                            role: "titleMedium"
                            text: page.info.developer || ""
                            color: M3.primary
                            elide: Text.ElideRight
                        }
                        MIcon {
                            size: 18
                            visible: page.info.verified === true
                            source: "kernora-verified"
                            color: M3.primary
                        }
                        Item { Layout.fillWidth: true }
                    }
                    MText {
                        Layout.fillWidth: true
                        role: "bodyMedium"
                        color: M3.surfaceVariantContent
                        wrapMode: Text.Wrap
                        text: page.info.summary || ""
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                visible: !page.info.local

                Stat {
                    visible: (page.info.ratingCount || 0) > 0
                    value: Number(page.info.rating || 0).toLocaleString(Qt.locale(), "f", 1)
                    icon: "rating"
                    label: i18np("%1 rating", "%1 ratings", page.info.ratingCount || 0)
                }
                Divider { visible: (page.info.ratingCount || 0) > 0 }
                Stat {
                    value: page.sourceTitle
                    label: i18n("Source")
                }
                Divider { visible: page.version.length > 0 }
                Stat {
                    visible: page.version.length > 0
                    value: page.version
                    label: i18n("Version")
                }
                Divider { visible: (page.status.installedSize || "").length > 0 }
                Stat {
                    visible: (page.status.installedSize || "").length > 0
                    value: page.status.installedSize || ""
                    label: i18n("Size")
                }
                Item { Layout.fillWidth: true }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: !page.busy

                    MButton {
                        Layout.preferredWidth: page.compact ? implicitWidth : Math.max(implicitWidth, 160)
                        variant: "outlined"
                        text: i18n("Uninstall")
                        visible: page.installed
                        onClicked: removeDialog.open()
                    }
                    MButton {
                        Layout.preferredWidth: page.compact ? implicitWidth : Math.max(implicitWidth, page.installed ? 160 : 240)
                        variant: "filled"
                        text: page.installed && page.status.update === true ? i18n("Update")
                            : page.installed ? i18n("Open") : i18n("Install")
                        onClicked: page.primaryAction()
                    }
                    MButton {
                        variant: "text"
                        text: i18n("Open")
                        visible: page.installed && page.status.update === true
                        onClicked: {
                            if (!Store.launch(page.appId)) {
                                page.app.showMessage(i18n("%1 is installed. Open it from the app menu.", page.info.name), "", null);
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
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
                        variant: "outlined"
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
                        ? i18n("From Flathub. App updates are available in Store.")
                        : page.source === "debian" && !page.info.local
                        ? i18n("From Debian. Installing it asks for your password.")
                        : ""
                }
            }

            Notice {
                Layout.fillWidth: true
                visible: page.info.local === true && page.source === "debian"
                warning: true
                icon: "dialog-warning"
                text: i18n("Only install packages you trust. This one comes from a file, not from a checked source, and gets full access to your computer.")
            }

            Notice {
                Layout.fillWidth: true
                visible: Store.live && !page.installed
                text: i18n("You are trying Kernora. Apps you install now disappear after a restart.")
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: shots.height
                visible: shots.count > 0 && shots.contentWidth > shots.count * shots.spacing

                HoverHandler { id: shotsHover }

                ListView {
                    id: shots

                    width: parent.width
                    height: count > 0 ? (page.compact ? 200 : 280) : 0
                    orientation: ListView.Horizontal
                    spacing: 12
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: page.info.screenshots || []
                    Behavior on contentX {
                        enabled: !shots.moving
                        NumberAnimation { duration: M3.durationLong2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasized }
                    }

                    delegate: Item {
                        id: shot

                        required property var modelData
                        required property int index

                        height: shots.height
                        visible: image.status !== Image.Error
                        width: image.status === Image.Error ? 0
                            : image.status === Image.Ready && image.implicitHeight > 0
                            ? Math.min(shots.width * 0.9, height * image.implicitWidth / image.implicitHeight) : height * 16 / 10

                        Rectangle {
                            anchors.fill: parent
                            radius: M3.classic ? M3.cornerCard : 12
                            color: M3.surfaceContainerHigh
                        }

                        RoundedClip {
                            anchors.fill: parent
                            radius: M3.classic ? M3.cornerCard : 12

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

                        MIcon {
                            anchors.centerIn: parent
                            size: 48
                            source: "image-x-generic"
                            color: M3.surfaceVariantContent
                            visible: image.status === Image.Error
                        }

                        MLoadingIndicator {
                            anchors.centerIn: parent
                            visible: image.status === Image.Loading
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: viewer.show(shot.index)
                        }
                    }
                }

                MIconButton {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    icon: "go-previous"
                    text: i18n("Previous")
                    opacity: shotsHover.hovered && !shots.atXBeginning ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }
                    onClicked: shots.contentX = Math.max(shots.originX, shots.contentX - shots.width * 0.8)
                }
                MIconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    icon: "go-next"
                    text: i18n("Next")
                    opacity: shotsHover.hovered && !shots.atXEnd ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }
                    onClicked: shots.contentX = Math.min(shots.contentWidth - shots.width + shots.originX, shots.contentX + shots.width * 0.8)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: (page.info.description || "").length > 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SectionTitle {
                        Layout.fillWidth: false
                        text: i18n("About this app")
                    }
                    MIconButton {
                        visible: description.truncated || description.expanded
                        icon: description.expanded ? "arrow-up" : "arrow-down"
                        text: description.expanded ? i18n("Show less") : i18n("Read more")
                        onClicked: description.expanded = !description.expanded
                    }
                    Item { Layout.fillWidth: true }
                }
                Text {
                    id: description
                    property bool expanded: false
                    Layout.fillWidth: true
                    text: page.info.description || ""
                    textFormat: Text.RichText
                    wrapMode: Text.Wrap
                    font: M3.bodyMedium
                    color: M3.surfaceVariantContent
                    linkColor: M3.primary
                    lineHeight: 1.2
                    maximumLineCount: expanded ? 10000 : 5
                    elide: Text.ElideRight
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
                MText {
                    Layout.fillWidth: true
                    visible: page.updated.length > 0
                    role: "bodyMedium"
                    text: i18n("Updated on %1", page.updated)
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8
                    visible: (page.info.categories || []).length > 0

                    Repeater {
                        model: page.info.categories || []
                        delegate: Rectangle {
                            id: tag
                            required property var modelData
                            implicitWidth: tagLabel.implicitWidth + 32
                            implicitHeight: 32
                            radius: M3.classic ? M3.cornerButton : 8
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
                                onClicked: page.app.openCategory(tag.modelData.id)
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16
                visible: (page.info.ratingCount || 0) > 0

                SectionTitle {
                    text: i18n("Ratings")
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 32

                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        spacing: 4
                        MText {
                            role: "displayMedium"
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

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 480
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6
                        visible: page.votes.length === 5

                        Repeater {
                            model: 5
                            delegate: RowLayout {
                                id: bar
                                required property int index
                                readonly property int star: 5 - index
                                readonly property real share: Number(page.votes[star - 1] || 0) / page.mostVotes
                                Layout.fillWidth: true
                                spacing: 12
                                MText {
                                    Layout.preferredWidth: 12
                                    role: "bodySmall"
                                    text: bar.star
                                    color: M3.surfaceVariantContent
                                    horizontalAlignment: Text.AlignRight
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 10
                                    radius: 5
                                    color: M3.surfaceContainerHighest
                                    Rectangle {
                                        width: Math.max(bar.share > 0 ? height : 0, parent.width * bar.share)
                                        height: parent.height
                                        radius: parent.radius
                                        color: M3.primary
                                    }
                                }
                            }
                        }
                    }
                }
                MText {
                    Layout.fillWidth: true
                    role: "bodySmall"
                    color: M3.surfaceVariantContent
                    wrapMode: Text.Wrap
                    text: i18n("Ratings come from Linux users through the Open Desktop Ratings Service.")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16

                SectionTitle {
                    text: i18n("App info")
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: page.compact ? 1 : 3
                    columnSpacing: 24
                    rowSpacing: 16

                    Fact { label: i18n("Version"); value: page.version }
                    Fact { label: i18n("Updated on"); value: page.updated }
                    Fact { label: i18n("Source"); value: page.sourceTitle }
                    Fact { label: i18n("Package"); value: page.source === "debian" ? (page.sourceInfo.package || "") : "" }
                    Fact { label: i18n("Size on disk"); value: page.status.installedSize || "" }
                    Fact { label: i18n("Licence"); value: page.info.license || "" }
                    Fact { label: i18n("Website"); value: page.info.homepage || ""; link: page.info.homepage || "" }
                    Fact { label: i18n("File"); value: page.info.file || "" }
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
        title: i18n("Uninstall %1?", page.info.name || "")
        text: page.status.installedSource === "flatpak"
            ? i18n("The app and its files in the sandbox are removed. Your documents stay.")
            : i18n("The app is removed from the computer. Your documents stay.")
        acceptText: i18n("Uninstall")
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

            MLoadingIndicator {
                anchors.centerIn: parent
                width: 64
                height: 64
                contained: true
                visible: full.status === Image.Loading
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
