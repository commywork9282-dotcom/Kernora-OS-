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

    readonly property bool on: QuickShare.enabled
    readonly property string visibility: QuickShare.visibility
    readonly property bool everyoneForAWhile: visibility === "temporary"
    readonly property var recent: QuickShare.transfers.slice().reverse().slice(0, 6)

    function remaining(seconds: int): string {
        return seconds > 60 ? i18n("%1 min", Math.ceil(seconds / 60)) : i18n("%1 sec", Math.max(1, seconds));
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

    Item {
        width: parent.width
        implicitHeight: art.height + blurb.implicitHeight + 36

        MShape {
            id: art
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 136
            height: 136
            shape: M3.classic ? "circle" : "cookie9"
            color: page.on ? M3.primaryContainer : M3.surfaceContainerHighest
            Behavior on color { ColorAnimation { duration: M3.durationMedium2 } }
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 24000
                loops: Animation.Infinite
                running: page.on && art.visible && M3.motionScale > 0 && !M3.classic
            }
        }
        MIcon {
            anchors.centerIn: art
            size: 60
            source: "kernora-quickshare"
            color: page.on ? M3.primaryContainerContent : M3.surfaceVariantContent
        }
        MText {
            id: blurb
            anchors.top: art.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 420)
            horizontalAlignment: Text.AlignHCenter
            role: "bodyMedium"
            color: M3.surfaceVariantContent
            wrapMode: Text.Wrap
            text: i18n("Share files, photos and links with Android phones and computers nearby.")
        }
    }

    HeroSwitch {
        width: parent.width
        title: i18n("Use Quick Share")
        checked: page.on
        enabled: QuickShare.available
        onToggled: checked => QuickShare.setEnabled(checked)
    }

    Group {
        enabled: page.on

        ListItem {
            title: i18n("Send and receive")
            subtitle: i18n("Open Quick Share")
            icon: "kernora-quickshare"
            accent: 0
            chevron: true
            onClicked: Process.startDetached("kernora-share", [])
        }
    }

    Group {
        title: i18n("Device name")
        note: i18n("How your device appears to others")
        enabled: page.on

        ListItem {
            title: QuickShare.name
            icon: "kernora-laptop"
            accent: 0
            chevron: true
            onClicked: nameDialog.open()
        }
    }

    Group {
        title: i18n("Device visibility")
        note: page.on ? i18n("Your device visibility controls who can share with you while your screen is unlocked. Every transfer still waits for you to accept it.")
                      : i18n("Quick Share is off. Nobody can see this computer.")
        enabled: page.on

        RadioRow {
            title: i18n("Everyone")
            subtitle: i18n("Any device nearby can share with you")
            checked: page.visibility === "everyone"
            onClicked: QuickShare.setVisibility("everyone")
        }
        RadioRow {
            title: i18n("Hidden")
            subtitle: i18n("No one can share with you")
            checked: page.visibility !== "everyone"
            onClicked: QuickShare.setVisibility("hidden")
        }
        ListItem {
            visible: page.visibility !== "everyone"
            title: i18n("Visible to everyone")
            subtitle: page.everyoneForAWhile ? i18n("%1 left", page.remaining(QuickShare.visibleFor)) : i18n("For 10 min")
            icon: "kernora-timer"
            iconStyle: "plain"
            checkable: true
            checked: page.everyoneForAWhile
            onToggled: on => QuickShare.setHighVisibility(on)
        }
        ListItem {
            visible: page.visibility !== "everyone"
            title: i18n("Ask when a device nearby is sharing")
            subtitle: i18n("Offer to become visible when a phone nearby opens Quick Share")
            icon: "preferences-desktop-notification"
            iconStyle: "plain"
            checkable: true
            checked: QuickShare.askNearby
            onToggled: on => QuickShare.setAskNearby(on)
        }
    }

    Group {
        title: i18n("Received files")
        enabled: page.on

        ListItem {
            title: i18n("Save received files to")
            subtitle: page.folderName(QuickShare.folder)
            icon: "folder-download"
            iconStyle: "plain"
            chevron: true
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
                icon: modelData.outgoing ? "kernora-upload" : "folder-download"
                iconStyle: "plain"
                interactive: modelData.phase === "finished" && !modelData.outgoing && modelData.kind === "files"
                onClicked: Process.openUrl(Qt.resolvedUrl("file://" + QuickShare.folder))
            }
        }
    }

    Dialog {
        id: nameDialog
        title: i18n("Device name")
        text: i18n("How your device appears to others in Quick Share.")
        acceptText: i18n("Rename")
        acceptEnabled: nameField.text.trim().length > 0 && nameField.text.trim().length <= 60
        onOpened: {
            nameField.text = QuickShare.name;
            nameField.forceActiveFocus();
        }
        onAccepted: QuickShare.setName(nameField.text.trim())
        InputField {
            id: nameField
            Layout.fillWidth: true
            label: i18n("Device name")
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
