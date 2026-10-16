/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import org.kernora.store
import "components"

Item {
    id: page

    property string view: Store.updateCount > 0 ? "updates" : "installed"

    readonly property var app: QQC2.ApplicationWindow.window
    readonly property bool canGoBack: QQC2.StackView.index > 0
    readonly property real contentWidth: Math.min(width - 48, 1200)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.preferredWidth: page.contentWidth
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
            spacing: 8

            IconButton {
                visible: page.canGoBack
                iconName: Qt.application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
                text: i18n("Back")
                onClicked: page.app.goBack()
            }
            MText {
                Layout.fillWidth: true
                role: "headlineSmall"
                text: i18n("My apps")
            }
        }

        StoreTabs {
            Layout.preferredWidth: page.contentWidth
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            tabs: [
                {value: "updates", label: Store.updateCount > 0 ? i18n("Updates (%1)", Store.updateCount) : i18n("Updates")},
                {value: "installed", label: i18n("Installed")}
            ]
            current: page.view
            onSelected: value => page.view = value
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: M3.outlineVariant
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: page.view === "updates" ? updatesView : installedView
        }
    }

    Component {
        id: updatesView
        UpdatesPage {}
    }

    Component {
        id: installedView
        ListPage {
            filter: Store.Installed
            showHeader: false
        }
    }
}
