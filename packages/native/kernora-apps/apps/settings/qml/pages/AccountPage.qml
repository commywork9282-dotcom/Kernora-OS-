/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Account")

    Connections {
        target: Accounts
        function onFailed(message) {
            page.notify(message);
        }
        function onPasswordChanged() {
            page.notify(i18n("Your password was changed."));
        }
    }

    hero: Component {
        ColumnLayout {
            width: parent ? parent.width : 0
            spacing: 12

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                implicitWidth: 128
                implicitHeight: 128

                Avatar {
                    anchors.fill: parent
                    size: 128
                    source: Accounts.avatar
                    initials: Accounts.initials
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 40
                    height: 40
                    radius: 20
                    color: M3.primaryContainer
                    border.width: 3
                    border.color: M3.surface
                    MIcon {
                        anchors.centerIn: parent
                        size: 20
                        source: "document-edit"
                        color: M3.primaryContainerContent
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pictureDialog.open()
                    }
                }
            }
            MText {
                Layout.fillWidth: true
                role: "headlineSmall"
                text: Accounts.displayName
                horizontalAlignment: Text.AlignHCenter
            }
            MText {
                Layout.fillWidth: true
                role: "bodyMedium"
                text: Accounts.administrator ? i18n("Administrator · %1", Accounts.userName) : Accounts.userName
                color: M3.surfaceVariantContent
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Group {
        title: i18n("Your account")

        ListItem {
            title: i18n("Name")
            subtitle: Accounts.realName.length > 0 ? Accounts.realName : i18n("Not set")
            icon: "user-identity"
            accent: 0
            chevron: true
            onClicked: nameDialog.open()
        }
        ListItem {
            title: i18n("Picture")
            subtitle: i18n("Choose a picture or a photo of your own")
            icon: "folder-pictures"
            accent: 0
            chevron: true
            onClicked: pictureDialog.open()
        }
        ListItem {
            title: i18n("Password")
            subtitle: i18n("Used to log in, unlock the screen and install software")
            icon: "preferences-desktop-user-password"
            accent: 4
            chevron: true
            onClicked: passwordDialog.open()
        }
    }

    Group {
        title: i18n("Other accounts")

        ListItem {
            title: i18n("Manage accounts")
            subtitle: i18n("Add people who use this computer")
            icon: "system-users"
            iconStyle: "plain"
            chevron: true
            onClicked: page.open("AccountsPage.qml", {})
        }
    }

    Dialog {
        id: nameDialog
        title: i18n("Your name")
        text: i18n("Shown on the login screen and in the launcher.")
        acceptText: i18n("Save")
        acceptEnabled: nameField.text.trim().length > 0
        onOpened: {
            nameField.text = Accounts.realName;
            nameField.forceActiveFocus();
        }
        onAccepted: Accounts.setRealName(nameField.text.trim())
        InputField {
            id: nameField
            Layout.fillWidth: true
            label: i18n("Full name")
            onAccepted: {
                if (nameDialog.acceptEnabled) {
                    nameDialog.accept();
                }
            }
        }
    }

    Dialog {
        id: pictureDialog
        title: i18n("Choose a picture")
        preferredWidth: 520
        showAccept: false

        Item {
            Layout.fillWidth: true
            implicitWidth: pictureGrid.implicitWidth
            implicitHeight: pictureGrid.implicitHeight

            GridLayout {
                id: pictureGrid
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 5
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: pictureDialog.opened ? Accounts.stockAvatars() : []
                    delegate: Item {
                        id: stock
                        required property url modelData
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 72
                        implicitHeight: 72
                        Avatar {
                            anchors.fill: parent
                            size: 72
                            source: stock.modelData
                        }
                        MStateLayer {
                            anchors.fill: parent
                            radius: M3.classic ? M3.cornerCard : 36
                            hovered: stockMouse.containsMouse
                            pressed: stockMouse.pressed
                            pressPoint: Qt.point(stockMouse.mouseX, stockMouse.mouseY)
                        }
                        MouseArea {
                            id: stockMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Accounts.setAvatar(stock.modelData);
                                pictureDialog.close();
                            }
                        }
                    }
                }
            }
        }
        QQC2.Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            text: i18n("Choose a file…")
            icon.name: "document-open"
            onClicked: {
                pictureDialog.close();
                fileDialog.open();
            }
        }
    }

    Dialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose a picture")
        nameFilters: [i18n("Pictures (*.png *.jpg *.jpeg *.webp *.avif)")]
        currentFolder: Files.standardFolder("pictures")
        onAccepted: Accounts.setAvatar(selectedFile)
    }

    Dialog {
        id: passwordDialog

        readonly property bool matches: newPassword.text === repeatPassword.text
        readonly property bool longEnough: newPassword.text.length >= 8

        icon: "preferences-desktop-user-password"
        title: i18n("Change password")
        text: i18n("Use at least 8 characters. The system asks for your current password to confirm.")
        acceptText: i18n("Change")
        acceptEnabled: longEnough && matches
        onOpened: {
            newPassword.text = "";
            repeatPassword.text = "";
            newPassword.forceActiveFocus();
        }
        onAccepted: {
            Accounts.setPassword(newPassword.text);
            newPassword.text = "";
            repeatPassword.text = "";
        }

        InputField {
            id: newPassword
            Layout.fillWidth: true
            label: i18n("New password")
            password: true
            errorText: text.length > 0 && !passwordDialog.longEnough ? i18n("At least 8 characters") : ""
        }
        InputField {
            id: repeatPassword
            Layout.fillWidth: true
            label: i18n("Repeat the new password")
            password: true
            errorText: text.length > 0 && !passwordDialog.matches ? i18n("The passwords are different") : ""
            onAccepted: {
                if (passwordDialog.acceptEnabled) {
                    passwordDialog.accept();
                }
            }
        }
    }
}
