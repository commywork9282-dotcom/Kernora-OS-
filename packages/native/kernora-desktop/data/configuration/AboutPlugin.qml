/*
    SPDX-FileCopyrightText: 2018 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
    SPDX-FileCopyrightText: 2020 David Redondo <kde@david-redondo.de>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kernora.m3
import org.kernora.ui as UI

KCM.SimpleKCM {
    id: page
    title: i18n("About")

    property var metaData: Plasmoid.metaData

    function plain(text: string): string {
        return text.replace(/\s*[:：]\s*$/, "");
    }

    Component {
        id: personDelegate

        UI.ListItem {
            required property var modelData
            icon: "user"
            title: modelData.name
            subtitle: modelData.task || ""
            interactive: false

            trailing: Component {
                Row {
                    spacing: 0
                    UI.IconButton {
                        visible: !!modelData.emailAddress
                        iconName: "mail-sent"
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Send an email to %1", modelData.emailAddress)
                        onClicked: Qt.openUrlExternally("mailto:%1".arg(modelData.emailAddress))
                    }
                    UI.IconButton {
                        visible: !!modelData.webAddress
                        iconName: "globe"
                        text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:tooltip %1 url", "Open website %1", modelData.webAddress)
                        onClicked: Qt.openUrlExternally(modelData.webAddress)
                    }
                }
            }
        }
    }

    UI.Dialog {
        id: licenseDialog
        title: page.metaData.license
        showReject: false
        preferredWidth: 560

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(licenseText.implicitHeight, 360)
            contentWidth: availableWidth

            MText {
                id: licenseText
                width: parent ? parent.width : implicitWidth
                role: "bodySmall"
                wrapMode: Text.WordWrap
                text: page.metaData.licenseText
                textFormat: Text.PlainText
            }
        }
    }

    ColumnLayout {
        spacing: 20

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 8
                implicitWidth: 88
                implicitHeight: 88
                radius: M3.classic ? width / 2 : 28
                color: M3.primaryContainer

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 52
                    height: 52
                    source: page.metaData.iconName || page.metaData.pluginId
                    fallback: "application-x-plasma"
                }
            }
            MText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                role: "headlineSmall"
                wrapMode: Text.Wrap
                text: page.metaData.name
                textFormat: Text.PlainText
            }
            MText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                role: "labelLarge"
                color: M3.primary
                text: page.metaData.version
                visible: text.length > 0
            }
            MText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                role: "bodyMedium"
                color: M3.surfaceVariantContent
                wrapMode: Text.Wrap
                text: page.metaData.description
                textFormat: Text.PlainText
                visible: text.length > 0
            }
        }

        UI.Group {
            Layout.fillWidth: true
            title: i18nd("plasma_shell_org.kde.plasma.desktop", "Copyright")

            UI.ListItem {
                visible: page.metaData.copyrightText.length > 0
                title: page.metaData.copyrightText
                interactive: false
            }
            UI.ListItem {
                visible: page.metaData.website.length > 0
                icon: "globe"
                title: page.metaData.website
                chevron: true
                onClicked: Qt.openUrlExternally(page.metaData.website)
            }
            UI.ListItem {
                icon: "license"
                title: page.plain(i18nd("plasma_shell_org.kde.plasma.desktop", "License:"))
                subtitle: page.metaData.license
                chevron: true
                Accessible.description: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:whatsthis", "View license text")
                onClicked: licenseDialog.open()
            }
        }

        UI.Group {
            Layout.fillWidth: true
            visible: page.metaData.authors.length > 0
            title: i18nd("plasma_shell_org.kde.plasma.desktop", "Authors")

            Repeater {
                model: page.metaData.authors
                delegate: personDelegate
            }
        }

        UI.Group {
            Layout.fillWidth: true
            visible: page.metaData.otherContributors.length > 0
            title: i18nd("plasma_shell_org.kde.plasma.desktop", "Credits")

            Repeater {
                model: page.metaData.otherContributors
                delegate: personDelegate
            }
        }

        UI.Group {
            Layout.fillWidth: true
            visible: page.metaData.translators.length > 0
            title: i18nd("plasma_shell_org.kde.plasma.desktop", "Translators")

            Repeater {
                model: page.metaData.translators
                delegate: personDelegate
            }
        }

        MButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 12
            variant: "outlined"
            icon: "tools-report-bug"
            text: i18nd("plasma_shell_org.kde.plasma.desktop", "Report a Bug…")
            visible: page.metaData.bugReportUrl.length > 0
            onClicked: Qt.openUrlExternally(page.metaData.bugReportUrl)
        }
    }
}
