/*
    SPDX-FileCopyrightText: 2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQml

import org.kde.notificationmanager as NotificationManager

import org.kde.plasma.private.notifications as Notifications

import org.kernora.m3
import org.kernora.ui

import "../global"

ColumnLayout {
    id: jobItem

    property ModelInterface modelInterface

    readonly property int totalFiles: modelInterface.jobDetails && modelInterface.jobDetails.totalFiles || 0

    readonly property alias menuOpen: otherFileActionsMenu.visible

    spacing: 8

    Notifications.FileInfo {
        id: fileInfo
        url: jobItem.totalFiles === 1 ? modelInterface.jobDetails.effectiveDestUrl : ""
    }

    RowLayout {
        id: progressRow
        Layout.fillWidth: true
        spacing: 12

        LinearProgress {
            id: progressBar
            Layout.fillWidth: true
            wavy: modelInterface.applicationName !== "Quick Share"
            opacity: modelInterface.jobState === NotificationManager.Notifications.JobStateSuspended ? 0.38 : 1
            value: modelInterface.percentage / 100
            indeterminate: visible && Window.window && Window.window.visible && modelInterface.percentage < 1
                           && modelInterface.jobState === NotificationManager.Notifications.JobStateRunning
                           && (modelInterface.jobDetails.processedBytes === 0 || modelInterface.jobDetails.totalBytes === 0)
                           && modelInterface.jobDetails.processedFiles === 0
        }

        MText {
            id: progressText
            role: "labelMedium"
            color: M3.surfaceVariantContent
            visible: !progressBar.indeterminate
            text: i18ndc("plasma_applet_org.kde.plasma.notifications", "Percentage of a job", "%1%", modelInterface.percentage || "0")
        }

        MIconButton {
            id: suspendButton

            readonly property bool paused: modelInterface.jobState === NotificationManager.Notifications.JobStateSuspended

            visible: modelInterface.suspendable
            variant: "tonal"
            size: 36
            iconSize: 20
            icon: paused ? "media-playback-start" : "media-playback-pause"
            text: paused ? i18ndc("plasma_applet_org.kde.plasma.notifications", "Resume paused job", "Resume")
                         : i18ndc("plasma_applet_org.kde.plasma.notifications", "Pause running job", "Pause")
            onClicked: paused ? modelInterface.resumeJobClicked()
                              : modelInterface.suspendJobClicked()
        }

        MIconButton {
            id: killButton
            visible: modelInterface.killable
            variant: "tonal"
            size: 36
            iconSize: 20
            icon: "window-close"
            text: i18ndc("plasma_applet_org.kde.plasma.notifications", "Cancel running job", "Cancel")
            onClicked: modelInterface.killJobClicked()
        }
    }

    MButton {
        id: expandButton

        property bool checked: false

        Layout.leftMargin: -16
        variant: "text"
        icon: checked ? "arrow-up" : "arrow-down"
        text: i18ndc("plasma_applet_org.kde.plasma.notifications", "Hides/expands item details", "Details")
        visible: modelInterface.jobDetails && modelInterface.jobDetails.hasDetails
        onClicked: checked = !checked
    }

    Loader {
        Layout.fillWidth: true
        Layout.preferredWidth: Globals.popupWidth
        Layout.preferredHeight: item ? item.implicitHeight : 0
        active: expandButton.checked && expandButton.visible
        visible: active
        sourceComponent: JobDetails {
            modelInterface: jobItem.modelInterface
        }
    }

    RowLayout {
        id: fileActionsRow
        Layout.fillWidth: true
        spacing: 8
        visible: modelInterface.jobDetails.effectiveDestUrl.toString() !== "" && !fileInfo.error

        MButton {
            id: openButton
            Layout.maximumWidth: fileActionsRow.width - otherFileActionsButton.width - fileActionsRow.spacing
            variant: "tonal"
            text: i18nd("plasma_applet_org.kde.plasma.notifications", "Open")
            onClicked: modelInterface.openUrl(modelInterface.jobDetails.effectiveDestUrl)

            states: [
                State {
                    when: modelInterface.jobDetails && modelInterface.jobDetails.totalFiles !== 1
                    PropertyChanges {
                        target: openButton
                        text: i18nd("plasma_applet_org.kde.plasma.notifications", "Open Containing Folder")
                        icon: "folder-open"
                    }
                },
                State {
                    when: fileInfo.openAction !== null
                    PropertyChanges {
                        target: openButton
                        text: fileInfo.openAction.text.replace("&", "")
                        icon: ""
                        visible: fileInfo.openAction.enabled
                        onClicked: {
                            fileInfo.openAction.trigger();
                            modelInterface.fileActionInvoked(fileInfo.openAction);
                        }
                    }
                }
            ]
        }

        Item {
            Layout.fillWidth: true
        }

        MIconButton {
            id: otherFileActionsButton
            icon: "application-menu"
            text: i18nd("plasma_applet_org.kde.plasma.notifications", "More Options…")
            onClicked: {
                otherFileActionsMenu.visualParent = otherFileActionsButton;
                otherFileActionsMenu.open(-1, -1);
            }

            Notifications.FileMenu {
                id: otherFileActionsMenu
                url: modelInterface.jobDetails.effectiveDestUrl
                onActionTriggered: action => modelInterface.fileActionInvoked(action)
            }
        }
    }

    states: [
        State {
            when: modelInterface.jobState === NotificationManager.Notifications.JobStateStopped
            PropertyChanges {
                target: progressRow
                visible: false
            }
            PropertyChanges {
                target: expandButton
                visible: false
                checked: false
            }
        }
    ]
}
