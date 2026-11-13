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

QtObject {
    id: app

    readonly property var args: Array.from(startArguments).map(String)
    readonly property string mode: args[0] || ""
    property var window: null

    property Timer quitter: Timer {
        interval: 0
        onTriggered: Qt.quit()
    }

    property Component popup: Component {
        Window {
            id: window

            readonly property string file: app.args[1] || ""
            property var info: AppGroups.group(file)
            readonly property var apps: info.apps || []
            readonly property int columns: Math.min(4, Math.max(2, apps.length))
            readonly property int margin: 32
            property bool wasActive: false
            property bool leaving: false

            flags: Qt.Dialog | Qt.FramelessWindowHint
            color: "transparent"
            width: card.width + margin * 2
            height: card.height + margin * 2
            visible: true
            title: info.name || ""

            function refresh(): void {
                info = AppGroups.group(file);
                if (!info.file) {
                    leave();
                }
            }

            function leave(): void {
                if (leaving) {
                    return;
                }
                leaving = true;
                exit.start();
            }

            onActiveChanged: {
                if (active) {
                    wasActive = true;
                } else if (wasActive && !menu.opened) {
                    leave();
                }
            }

            Component.onCompleted: {
                if (!info.file) {
                    app.quitter.start();
                    return;
                }
                requestActivate();
            }

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (nameField.activeFocus) {
                        nameField.text = window.info.name || "";
                        surface.forceActiveFocus();
                    } else {
                        window.leave();
                    }
                }
            }

            MultiEffect {
                source: card
                anchors.fill: card
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.36
                shadowBlur: 1.0
                shadowVerticalOffset: 8
                blurMax: 48
                opacity: card.opacity
                scale: card.scale
            }

            Rectangle {
                id: card

                x: window.margin
                y: window.margin
                width: window.columns * 96 + 40
                height: content.implicitHeight + 40
                radius: M3.classic ? M3.cornerDialog : 28
                color: M3.surfaceContainer
                opacity: 0
                scale: 0.92
                transformOrigin: Item.Top

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
                    NumberAnimation { target: card; property: "scale"; to: 0.96; duration: M3.durationShort4; easing.type: Easing.InCubic }
                    onFinished: Qt.quit()
                }

                Item {
                    id: surface
                    anchors.fill: parent
                    focus: true
                }

                ColumnLayout {
                    id: content
                    x: 20
                    y: 20
                    width: parent.width - 40
                    spacing: 12

                    Grid {
                        Layout.alignment: Qt.AlignHCenter
                        columns: window.columns

                        Repeater {
                            model: window.apps

                            delegate: Item {
                                id: tile

                                required property var modelData

                                width: 96
                                height: 100

                                Rectangle {
                                    id: highlight
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 20
                                    color: "transparent"

                                    MStateLayer {
                                        radius: highlight.radius
                                        color: M3.surfaceContent
                                        hovered: tileMouse.containsMouse
                                        pressed: tileMouse.pressed
                                        pressPoint: Qt.point(tileMouse.mouseX - 2, tileMouse.mouseY - 2)
                                    }
                                }

                                AppIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 10
                                    size: 52
                                    name: tile.modelData.icon
                                }

                                MText {
                                    x: 6
                                    y: 68
                                    width: parent.width - 12
                                    role: "labelMedium"
                                    color: M3.surfaceContent
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: tile.modelData.name
                                }

                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            menu.app = tile.modelData.id;
                                            menu.openAt(tile, mouse.x, mouse.y);
                                            return;
                                        }
                                        window.leaving = true;
                                        AppGroups.launch(window.file, tile.modelData.id, () => Qt.quit());
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 22
                        color: nameField.activeFocus ? M3.surfaceContainerHighest : "transparent"

                        TextInput {
                            id: nameField
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: activeFocus ? TextInput.AlignLeft : TextInput.AlignHCenter
                            font: M3.titleMedium
                            color: M3.surfaceContent
                            selectionColor: M3.primary
                            selectedTextColor: M3.primaryContent
                            selectByMouse: true
                            maximumLength: 40
                            text: window.info.name || ""
                            Accessible.name: i18nc("@label", "Group name")
                            onEditingFinished: {
                                if (text.trim().length > 0 && text.trim() !== window.info.name) {
                                    AppGroups.rename(window.file, text);
                                    window.refresh();
                                } else {
                                    text = window.info.name || "";
                                }
                            }
                        }
                    }

                }

                MMenu {
                    id: menu

                    property string app: ""

                    items: [
                        {
                            icon: "list-remove",
                            text: i18nc("@action:inmenu", "Remove from group"),
                            action: () => {
                                AppGroups.takeOut(window.file, menu.app);
                                window.refresh();
                            }
                        }
                    ]
                }
            }
        }
    }

    Component.onCompleted: {
        if (mode === "drop" && args.length > 2) {
            AppGroups.drop(args[1], args.slice(2));
            quitter.start();
        } else if (mode === "open" && args.length > 1) {
            window = popup.createObject(app);
        } else {
            quitter.start();
        }
    }
}
