/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts

import org.kernora.m3

import "../components" as Components


BaseDelegate {
    id: delegateRoot

    body: bodyLabel
    icon: icon
    footer: footerLoader.item

    Item {
        implicitWidth: 16
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: -4
            spacing: 8

            Components.Summary {
                id: summaryLabel
                Layout.topMargin: lineCount > 1 ? Math.max(0, (headingElement.implicitHeight - metrics.height) / 2) : 0
                modelInterface: delegateRoot.modelInterface
            }

            Item {
                Layout.fillWidth: true
                visible: !summaryLabel.visible
            }

            MText {
                role: "labelMedium"
                color: M3.surfaceVariantContent
                text: headingElement.ageText
                visible: text.length > 0
            }

            Components.HeadingButtons {
                id: headingElement
                Layout.alignment: Qt.AlignRight | Qt.AlignTop
                modelInterface: delegateRoot.modelInterface
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: delegateRoot.hasBodyText || icon.visible

            Components.Body {
                id: bodyLabel
                Layout.fillWidth: true
                visible: delegateRoot.hasBodyText
                modelInterface: delegateRoot.modelInterface
            }

            Components.Icon {
                id: icon
                modelInterface: delegateRoot.modelInterface
            }
        }

        Components.FooterLoader {
            id: footerLoader
            Layout.fillWidth: true
            Layout.topMargin: 12
            modelInterface: delegateRoot.modelInterface
            iconContainerItem: icon
        }
    }
}
