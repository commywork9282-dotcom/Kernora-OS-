/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui

Item {
    id: usersPage

    Rectangle {
        anchors.fill: parent
        color: M3.surface
    }

    Flickable {
        anchors.fill: parent
        contentHeight: form.implicitHeight + 48
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: form
            x: 40
            y: 32
            width: Math.min(parent.width - 80, 620)
            spacing: 14

            MText {
                Layout.fillWidth: true
                role: "headlineSmall"
                text: qsTr("Pick your user name and credentials to login and perform admin tasks")
                wrapMode: Text.Wrap
            }

            MText { Layout.topMargin: 8; role: "titleSmall"; color: M3.primary; text: qsTr("What is your name?") }
            InputField {
                id: fullName
                Layout.fillWidth: true
                label: qsTr("Your full name")
                icon: "user-identity"
                enabled: config.isEditable("fullName")
                text: config.fullName
                onTextChanged: config.setFullName(text)
            }

            MText { Layout.topMargin: 8; role: "titleSmall"; color: M3.primary; text: qsTr("What name do you want to use to log in?") }
            InputField {
                id: loginName
                Layout.fillWidth: true
                label: qsTr("Login name")
                icon: "system-users"
                enabled: config.isEditable("loginName")
                text: config.loginName
                input.validator: RegularExpressionValidator { regularExpression: /[a-z_][a-z0-9_-]*[$]?$/ }
                errorText: text === "root" ? qsTr("root is not allowed as username.")
                    : (text.length > 0 && !input.acceptableInput ? qsTr("Only lowercase letters, numbers, underscore and hyphen are allowed.") : "")
                supportingText: qsTr("If more than one person will use this computer, you can create multiple accounts after installation.")
                onTextChanged: {
                    if (input.acceptableInput && text !== "root") {
                        config.setLoginName(text);
                    }
                }
            }

            MText { Layout.topMargin: 8; role: "titleSmall"; color: M3.primary; text: qsTr("What is the name of this computer?") }
            InputField {
                id: hostName
                Layout.fillWidth: true
                label: qsTr("Computer name")
                icon: "computer"
                text: config.hostname
                input.validator: RegularExpressionValidator { regularExpression: /[a-zA-Z0-9][-a-zA-Z0-9_]+/ }
                errorText: text === "localhost" ? qsTr("localhost is not allowed as hostname.")
                    : (text.length > 0 && !input.acceptableInput ? qsTr("Only letters, numbers, underscore and hyphen are allowed, minimal of two characters.") : "")
                supportingText: qsTr("This name will be used if you make the computer visible to others on a network.")
                onTextChanged: {
                    if (input.acceptableInput && text !== "localhost") {
                        config.setHostName(text);
                    }
                }
            }

            MText { Layout.topMargin: 8; role: "titleSmall"; color: M3.primary; text: qsTr("Choose a password to keep your account safe.") }
            InputField {
                id: password
                Layout.fillWidth: true
                label: qsTr("Password")
                icon: "preferences-desktop-user-password"
                password: true
                text: config.userPassword
                onTextChanged: config.setUserPassword(text)
            }
            InputField {
                id: repeat
                Layout.fillWidth: true
                label: qsTr("Repeat password")
                icon: "preferences-desktop-user-password"
                password: true
                text: config.userPasswordSecondary
                onTextChanged: config.setUserPasswordSecondary(text)
                errorText: config.userPasswordValidity === 2 && text.length > 0 ? config.userPasswordMessage : ""
                supportingText: config.userPasswordValidity === 1 ? config.userPasswordMessage
                    : qsTr("Enter the same password twice, so that it can be checked for typing errors.")
            }

            Group {
                Layout.fillWidth: true
                Layout.topMargin: 12
                ListItem {
                    title: qsTr("Log in automatically without asking for the password")
                    icon: "system-lock-screen"
                    iconStyle: "plain"
                    checkable: true
                    checked: config.doAutoLogin
                    onToggled: on => config.setAutoLogin(on)
                }
                ListItem {
                    visible: config.writeRootPassword
                    title: qsTr("Reuse user password as root password")
                    subtitle: qsTr("Use the same password for the administrator account.")
                    icon: "preferences-security"
                    iconStyle: "plain"
                    checkable: true
                    checked: config.reuseUserPasswordForRoot
                    onToggled: on => config.setReuseUserPasswordForRoot(on)
                }
            }
        }
    }

    function onActivate() {
        fullName.forceActiveFocus();
    }
    function onLeave() {}
}
