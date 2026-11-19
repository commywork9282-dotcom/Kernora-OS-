/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import org.kernora.m3
import org.kernora.ui

PixelPage {
    id: page

    icon: "person"
    title: qsTr("Create your account")
    description: qsTr("You will use it to sign in to Kernora and to install apps.")

    readonly property string faces: "file:///usr/share/kernora/faces/"
    readonly property string avatars: "file:///usr/share/kernora/avatars/"
    readonly property var stock: ["01-ember-layers", "02-violet-rings", "03-teal-diagonal", "04-rose-swell", "05-blue-layers",
        "06-amber-rings", "07-green-diagonal", "08-ember-diagonal", "09-violet-layers", "10-teal-swell", "11-rose-rings",
        "12-blue-diagonal", "13-green-rings", "14-amber-layers"]
    property string avatar: ""
    readonly property string avatarSource: avatar.length > 0 ? avatar : faces + M3.colour + ".png"

    readonly property int strength: {
        const value = config.userPassword;
        if (value.length === 0) {
            return 0;
        }
        let kinds = 0;
        for (const pattern of [/[a-zа-яё]/, /[A-ZА-ЯЁ]/, /[0-9]/, /[^A-Za-zА-Яа-яЁё0-9]/]) {
            kinds += pattern.test(value) ? 1 : 0;
        }
        return Math.max(1, Math.min(4, (value.length >= 8 ? 1 : 0) + (value.length >= 12 ? 1 : 0) + (kinds >= 2 ? 1 : 0) + (kinds >= 3 ? 1 : 0)));
    }

    function chooseAvatar(path: string): void {
        page.avatar = path;
        if (path.length > 0) {
            Global.insert("kernoraAvatar", path.replace(/^file:\/\//, ""));
        } else {
            Global.remove("kernoraAvatar");
        }
    }

    below: Column {
        width: parent ? parent.width : 600
        spacing: 24

        RoundedClip {
            width: 168
            height: 168
            radius: 84

            Image {
                anchors.fill: parent
                source: page.avatarSource
                sourceSize: Qt.size(336, 336)
                fillMode: Image.PreserveAspectCrop
            }
        }

        Grid {
            x: -6
            columns: Math.max(4, Math.floor((page.paneWidth + 4) / 68))
            spacing: 4

            Item {
                width: 64
                height: 64

                Rectangle {
                    anchors.centerIn: parent
                    width: 52
                    height: 52
                    radius: 26
                    color: M3.surfaceContainerHigh
                }

                MIcon {
                    anchors.centerIn: parent
                    size: 24
                    source: page.symbol("photo_library")
                    color: M3.surfaceVariantContent
                }

                MStateLayer {
                    anchors.centerIn: parent
                    width: 52
                    height: 52
                    radius: 26
                    color: M3.surfaceContent
                    hovered: photoMouse.containsMouse
                    pressed: photoMouse.pressed
                }

                MouseArea {
                    id: photoMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: photoDialog.open()
                }
            }

            Repeater {
                model: [""].concat(page.stock.map(name => page.avatars + name + ".png"))

                Item {
                    id: choice

                    required property int index
                    required property string modelData
                    readonly property bool selected: page.avatar === modelData

                    width: 64
                    height: 64

                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        visible: choice.selected
                        color: M3.surfaceContainerHighest
                    }

                    RoundedClip {
                        anchors.centerIn: parent
                        width: 52
                        height: 52
                        radius: 26

                        Image {
                            anchors.fill: parent
                            source: choice.modelData.length > 0 ? choice.modelData : page.faces + M3.colour + ".png"
                            sourceSize: Qt.size(104, 104)
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.chooseAvatar(choice.modelData)
                    }
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: form.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: form

            width: parent.width
            spacing: 2

            SetupField {
                id: fullName
                first: true
                symbol: "person"
                label: qsTr("Your full name")
                enabled: config.isEditable("fullName")
                text: config.fullName
                onTextChanged: config.setFullName(text)
                onAccepted: loginName.forceActiveFocus()
            }

            SetupField {
                id: loginName
                symbol: "account_circle"
                label: qsTr("Login name")
                enabled: config.isEditable("loginName")
                text: config.loginName
                input.validator: RegularExpressionValidator { regularExpression: /[a-z_][a-z0-9_-]*[$]?$/ }
                errorText: text === "root" ? qsTr("root is not allowed as username.")
                    : (text.length > 0 && !input.acceptableInput ? qsTr("Only lowercase letters, numbers, underscore and hyphen are allowed.") : "")
                onTextChanged: {
                    if (input.acceptableInput && text !== "root") {
                        config.setLoginName(text);
                    }
                }
                onAccepted: hostName.forceActiveFocus()
            }

            SetupField {
                id: hostName
                last: true
                symbol: "computer"
                label: qsTr("Computer name")
                text: config.hostname
                input.validator: RegularExpressionValidator { regularExpression: /[a-zA-Z0-9][-a-zA-Z0-9_]+/ }
                errorText: text === "localhost" ? qsTr("localhost is not allowed as hostname.")
                    : (text.length > 0 && !input.acceptableInput ? qsTr("Only letters, numbers, underscore and hyphen are allowed, minimal of two characters.") : "")
                onTextChanged: {
                    if (input.acceptableInput && text !== "localhost") {
                        config.setHostName(text);
                    }
                }
                onAccepted: password.forceActiveFocus()
            }

            Item {
                width: 1
                height: 22
            }

            SetupField {
                id: password
                first: true
                symbol: "password"
                label: qsTr("Password")
                password: true
                text: config.userPassword
                onTextChanged: config.setUserPassword(text)
                onAccepted: repeat.forceActiveFocus()
            }

            SetupField {
                id: repeat
                last: true
                symbol: "password"
                label: qsTr("Repeat password")
                password: true
                revealed: password.revealed
                text: config.userPasswordSecondary
                onTextChanged: config.setUserPasswordSecondary(text)
                errorText: config.userPasswordValidity === 2 && text.length > 0 ? config.userPasswordMessage : ""
                onAccepted: if (ViewManager.nextEnabled) ViewManager.next()
            }

            Item {
                width: 1
                height: 14
            }

            Row {
                id: meter

                visible: page.strength > 0
                width: parent.width
                spacing: 4

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index
                        width: (meter.width - 3 * meter.spacing) / 4
                        height: 6
                        radius: 3
                        color: index < page.strength ? (page.strength <= 1 ? M3.error : M3.primary) : M3.surfaceContainerHighest
                    }
                }
            }

            Item {
                width: 1
                height: page.strength > 0 ? 8 : 0
            }

            MText {
                visible: page.strength > 0
                x: 4
                role: "bodyMedium"
                text: page.strength <= 1 ? qsTr("Weak password") : page.strength <= 2 ? qsTr("Fair password") : qsTr("Strong password")
                color: page.strength <= 1 ? M3.error : M3.primary
            }

            Item {
                width: 1
                height: 22
            }

            Group {
                width: parent.width

                ListItem {
                    title: qsTr("Log in automatically without asking for the password")
                    icon: "system-lock-screen"
                    iconStyle: "plain"
                    checkable: true
                    checked: config.doAutoLogin
                    onToggled: on => config.setAutoLogin(on)
                }
            }
        }
    }

    FileDialog {
        id: photoDialog
        title: qsTr("Choose a picture")
        nameFilters: [qsTr("Images") + " (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: page.chooseAvatar(selectedFile.toString())
    }

    function onActivate() {
        fullName.forceActiveFocus();
    }

    function onLeave() {}
}
