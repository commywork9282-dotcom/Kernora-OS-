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

    title: i18n("Accounts")
    subtitle: i18n("People who use this computer")

    Connections {
        target: Accounts
        function onFailed(message) {
            page.notify(message);
        }
        function onUserCreated(userName) {
            page.notify(i18n("The account “%1” was added.", userName));
        }
    }

    function transliterate(text: string): string {
        const table = {
            "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh", "з": "z", "и": "i",
            "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t",
            "у": "u", "ф": "f", "х": "kh", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "shch", "ъ": "", "ы": "y", "ь": "",
            "э": "e", "ю": "yu", "я": "ya"
        };
        const word = text.trim().toLowerCase().split(/\s+/)[0] || "";
        let out = "";
        for (const ch of word) {
            out += table[ch] !== undefined ? table[ch] : ch;
        }
        out = out.replace(/[^a-z0-9_-]/g, "");
        return out.replace(/^[^a-z_]+/, "").slice(0, 32);
    }

    Group {
        Repeater {
            model: Accounts.users
            delegate: ListItem {
                id: row
                required property var modelData
                title: modelData.displayName + (modelData.current ? " " + i18n("(you)") : "")
                subtitle: (modelData.administrator ? i18n("Administrator") : i18n("Standard account")) + " · " + modelData.userName
                chevron: true
                leading: Component {
                    Avatar {
                        size: 40
                        source: row.modelData.avatar
                        initials: String(row.modelData.displayName).slice(0, 1).toUpperCase()
                    }
                }
                onClicked: row.modelData.current ? page.back() : page.open("UserPage.qml", { user: row.modelData })
            }
        }
        ListItem {
            title: i18n("Add an account")
            icon: "list-add"
            iconStyle: "plain"
            enabled: Accounts.administrator
            onClicked: addDialog.open()
        }
    }

    MText {
        width: parent.width
        visible: !Accounts.administrator
        leftPadding: 16
        rightPadding: 16
        role: "bodySmall"
        color: M3.surfaceVariantContent
        wrapMode: Text.Wrap
        text: i18n("Only an administrator can add accounts.")
    }

    Dialog {
        id: addDialog

        property bool userNameEdited: false
        readonly property string userNameError: userName.text.length > 0 ? Accounts.validateUserName(userName.text) : ""
        readonly property bool matches: password.text === repeat.text
        readonly property bool longEnough: password.text.length >= 8

        icon: "system-users"
        title: i18n("Add an account")
        acceptText: i18n("Add")
        acceptEnabled: realName.text.trim().length > 0 && userName.text.length > 0 && userNameError.length === 0 && longEnough && matches
        preferredWidth: 460
        onOpened: {
            realName.text = "";
            userName.text = "";
            password.text = "";
            repeat.text = "";
            administrator.checked = false;
            userNameEdited = false;
            realName.forceActiveFocus();
        }
        onAccepted: Accounts.createUser(userName.text, realName.text, password.text, administrator.checked)

        InputField {
            id: realName
            Layout.fillWidth: true
            label: i18n("Name")
            onTextChanged: {
                if (!addDialog.userNameEdited) {
                    userName.text = page.transliterate(text);
                }
            }
        }
        InputField {
            id: userName
            Layout.fillWidth: true
            label: i18n("User name")
            supportingText: i18n("Used to log in; small Latin letters and digits")
            errorText: addDialog.userNameError
        }
        Connections {
            target: userName.input
            function onTextEdited() {
                addDialog.userNameEdited = true;
            }
        }
        InputField {
            id: password
            Layout.fillWidth: true
            label: i18n("Password")
            password: true
            errorText: text.length > 0 && !addDialog.longEnough ? i18n("At least 8 characters") : ""
        }
        InputField {
            id: repeat
            Layout.fillWidth: true
            label: i18n("Repeat the password")
            password: true
            errorText: text.length > 0 && !addDialog.matches ? i18n("The passwords are different") : ""
        }
        ListItem {
            id: administrator
            Layout.fillWidth: true
            title: i18n("Administrator")
            subtitle: i18n("Can install software and change settings for everyone")
            icon: "security-high"
            iconStyle: "plain"
            checkable: true
            onToggled: on => checked = on
        }
    }
}
