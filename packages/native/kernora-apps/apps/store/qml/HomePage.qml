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

    readonly property var app: QQC2.ApplicationWindow.window
    readonly property real contentWidth: Math.min(width - 48, 1080)

    function luminance(color: color): real {
        return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
    }

    component Shelf: Column {
        id: shelf

        property string title
        property string collection
        property string category

        width: page.contentWidth
        spacing: 12
        visible: shelfModel.count > 0

        AppModel {
            id: shelfModel
            collection: shelf.collection
        }

        RowLayout {
            width: parent.width
            spacing: 8

            MText {
                Layout.fillWidth: true
                role: "titleLarge"
                text: shelf.title
            }
            MIconButton {
                icon: "go-previous"
                text: i18n("Back")
                visible: list.contentWidth > list.width
                enabled: !list.atXBeginning
                onClicked: list.contentX = Math.max(list.originX, list.contentX - list.width * 0.8)
            }
            MIconButton {
                icon: "go-next"
                text: i18n("More")
                visible: list.contentWidth > list.width
                enabled: !list.atXEnd
                onClicked: list.contentX = Math.min(list.contentWidth - list.width + list.originX, list.contentX + list.width * 0.8)
            }
            MButton {
                variant: "text"
                text: i18n("See all")
                visible: shelf.category.length > 0
                onClicked: page.app.showSection("category:" + shelf.category)
            }
        }

        ListView {
            id: list
            width: parent.width
            height: 232
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: shelfModel
            Behavior on contentX {
                NumberAnimation { duration: M3.durationLong2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasized }
            }
            delegate: AppTile {
                required appId
                required name
                required summary
                required iconSource
                required installed
                required busy
                required hasUpdate
                required progress
                required rating
                onClicked: page.app.openApp(appId)
            }
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
            y: 28
            width: page.contentWidth
            spacing: 32

            Banner {
                width: parent.width
                visible: Store.live
                icon: "dialog-information"
                title: i18n("You are trying Kernora")
                text: i18n("Apps you install now disappear after a restart. Install Kernora to keep them.")
            }

            Item {
                id: hero
                width: parent.width
                height: 280
                visible: heroModel.count > 0

                AppModel {
                    id: heroModel
                    collection: "hero"
                }

                ListView {
                    id: heroList
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    snapMode: ListView.SnapOneItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: M3.durationLong4
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    spacing: 16
                    model: heroModel

                    delegate: Item {
                        id: slide

                        required property string appId
                        required property string name
                        required property string summary
                        required property string iconSource
                        required property string accent
                        required property bool installed

                        readonly property color background: accent.length > 0 && !M3.dark ? accent : M3.primaryContainer
                        readonly property color ink: accent.length > 0 && !M3.dark
                            ? (page.luminance(background) > 0.55 ? "#1c1b1f" : "#ffffff") : M3.primaryContainerContent

                        width: heroList.width
                        height: heroList.height

                        Rectangle {
                            id: slideCard
                            anchors.fill: parent
                            radius: M3.classic ? M3.cornerCard : 32
                            color: slide.background

                            Rectangle {
                                width: parent.height * 1.3
                                height: width
                                radius: width / 2
                                x: parent.width - width * 0.62
                                y: -height * 0.18
                                color: Qt.alpha(slide.ink, 0.08)
                            }
                            Rectangle {
                                width: parent.height * 0.7
                                height: width
                                radius: width / 2
                                x: parent.width - width * 1.55
                                y: parent.height - height * 0.45
                                color: Qt.alpha(slide.ink, 0.06)
                            }

                            MStateLayer {
                                radius: slideCard.radius
                                color: slide.ink
                                hovered: slideMouse.containsMouse
                                pressed: slideMouse.pressed
                                pressPoint: Qt.point(slideMouse.mouseX, slideMouse.mouseY)
                            }
                        }

                        MouseArea {
                            id: slideMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.app.openApp(slide.appId)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 40
                            spacing: 32

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 8

                                MText {
                                    role: "labelLarge"
                                    text: i18n("Popular choice")
                                    color: slide.ink
                                    opacity: 0.8
                                }
                                MText {
                                    Layout.fillWidth: true
                                    role: "displaySmall"
                                    text: slide.name
                                    color: slide.ink
                                    elide: Text.ElideRight
                                }
                                MText {
                                    Layout.fillWidth: true
                                    role: "bodyLarge"
                                    text: slide.summary
                                    color: slide.ink
                                    opacity: 0.9
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    Layout.topMargin: 12
                                    implicitWidth: heroAction.implicitWidth + 48
                                    implicitHeight: 44
                                    radius: M3.classic ? M3.cornerButton : 22
                                    color: slide.ink

                                    MText {
                                        id: heroAction
                                        anchors.centerIn: parent
                                        role: "labelLarge"
                                        text: slide.installed ? i18n("Open") : i18n("Get it")
                                        color: slide.background
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (slide.installed) {
                                                Store.launch(slide.appId);
                                            } else {
                                                page.app.openApp(slide.appId);
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 152
                                Layout.preferredHeight: 152
                                visible: hero.width > 560
                                radius: 44
                                color: Qt.alpha("#ffffff", M3.dark ? 0.08 : 0.85)

                                AppIcon {
                                    anchors.centerIn: parent
                                    size: 112
                                    name: slide.iconSource
                                }
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    spacing: 6

                    Repeater {
                        model: heroModel.count
                        delegate: Rectangle {
                            required property int index
                            width: index === heroList.currentIndex ? 20 : 8
                            height: 8
                            radius: 4
                            color: M3.dark ? M3.primaryContainerContent : "#ffffff"
                            opacity: index === heroList.currentIndex ? 0.95 : 0.5
                            Behavior on width {
                                NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasized }
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: heroList.currentIndex = parent.index
                            }
                        }
                    }
                }

                Timer {
                    interval: 7000
                    repeat: true
                    running: page.visible && heroModel.count > 1 && !heroList.moving
                    onTriggered: heroList.currentIndex = (heroList.currentIndex + 1) % heroModel.count
                }
            }

            Shelf {
                title: i18n("Popular apps")
                collection: "popular"
            }
            Shelf {
                title: i18n("Games")
                collection: "games"
                category: "games"
            }
            Shelf {
                title: i18n("Chat & calls")
                collection: "chat"
                category: "internet"
            }
            Shelf {
                title: i18n("Music & video")
                collection: "media"
                category: "multimedia"
            }
            Shelf {
                title: i18n("Create")
                collection: "create"
                category: "graphics"
            }
            Shelf {
                title: i18n("Work & study")
                collection: "work"
                category: "office"
            }

            Column {
                width: parent.width
                spacing: 12

                MText {
                    role: "titleLarge"
                    text: i18n("Browse by category")
                }

                Flow {
                    width: parent.width
                    spacing: 12

                    Repeater {
                        model: Store.categories
                        delegate: Item {
                            id: chip
                            required property var modelData
                            required property int index
                            width: (parent.width - 12 * (columns - 1)) / columns
                            height: 72
                            readonly property int columns: Math.max(2, Math.floor((page.contentWidth + 12) / 260))

                            Rectangle {
                                id: chipCard
                                anchors.fill: parent
                                radius: M3.classic ? M3.cornerCard : 20
                                color: M3.surfaceContainerLow
                                MStateLayer {
                                    radius: chipCard.radius
                                    color: M3.surfaceContent
                                    hovered: chipMouse.containsMouse
                                    pressed: chipMouse.pressed
                                    pressPoint: Qt.point(chipMouse.mouseX, chipMouse.mouseY)
                                }
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 14
                                IconCircle {
                                    size: 40
                                    icon: chip.modelData.icon
                                    accent: chip.index % 5
                                }
                                MText {
                                    Layout.fillWidth: true
                                    role: "titleSmall"
                                    text: chip.modelData.name
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.app.showSection("category:" + chip.modelData.id)
                            }
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
}
