/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

Window {
    id: dialog

    readonly property int margin: 40
    readonly property var question: JSON.parse(String(startArguments[0] || "{}"))
    readonly property var app: Process.application("waydroid." + (question.package || ""))
    readonly property var buttons: question.buttons || []
    readonly property bool stacked: buttons.length > 2 || buttons.some(text => text.length > 16)
    property int answer: 0
    property bool leaving: false

    flags: Qt.Dialog | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    width: 400 + margin * 2
    height: card.implicitHeight + margin * 2
    visible: true
    title: question.title || app.name || ""

    function choose(value: int): void {
        if (leaving) {
            return;
        }
        leaving = true;
        answer = value;
        exit.start();
    }

    Shortcut {
        sequence: "Escape"
        onActivated: dialog.choose(0)
    }

    MultiEffect {
        source: card
        anchors.fill: card
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.4
        shadowBlur: 1.0
        shadowVerticalOffset: 8
        blurMax: 48
        opacity: card.opacity
        scale: card.scale
    }

    Rectangle {
        id: card
        x: dialog.margin
        y: dialog.margin
        width: dialog.width - dialog.margin * 2
        implicitHeight: content.implicitHeight + 48
        height: implicitHeight
        radius: M3.classic ? M3.cornerDialog : 28
        color: M3.surfaceContainerHigh
        opacity: 0
        scale: 0.92

        MSpring {
            dampingRatio: M3.springExpressiveDefaultDamping
            response: M3.springExpressiveDefaultResponse
            onValueChanged: {
                card.opacity = Math.min(1, value);
                card.scale = 0.92 + 0.08 * value;
            }
            Component.onCompleted: animateTo(1)
        }

        ParallelAnimation {
            id: exit
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: M3.durationShort4; easing.type: Easing.InCubic }
            NumberAnimation { target: card; property: "scale"; to: 0.94; duration: M3.durationShort4; easing.type: Easing.InCubic }
            onFinished: Qt.exit(10 + dialog.answer)
        }

        DragHandler {
            target: null
            onActiveChanged: {
                if (active) {
                    dialog.startSystemMove();
                }
            }
        }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 0

            AppIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 56
                name: dialog.app.icon || "kernora-android"
            }

            MText {
                Layout.fillWidth: true
                Layout.topMargin: 16
                visible: text.length > 0
                horizontalAlignment: Text.AlignHCenter
                role: "headlineSmall"
                text: dialog.question.title || ""
                wrapMode: Text.Wrap
            }

            MText {
                Layout.fillWidth: true
                Layout.topMargin: 12
                visible: text.length > 0
                horizontalAlignment: Text.AlignHCenter
                role: "bodyMedium"
                color: M3.surfaceVariantContent
                text: dialog.question.message || ""
                wrapMode: Text.Wrap
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 24
                columns: dialog.stacked ? 1 : dialog.buttons.length + 1
                columnSpacing: 8
                rowSpacing: 8

                Item {
                    visible: !dialog.stacked
                    Layout.fillWidth: true
                }
                Repeater {
                    model: dialog.buttons

                    delegate: MButton {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: dialog.stacked
                        variant: index === 0 ? "filled" : "tonal"
                        text: modelData
                        onClicked: dialog.choose(index + 1)
                    }
                }
            }
        }
    }
}
