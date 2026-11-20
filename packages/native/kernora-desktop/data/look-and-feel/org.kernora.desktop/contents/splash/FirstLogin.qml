/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kernora.m3

Rectangle {
    id: page

    color: M3.surface

    readonly property bool wide: width >= 960
    readonly property real margin: wide ? Math.round(Math.max(40, Math.min(72, width * 0.05))) : 24
    readonly property real topSpace: Math.round(Math.max(88, Math.min(136, height * 0.15)))
    readonly property real paneWidth: wide ? Math.round(width / 2 - margin - 40) : width - 2 * margin
    readonly property bool still: M3.durationLong2 <= 1

    readonly property var tips: [
        { icon: "search", title: i18nd("kernora-ui", "Meta opens the launcher"),
          text: i18nd("kernora-ui", "Start typing to find apps, files and settings") },
        { icon: "preferences-desktop", title: i18nd("kernora-ui", "Network and battery icons open quick settings"),
          text: i18nd("kernora-ui", "Wi-Fi, sound, brightness, Do Not Disturb and more") },
        { icon: "preferences-desktop-touchscreen", title: i18nd("kernora-ui", "Touch and hold the desktop"),
          text: i18nd("kernora-ui", "Wallpaper & style, widgets and Home settings") },
        { icon: "kernora-select-region", title: i18nd("kernora-ui", "Print takes a screenshot"),
          text: i18nd("kernora-ui", "Choose an area, the screen or a window") }
    ]
    function tipNow(): int {
        return Math.floor(Date.now() / 5000) % page.tips.length;
    }

    property int tip: tipNow()
    property int shownTip: tip

    Timer {
        interval: 250
        repeat: true
        running: true
        onTriggered: page.tip = page.tipNow()
    }

    onTipChanged: {
        if (page.still) {
            page.shownTip = page.tip;
        } else {
            swap.restart();
        }
    }

    SequentialAnimation {
        id: swap
        NumberAnimation {
            target: tipBody
            property: "opacity"
            to: 0
            duration: 200
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: page.shownTip = page.tip
        }
        NumberAnimation {
            target: tipBody
            property: "opacity"
            to: 1
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Column {
        x: page.margin
        y: page.topSpace
        width: page.paneWidth
        spacing: 0

        MText {
            width: parent.width
            role: "displaySmall"
            text: i18nd("kernora-ui", "Getting your desktop ready…")
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.1
        }

        Item {
            width: 1
            height: 20
        }

        MText {
            width: parent.width
            role: "bodyLarge"
            text: i18nd("kernora-ui", "The first start takes a little longer. Here is what is worth knowing in the meantime.")
            color: M3.surfaceVariantContent
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.25
        }

        Item {
            width: 1
            height: 40
        }

        MLinearProgress {
            visible: !page.still
            width: parent.width
            indeterminate: true
            thickness: 6
        }

        Item {
            width: 1
            height: page.still ? 0 : 40
        }

        Rectangle {
            width: parent.width
            height: Math.max(96, tipBody.height + 48)
            radius: 28
            color: M3.surfaceContainerHigh

            Item {
                id: tipBody

                x: 24
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 48
                height: Math.max(48, tipText.height)

                readonly property var current: page.tips[page.shownTip]

                Rectangle {
                    id: tipIcon
                    width: 48
                    height: 48
                    radius: 24
                    anchors.verticalCenter: parent.verticalCenter
                    color: M3.primaryContainer

                    MIcon {
                        anchors.centerIn: parent
                        size: 24
                        source: tipBody.current.icon
                        color: M3.primaryContainerContent
                    }
                }

                Column {
                    id: tipText
                    x: tipIcon.width + 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x
                    spacing: 4

                    MText {
                        width: parent.width
                        role: "titleMedium"
                        text: tipBody.current.title
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }

                    MText {
                        width: parent.width
                        role: "bodyMedium"
                        text: tipBody.current.text
                        color: M3.surfaceVariantContent
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
            }
        }

        Item {
            width: 1
            height: 16
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Repeater {
                model: page.tips.length

                Rectangle {
                    required property int index
                    readonly property bool current: index === page.tip

                    anchors.verticalCenter: parent.verticalCenter
                    width: current ? 20 : 6
                    height: 6
                    radius: 3
                    color: current ? M3.primary : M3.outlineVariant

                    Behavior on width {
                        NumberAnimation {
                            duration: page.still ? 0 : 300
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    Item {
        id: art

        visible: page.wide
        x: page.width / 2 + 24
        y: page.topSpace
        width: page.width / 2 - page.margin - 24
        height: page.height - page.topSpace - 120

        readonly property real unit: Math.min(width / 2.2, height / 2.4)

        Repeater {
            model: [
                { shape: "cookie9", x: 0.10, y: 0.12, size: 1.0, tone: "primary", icon: "preferences-desktop-wallpaper" },
                { shape: "circle", x: 0.58, y: 0.0, size: 0.6, tone: "tertiary", icon: "preferences-desktop-widgets" },
                { shape: "sunny", x: 0.62, y: 0.46, size: 0.72, tone: "secondary", icon: "preferences-desktop-color" },
                { shape: "pill", x: 0.18, y: 0.66, size: 0.52, tone: "neutral", icon: "view-app-grid" }
            ]

            MShape {
                id: blob

                required property var modelData
                required property int index

                x: art.width * modelData.x
                y: art.height * modelData.y
                width: art.unit * modelData.size * 1.3
                height: width
                shape: modelData.shape
                color: modelData.tone === "primary" ? M3.primaryContainer : modelData.tone === "tertiary" ? M3.tertiaryContainer
                    : modelData.tone === "secondary" ? M3.secondaryContainer : M3.surfaceContainerHighest

                SequentialAnimation on rotation {
                    running: !page.still
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: blob.index % 2 ? -6 : 6
                        to: blob.index % 2 ? 6 : -6
                        duration: 3000 + blob.index * 500
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: blob.index % 2 ? 6 : -6
                        to: blob.index % 2 ? -6 : 6
                        duration: 3000 + blob.index * 500
                        easing.type: Easing.InOutSine
                    }
                }

                MIcon {
                    anchors.centerIn: parent
                    rotation: -blob.rotation
                    size: Math.round(blob.width * 0.32)
                    source: blob.modelData.icon
                    color: blob.modelData.tone === "primary" ? M3.primaryContainerContent : blob.modelData.tone === "tertiary" ? M3.tertiaryContainerContent
                        : blob.modelData.tone === "secondary" ? M3.secondaryContainerContent : M3.surfaceVariantContent
                }
            }
        }
    }
}
