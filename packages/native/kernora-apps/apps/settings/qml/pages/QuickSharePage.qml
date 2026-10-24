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

    title: i18n("Quick Share")

    readonly property string visibility: QuickShare.visibility
    readonly property var recent: QuickShare.transfers.slice().reverse().slice(0, 6)

    function minutes(seconds: int): string {
        return i18np("%1 minute left", "%1 minutes left", Math.max(1, Math.ceil(seconds / 60)));
    }

    function folderName(path: string): string {
        const home = decodeURIComponent(String(Files.standardFolder("home")).replace(/^file:\/\//, ""));
        if (path.length === 0) {
            return "";
        }
        return path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
    }

    function transferText(transfer: var): string {
        const what = transfer.kind === "files"
            ? (transfer.files.length === 1 ? transfer.files[0] : i18np("%1 file", "%1 files", transfer.files.length))
            : (transfer.kind === "url" ? i18n("A link") : (transfer.kind === "wifi" ? i18n("A Wi-Fi network") : i18n("Text")));
        switch (transfer.phase) {
        case "finished":
            return transfer.outgoing ? i18n("%1 · sent", what) : i18n("%1 · received", what);
        case "rejected":
            return i18n("%1 · declined", what);
        case "cancelled":
            return i18n("%1 · cancelled", what);
        case "failed":
            return i18n("%1 · not finished", what);
        case "waiting":
            return i18n("%1 · waiting", what);
        default:
            return transfer.total > 0
                ? i18n("%1 · %2%", what, Math.round(100 * transfer.done / transfer.total))
                : what;
        }
    }

    Group {
        title: i18n("Who can see this computer")
        note: QuickShare.available
            ? i18n("Phones and computers find it over Wi-Fi on the same network. Bluetooth helps wake up a phone that is sharing.")
            : i18n("Quick Share is not running.")

        RadioRow {
            title: i18n("Everyone")
            subtitle: i18n("Any device nearby can ask to send you files")
            checked: page.visibility === "everyone"
            onClicked: QuickShare.setVisibility("everyone")
        }
        RadioRow {
            title: i18n("Everyone for 10 minutes")
            subtitle: page.visibility === "temporary" ? page.minutes(QuickShare.visibleFor) : i18n("Then hidden again")
            checked: page.visibility === "temporary"
            onClicked: QuickShare.setVisibility("temporary")
        }
        RadioRow {
            title: i18n("Hidden")
            subtitle: i18n("Nobody sees this computer until you allow it")
            checked: page.visibility === "hidden"
            onClicked: QuickShare.setVisibility("hidden")
        }
        ListItem {
            title: i18n("Ask when someone nearby is sharing")
            subtitle: i18n("While hidden, offer to become visible when a phone nearby opens Quick Share")
            icon: "preferences-desktop-notification"
            iconStyle: "plain"
            checkable: true
            enabled: page.visibility !== "everyone"
            checked: QuickShare.askNearby
            onToggled: on => QuickShare.setAskNearby(on)
        }
    }

    Group {
        title: i18n("This computer")

        ListItem {
            title: i18n("Name")
            subtitle: QuickShare.name
            icon: "computer"
            accent: 0
            chevron: true
            enabled: QuickShare.available
            onClicked: nameDialog.open()
        }
        ListItem {
            title: i18n("Save received files to")
            subtitle: page.folderName(QuickShare.folder)
            icon: "folder-download"
            iconStyle: "plain"
            chevron: true
            enabled: QuickShare.available
            onClicked: folderDialog.open()
        }
    }

    Group {
        title: i18n("Recent")
        visible: page.recent.length > 0

        Repeater {
            model: page.recent

            delegate: ListItem {
                required property var modelData
                title: modelData.device.length > 0 ? modelData.device : i18n("Unknown device")
                subtitle: page.transferText(modelData)
                icon: modelData.outgoing ? "document-send" : "folder-download"
                iconStyle: "plain"
                interactive: modelData.phase === "finished" && !modelData.outgoing && modelData.kind === "files"
                onClicked: Process.openUrl(Qt.resolvedUrl("file://" + QuickShare.folder))
            }
        }
    }

    Dialog {
        id: nameDialog
        title: i18n("Name")
        text: i18n("Phones nearby see this computer by this name in Quick Share.")
        acceptText: i18n("Rename")
        acceptEnabled: nameField.text.trim().length > 0
        onOpened: {
            nameField.text = QuickShare.name;
            nameField.forceActiveFocus();
        }
        onAccepted: QuickShare.setName(nameField.text.trim())
        InputField {
            id: nameField
            Layout.fillWidth: true
            label: i18n("Name")
            onAccepted: {
                if (nameDialog.acceptEnabled) {
                    nameDialog.accept();
                }
            }
        }
    }

    Dialogs.FolderDialog {
        id: folderDialog
        title: i18n("Save received files to")
        currentFolder: "file://" + QuickShare.folder
        onAccepted: QuickShare.setFolder(selectedFolder)
    }
}
