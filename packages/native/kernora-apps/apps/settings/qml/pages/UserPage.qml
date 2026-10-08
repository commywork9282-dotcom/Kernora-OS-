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
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    property var user
    property bool leaving: false

    readonly property var current: {
        const found = Accounts.users.find(u => user && u.path === user.path);
        return found || user || {};
    }

    title: current.displayName || ""
    subtitle: current.userName || ""

    Connections {
        target: Accounts
        function onFailed(message) {
            page.notify(message);
        }
        function onPasswordChanged() {
            page.notify(i18n("The password was changed."));
        }
        function onUsersChanged() {
            if (!page.leaving && page.user && !Accounts.users.some(u => u.path === page.user.path)) {
                page.leaving = true;
                page.back();
            }
        }
    }

    hero: Component {
        ColumnLayout {
            width: parent ? parent.width : 0
            spacing: 12

            Avatar {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                size: 112
                source: page.current.avatar || ""
                initials: String(page.current.displayName || "?").slice(0, 1).toUpperCase()
            }
        }
    }

    Group {
        ListItem {
            title: i18n("Administrator")
            subtitle: i18n("Can install software and change settings for everyone")
            icon: "security-high"
            iconStyle: "plain"
            checkable: true
            enabled: Accounts.administrator
            checked: !!page.current.administrator
            onToggled: on => Accounts.setUserAdministrator(page.current.path, on)
        }
        ListItem {
            title: i18n("Set a new password")
            subtitle: i18n("When the password is forgotten")
            icon: "preferences-desktop-user-password"
            iconStyle: "plain"
            enabled: Accounts.administrator
            chevron: true
            onClicked: passwordDialog.open()
        }
    }

    Group {
        ListItem {
            title: i18n("Delete the account")
            icon: "user-trash"
            iconStyle: "plain"
            destructive: true
            enabled: Accounts.administrator
            onClicked: deleteDialog.open()
        }
    }

    Dialog {
        id: passwordDialog

        readonly property bool matches: newPassword.text === repeatPassword.text
        readonly property bool longEnough: newPassword.text.length >= 8

        icon: "preferences-desktop-user-password"
        title: i18n("New password for %1", page.current.displayName || "")
        text: i18n("Use at least 8 characters.")
        acceptText: i18n("Change")
        acceptEnabled: longEnough && matches
        onOpened: {
            newPassword.text = "";
            repeatPassword.text = "";
            newPassword.forceActiveFocus();
        }
        onAccepted: Accounts.setUserPassword(page.current.path, newPassword.text)

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
        }
    }

    Dialog {
        id: deleteDialog

        icon: "user-trash"
        title: i18n("Delete %1?", page.current.displayName || "")
        text: i18n("The account can no longer log in.")
        acceptText: i18n("Delete")
        destructive: true
        onOpened: removeFiles.checked = false
        onAccepted: Accounts.deleteUser(page.current.path, removeFiles.checked)

        ListItem {
            id: removeFiles
            Layout.fillWidth: true
            title: i18n("Delete their files too")
            subtitle: i18n("Documents, pictures and everything else in the home folder")
            checkable: true
            onToggled: on => checked = on
        }
    }
}
