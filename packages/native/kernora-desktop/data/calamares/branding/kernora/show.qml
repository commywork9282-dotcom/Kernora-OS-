/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0

import QtQuick
import calamares.slideshow 1.0
import org.kernora.m3

Presentation {
    id: presentation

    property real progress: 0
    property string message

    readonly property bool wide: width >= 960
    readonly property real margin: wide ? Math.round(Math.max(40, Math.min(72, width * 0.05))) : 24
    readonly property real topSpace: Math.round(Math.max(88, Math.min(136, height * 0.15)))

    SetupAccessibility {}

    function symbol(name: string): url {
        return Qt.resolvedUrl("symbols/" + name + "_24px.svg");
    }

    function refresh(): void {
        const value = Number(Global.value("kernoraProgress"));
        presentation.progress = isNaN(value) ? 0 : Math.max(0, Math.min(1, value));
        const text = Global.value("kernoraProgressMessage");
        presentation.message = text ? String(text) : "";
    }

    Connections {
        target: Global
        function onChanged() {
            Qt.callLater(presentation.refresh);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: M3.surface
    }

    Column {
        x: presentation.margin
        y: presentation.topSpace
        width: presentation.wide ? presentation.width / 2 - presentation.margin - 40 : presentation.width - 2 * presentation.margin
        spacing: 0

        MText {
            width: parent.width
            role: "displaySmall"
            text: qsTr("Getting your computer ready…")
            wrapMode: Text.Wrap
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
            text: qsTr("This takes a few minutes. You can leave the computer alone: when everything is ready, Kernora will ask you to restart.")
            color: M3.surfaceVariantContent
            wrapMode: Text.Wrap
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.25
        }

        Item {
            width: 1
            height: 40
        }

        MLinearProgress {
            width: parent.width
            value: presentation.progress
            indeterminate: presentation.progress <= 0
            thickness: 6
        }

        Item {
            width: 1
            height: 12
        }

        MText {
            width: parent.width
            role: "bodyMedium"
            text: presentation.message.length > 0 ? presentation.message + " · " + Math.round(presentation.progress * 100) + "%" : ""
            color: M3.surfaceVariantContent
            elide: Text.ElideRight
        }
    }

    Item {
        id: art

        visible: presentation.wide
        x: presentation.width / 2 + 24
        y: presentation.topSpace
        width: presentation.width / 2 - presentation.margin - 24
        height: presentation.height - presentation.topSpace - 120

        readonly property real unit: Math.min(width / 2.2, height / 2.4)

        Repeater {
            model: [
                { shape: "cookie9", x: 0.10, y: 0.12, size: 1.0, tone: "primary", icon: "folder" },
                { shape: "circle", x: 0.58, y: 0.0, size: 0.6, tone: "tertiary", icon: "image" },
                { shape: "sunny", x: 0.62, y: 0.46, size: 0.72, tone: "secondary", icon: "settings" },
                { shape: "pill", x: 0.18, y: 0.66, size: 0.52, tone: "neutral", icon: "music_note" }
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
                    running: presentation.activatedInCalamares && M3.motionScale > 0
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
                    source: presentation.symbol(blob.modelData.icon)
                    color: blob.modelData.tone === "primary" ? M3.primaryContainerContent : blob.modelData.tone === "tertiary" ? M3.tertiaryContainerContent
                        : blob.modelData.tone === "secondary" ? M3.secondaryContainerContent : M3.surfaceVariantContent
                }
            }
        }
    }

    function onActivate() {
        presentation.refresh();
    }

    function onLeave() {}
}
