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

Item {
    id: page

    readonly property var app: QQC2.ApplicationWindow.window
    readonly property real contentWidth: Math.min(width - 48, 1200)
    property int revision: 0
    readonly property var allJob: { revision; return Store.state("*updates"); }
    readonly property bool updatingAll: allJob.busy === true
    readonly property int extra: Math.max(0, Store.pendingUpdates - Store.updateCount)

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

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + 64
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column
            x: (flick.width - page.contentWidth) / 2
            y: 16
            width: page.contentWidth
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                visible: !page.updatingAll && Store.pendingUpdates > 0

                MText {
                    Layout.fillWidth: true
                    role: "titleMedium"
                    wrapMode: Text.Wrap
                    text: Store.pendingUpdates > 0
                        ? (Store.updateCount > 0 ? i18np("%1 app has a new version", "%1 apps have a new version", Store.updateCount) : i18n("App components have new versions"))
                        : Store.checkingUpdates ? i18n("Checking for updates…")
                        : Store.updateError.length > 0 ? i18n("Could not check for updates") : i18n("Your apps are up to date")
                }
                MButton {
                    visible: Store.pendingUpdates > 0
                    variant: "filled"
                    text: i18n("Update all")
                    enabled: Store.busyCount === 0 && !Store.checkingUpdates && Store.updateError.length === 0
                    onClicked: Store.updateAll()
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
                    variant: "outlined"
                    text: i18n("Cancel")
                    onClicked: Store.cancel("*updates")
                }
            }

            LinearProgress {
                Layout.fillWidth: true
                visible: Store.checkingUpdates
                indeterminate: true
            }

            Repeater {
                model: updates
                delegate: Item {
                    id: row

                    required property string appId
                    required property string name
                    required property string iconSource
                    required property string developer
                    required property bool busy
                    required property int progress
                    required property string status

                    Layout.fillWidth: true
                    Layout.preferredHeight: 80

                    MStateLayer {
                        radius: M3.classic ? M3.cornerCard : 16
                        color: M3.surfaceContent
                        hovered: rowMouse.containsMouse
                        pressed: rowMouse.pressed
                        pressPoint: Qt.point(rowMouse.mouseX, rowMouse.mouseY)
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.app.openApp(row.appId)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 16

                        AppPlate {
                            size: 56
                            iconName: row.iconSource
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            MText {
                                Layout.fillWidth: true
                                role: "titleMedium"
                                text: row.name
                                elide: Text.ElideRight
                            }
                            MText {
                                Layout.fillWidth: true
                                role: "bodyMedium"
                                color: M3.surfaceVariantContent
                                elide: Text.ElideRight
                                text: row.busy ? row.status : (row.developer.length > 0 ? row.developer : i18n("A new version is ready"))
                            }
                            LinearProgress {
                                Layout.fillWidth: true
                                visible: row.busy
                                indeterminate: row.progress < 0
                                value: Math.max(0, row.progress) / 100
                            }
                        }
                        MButton {
                            variant: "outlined"
                            text: row.busy ? (row.progress >= 0 ? i18n("%1%", row.progress) : i18n("Working…")) : i18n("Update")
                            enabled: !row.busy && !page.updatingAll
                            onClicked: Store.update(row.appId)
                        }
                    }
                }
            }

            MText {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                visible: page.extra > 0
                role: "bodyMedium"
                color: M3.surfaceVariantContent
                wrapMode: Text.Wrap
                text: i18np("Also %1 shared component used by your apps.", "Also %1 shared components used by your apps.", page.extra)
            }

            EmptyState {
                Layout.fillWidth: true
                Layout.topMargin: 32
                visible: Store.pendingUpdates === 0 && !Store.checkingUpdates && Store.updateError.length === 0
                icon: "checkmark"
                title: i18n("Everything is up to date")
                text: i18n("The store checks for new versions of your apps by itself.")
            }

            EmptyState {
                Layout.fillWidth: true
                Layout.topMargin: 32
                visible: Store.updateError.length > 0
                icon: "network-offline"
                title: i18n("Could not check for updates")
                text: i18n("Check your internet connection and try again. Your installed apps are still available.")
                actionText: i18n("Try again")
                onActionTriggered: Store.refresh()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.preferredHeight: 1
                color: M3.outlineVariant
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                MIcon {
                    Layout.leftMargin: 8
                    size: 24
                    source: "system-software-update"
                    color: M3.surfaceVariantContent
                }
                MText {
                    Layout.fillWidth: true
                    role: "bodyMedium"
                    color: M3.surfaceVariantContent
                    wrapMode: Text.Wrap
                    text: i18n("Kernora and the apps that come with it update in Settings")
                }
                MButton {
                    variant: "text"
                    text: i18n("Open Settings")
                    onClicked: Store.openSystemUpdates()
                }
            }
        }
    }

    MScrollIndicator {
        flickable: flick
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
}
