/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Effects
import org.kernora.m3
import org.kernora.ui
import "setupdata.js" as SetupData

PixelPage {
    id: page

    icon: "palette"
    title: qsTr("Choose a style")
    description: qsTr("You can change it later in Settings.")

    property bool russian: Qt.locale().name.indexOf("ru") === 0
    readonly property var wallpapers: SetupData.wallpapers.map(entry => ({
        id: entry.id,
        name: russian ? entry.nameRu : entry.name,
        scene: "file:///usr/share/plasma/wallpapers/" + entry.id + "/contents/ui/Scene.qml"
    }))
    readonly property var colours: SetupData.colours
    property string wallpaper: wallpapers.length > 0 ? wallpapers[0].id : ""
    property string colour: "kernora"
    property bool dark: true
    property bool sameShapes: true

    readonly property var current: wallpapers.find(entry => entry.id === wallpaper) || null

    function store(): void {
        Global.insert("kernoraStyle", JSON.stringify({
            wallpaper: page.wallpaper,
            colour: page.colour,
            dark: page.dark,
            originalShapes: !page.sameShapes
        }));
    }

    onWallpaperChanged: Qt.callLater(store)
    onColourChanged: Qt.callLater(store)
    onDarkChanged: Qt.callLater(store)
    onSameShapesChanged: Qt.callLater(store)

    component Live: Item {
        id: live

        property url scene
        property real phase: 0.3
        property real radius: 16

        Item {
            id: content
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: mask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Loader {
                id: loader
                anchors.fill: parent
                source: live.scene
                onLoaded: {
                    item.intro = 1;
                    item.phase = Qt.binding(() => live.phase % 1);
                }
            }
        }

        Item {
            id: mask
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                radius: live.radius
                color: "white"
            }
        }
    }

    below: Column {
        width: parent ? parent.width : 600
        spacing: 16

        Rectangle {
            width: parent.width
            height: Math.round((width - 24) * 10 / 16) + 24
            radius: 32
            color: M3.surfaceContainerHigh

            Live {
                id: preview

                anchors.fill: parent
                anchors.margins: 12
                radius: 20
                scene: page.current ? page.current.scene : ""

                NumberAnimation on phase {
                    running: page.visible
                    from: 0.3
                    to: 1.3
                    duration: 120000
                    loops: Animation.Infinite
                }
            }
        }

        Column {
            spacing: 2

            MText {
                role: "titleMedium"
                text: page.current ? page.current.name : ""
                color: M3.surfaceContent
            }

            MText {
                role: "bodyMedium"
                text: qsTr("Live wallpaper")
                color: M3.surfaceVariantContent
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column

            width: parent.width

            MText {
                role: "titleSmall"
                text: qsTr("Wallpaper")
                color: M3.surfaceContent
            }

            Item {
                width: 1
                height: 16
            }

            Grid {
                id: walls

                readonly property real tile: (width - 2 * columnSpacing) / 3

                width: parent.width
                columns: 3
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: page.wallpapers

                    Item {
                        id: tile

                        required property int index
                        required property var modelData
                        readonly property bool selected: modelData.id === page.wallpaper

                        width: walls.tile
                        height: Math.round(walls.tile * 10 / 16)

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -6
                            visible: tile.selected
                            radius: 22
                            color: "transparent"
                            border.width: 3
                            border.color: M3.primary
                        }

                        Live {
                            anchors.fill: parent
                            radius: 16
                            scene: tile.modelData.scene
                            phase: [0.3, 0.12, 0.4, 0.5, 0.2, 0.6][tile.index % 6]
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: "transparent"
                            border.width: 1
                            border.color: M3.surfaceContainerHighest
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.wallpaper = tile.modelData.id
                        }
                    }
                }
            }

            Item {
                width: 1
                height: 28
            }

            MText {
                role: "titleSmall"
                text: qsTr("Colours")
                color: M3.surfaceContent
            }

            Item {
                width: 1
                height: 8
            }

            Flow {
                x: -6
                width: parent.width + 12
                spacing: 2

                Repeater {
                    model: page.colours

                    Item {
                        id: chip

                        required property var modelData
                        readonly property bool selected: modelData.id === page.colour

                        width: 54
                        height: 54

                        Rectangle {
                            anchors.fill: parent
                            radius: chip.selected ? 18 : 27
                            color: chip.selected ? M3.surfaceContainerHighest : "transparent"
                        }

                        Item {
                            anchors.centerIn: parent
                            width: 38
                            height: 38
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: circle
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                            }

                            Rectangle {
                                width: 38
                                height: 19
                                color: chip.modelData.dark.primary
                            }

                            Rectangle {
                                y: 19
                                width: 19
                                height: 19
                                color: chip.modelData.light.secondaryContainer
                            }

                            Rectangle {
                                x: 19
                                y: 19
                                width: 19
                                height: 19
                                color: chip.modelData.dark.tertiary
                            }
                        }

                        Item {
                            id: circle
                            anchors.centerIn: parent
                            width: 38
                            height: 38
                            visible: false
                            layer.enabled: true

                            Rectangle {
                                anchors.fill: parent
                                radius: 19
                                color: "white"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.colour = chip.modelData.id
                        }
                    }
                }
            }

            Item {
                width: 1
                height: 24
            }

            Group {
                width: parent.width

                ListItem {
                    title: qsTr("Dark theme")
                    icon: "weather-clear-night"
                    iconStyle: "plain"
                    checkable: true
                    checked: page.dark
                    onToggled: on => page.dark = on
                }

                ListItem {
                    title: qsTr("Icons of one shape")
                    subtitle: qsTr("Apps without a Kernora icon get a round one")
                    icon: "preferences-desktop"
                    iconStyle: "plain"
                    checkable: true
                    checked: page.sameShapes
                    onToggled: on => page.sameShapes = on
                }
            }
        }
    }

    function onActivate() {
        russian = Qt.locale().name.indexOf("ru") === 0;
        Qt.callLater(store);
    }

    function onLeave() {
        store();
    }
}
