/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kernora.m3

PlasmaCore.Dialog {
    id: window

    property string digits: ""

    signal started(int seconds)

    type: PlasmaCore.Dialog.AppletPopup
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
    visible: false

    readonly property string backspacePath: "M360-200q-20 0-37.5-9T294-234L120-480l174-246q11-16 28.5-25t37.5-9h400q33 0 56.5 23.5T840-680v400q0 33-23.5 56.5T760-200H360Zm400-80v-400 400Zm-400 0h400v-400H360L218-480l142 200Zm96-40 104-104 104 104 56-56-104-104 104-104-56-56-104 104-104-104-56 56 104 104-104 104 56 56Z"
    readonly property string playPath: "M320-200v-560l440 280-440 280Z"

    function openFor(item: Item) {
        digits = "";
        const center = item.mapToGlobal(item.width / 2, item.height / 2);
        const screen = item.Window.window ? item.Window.window.screen : null;
        const left = screen ? screen.virtualX : 0;
        const top = screen ? screen.virtualY : 0;
        const right = left + (screen ? screen.width : 1920);
        const bottom = top + (screen ? screen.height : 1080);
        x = Math.round(Math.max(left + 8, Math.min(right - scene.width - 8, center.x - scene.width / 2)));
        y = Math.round(Math.max(top + 8, Math.min(bottom - scene.height - 8, center.y - scene.height / 2)));
        visible = true;
        requestActivate();
        scene.forceActiveFocus();
    }

    function press(key: string) {
        if (key === "back") {
            digits = digits.slice(0, -1);
            return;
        }
        let next = (digits + key).replace(/^0+/, "");
        if (next.length > 6) {
            return;
        }
        digits = next;
    }

    function seconds(): int {
        const padded = digits.padStart(6, "0");
        return Number(padded.slice(0, 2)) * 3600 + Number(padded.slice(2, 4)) * 60 + Number(padded.slice(4, 6));
    }

    function start() {
        const total = seconds();
        if (total <= 0) {
            return;
        }
        visible = false;
        started(total);
    }

    onActiveChanged: {
        if (!active) {
            visible = false;
        }
    }

    mainItem: Item {
        id: scene

        width: card.width + 48
        height: card.height + 48
        focus: true

        Keys.onPressed: event => {
            if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                window.press(String(event.key - Qt.Key_0));
            } else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
                window.press("back");
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                window.start();
            } else if (event.key === Qt.Key_Escape) {
                window.visible = false;
            } else {
                return;
            }
            event.accepted = true;
        }

        Kirigami.ShadowedRectangle {
            anchors.fill: card
            radius: 28
            color: M3.surfaceContainerHigh
            shadow.size: 18
            shadow.yOffset: 4
            shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.4 : 0.18)
        }

        Item {
            id: card

            x: 24
            y: 24
            width: 336
            height: 24 + 76 + 1 + 20 + 4 * 60 + 3 * 8 + 20 + 80 + 24

            Text {
                id: display

                readonly property string padded: window.digits.padStart(6, "0")
                readonly property int typed: window.digits.length
                readonly property var units: [
                    i18nc("@label timer hours, short", "h"),
                    i18nc("@label timer minutes, short", "m"),
                    i18nc("@label timer seconds, short", "s")
                ]

                function shade(lit: bool): string {
                    return String(lit ? M3.primary : M3.surfaceVariantContent);
                }

                function markup(): string {
                    let html = "";
                    for (let group = 0; group < 3; ++group) {
                        for (let digit = 0; digit < 2; ++digit) {
                            const index = group * 2 + digit;
                            html += '<span style="color:' + shade(index >= 6 - typed) + '">' + padded.charAt(index) + "</span>";
                        }
                        html += '<span style="font-size:20px;color:' + shade(group * 2 + 1 >= 6 - typed) + '">' + units[group] + "</span>";
                        if (group < 2) {
                            html += '<span style="font-size:30px">&nbsp;</span>';
                        }
                    }
                    return html;
                }

                anchors.horizontalCenter: parent.horizontalCenter
                y: 24
                height: 76
                verticalAlignment: Text.AlignVCenter
                text: markup()
                textFormat: Text.RichText
                font.family: M3.typeface
                font.pixelSize: 44
                font.features: { "tnum": 1 }
            }

            Rectangle {
                x: 24
                y: 24 + 76
                width: parent.width - 48
                height: 1
                color: M3.outlineVariant
            }

            Grid {
                id: keys

                x: (parent.width - width) / 2
                y: 24 + 76 + 1 + 20
                columns: 3
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "00", "0", "back"]

                    Item {
                        id: key

                        required property string modelData
                        readonly property bool back: modelData === "back"

                        width: 88
                        height: 60

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: key.back ? M3.secondaryContainer : M3.surfaceContainerHighest
                            scale: keyMouse.pressed ? 0.95 : 1

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: M3.surfaceContent
                                opacity: keyMouse.pressed ? 0.12 : keyMouse.containsMouse ? 0.08 : 0
                            }
                        }

                        Text {
                            visible: !key.back
                            anchors.centerIn: parent
                            text: key.modelData
                            color: M3.surfaceContent
                            font.family: M3.typeface
                            font.pixelSize: 26
                            textFormat: Text.PlainText
                        }

                        SymbolIcon {
                            visible: key.back
                            anchors.centerIn: parent
                            size: 24
                            color: M3.secondaryContainerContent
                            path: window.backspacePath
                        }

                        MouseArea {
                            id: keyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.press(key.modelData)
                        }
                    }
                }
            }

            Item {
                id: go

                anchors.horizontalCenter: parent.horizontalCenter
                y: keys.y + keys.height + 20
                width: 96
                height: 80
                scale: window.digits.length > 0 ? 1 : 0.5
                opacity: window.digits.length > 0 ? 1 : 0
                enabled: window.digits.length > 0

                Behavior on scale {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutBack
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 28
                    color: M3.primary

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: M3.primaryContent
                        opacity: goMouse.pressed ? 0.12 : goMouse.containsMouse ? 0.08 : 0
                    }
                }

                SymbolIcon {
                    anchors.centerIn: parent
                    size: 36
                    color: M3.primaryContent
                    path: window.playPath
                }

                MouseArea {
                    id: goMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.start()
                }
            }
        }
    }
}
