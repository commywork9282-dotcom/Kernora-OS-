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
import org.kernora.store
import "components"

Page {
    id: page

    readonly property var app: QQC2.ApplicationWindow.window
    property int revision: 0
    readonly property var allJob: { revision; return Store.state("*updates"); }
    readonly property bool updatingAll: allJob.busy === true
    readonly property int extra: Math.max(0, Store.pendingUpdates - Store.updateCount)

    title: i18n("Updates")
    subtitle: Store.pendingUpdates > 0
        ? (Store.updateCount > 0 ? i18np("%1 app has a new version", "%1 apps have a new version", Store.updateCount) : i18n("App components have new versions"))
        : Store.checkingUpdates ? i18n("Checking for updates…")
        : Store.updateError.length > 0 ? i18n("Could not check for updates") : i18n("Your apps are up to date")
    canGoBack: app ? app.narrow : false
    cornerRadius: app && !app.narrow ? (M3.classic ? M3.cornerCard : 28) : 0
    maximumContentWidth: 860
    onBack: app.goBack()

    Connections {
        target: Store
        function onAppChanged(id: string): void {
            if (id === "*updates") {
                page.revision += 1;
            }
        }
    }

    AppModel {
        id: updates
        filter: Store.Updates
    }

    ColumnLayout {
        width: parent.width
        spacing: 16
        visible: Store.pendingUpdates > 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: !page.updatingAll
            MButton {
                variant: "filled"
                icon: "system-software-update"
                text: i18n("Update all")
                enabled: Store.busyCount === 0 && !Store.checkingUpdates && Store.updateError.length === 0
                onClicked: Store.updateAll()
            }
            MText {
                Layout.fillWidth: true
                role: "bodyMedium"
                color: M3.surfaceVariantContent
                wrapMode: Text.Wrap
                text: i18n("Apps keep working while they update.")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            visible: page.updatingAll
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                MText {
                    role: "titleSmall"
                    text: page.allJob.status || ""
                }
                LinearProgress {
                    Layout.fillWidth: true
                    indeterminate: page.allJob.progress === undefined || page.allJob.progress < 0
                    value: Math.max(0, page.allJob.progress || 0) / 100
                }
            }
            MButton {
                variant: "tonal"
                text: i18n("Cancel")
                onClicked: Store.cancel("*updates")
            }
        }
    }

    Group {
        width: parent.width
        title: i18n("Apps")
        visible: updates.count > 0

        Repeater {
            model: updates
            delegate: ListItem {
                id: row

                required property string appId
                required property string name
                required property string iconSource
                required property bool busy
                required property int progress
                required property string status

                title: name
                subtitle: busy ? status : i18n("A new version is ready")
                leading: Component {
                    AppIcon {
                        size: 40
                        name: row.iconSource
                    }
                }
                trailing: Component {
                    MButton {
                        variant: "tonal"
                        text: row.busy ? (row.progress >= 0 ? i18n("%1%", row.progress) : i18n("Working…")) : i18n("Update")
                        enabled: !row.busy && !page.updatingAll
                        onClicked: Store.update(row.appId)
                    }
                }
                onClicked: page.app.openApp(row.appId)
            }
        }

        ListItem {
            visible: page.extra > 0
            title: i18n("App components")
            subtitle: i18np("%1 shared component used by your apps", "%1 shared components used by your apps", page.extra)
            icon: "package-x-generic"
            iconStyle: "circle"
            interactive: false
        }
    }

    EmptyState {
        width: parent.width
        visible: Store.pendingUpdates === 0 && !Store.checkingUpdates && Store.updateError.length === 0
        icon: "checkmark"
        title: i18n("Everything is up to date")
        text: i18n("The store checks for new versions of your apps by itself.")
    }

    LinearProgress {
        width: parent.width
        visible: Store.checkingUpdates
        indeterminate: true
    }

    EmptyState {
        width: parent.width
        visible: Store.updateError.length > 0
        icon: "network-offline"
        title: i18n("Could not check for updates")
        text: i18n("Check your internet connection and try again. Your installed apps are still available.")
        actionText: i18n("Try again")
        onActionTriggered: Store.refresh()
    }

    Group {
        width: parent.width
        title: i18n("System")

        ListItem {
            title: i18n("System updates")
            subtitle: i18n("Lumo and the apps that come with it update in Settings")
            icon: "system-software-update"
            accent: 0
            chevron: true
            onClicked: Store.openSystemUpdates()
        }
    }
}
