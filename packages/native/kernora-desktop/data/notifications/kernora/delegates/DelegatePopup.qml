/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kquickcontrolsaddons as KQuickControlsAddons

import "../components" as Components


BaseDelegate {
    id: delegateRoot

    body: bodyLabel
    icon: icon
    footer: footerLoader.item

    Accessible.role: Accessible.Notification

    Components.AppBadge {
        id: badge
        modelInterface: delegateRoot.modelInterface
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 0

        Components.NotificationHeader {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.rightMargin: -4
            modelInterface: delegateRoot.modelInterface
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 2

                Components.Summary {
                    id: summary
                    modelInterface: delegateRoot.modelInterface

                    KQuickControlsAddons.MouseEventListener {
                        anchors.fill: parent
                        visible: modelInterface.hasDefaultAction && !delegateRoot.hasBodyText
                        onClicked: modelInterface.defaultActionInvoked();
                    }
                }

                KQuickControlsAddons.MouseEventListener {
                    Layout.fillWidth: true
                    Layout.maximumHeight: 20 * modelInterface.maximumLineCount
                    implicitHeight: bodyLabel.implicitHeight
                    clip: true
                    visible: delegateRoot.hasBodyText
                    onClicked: {
                        if (modelInterface.hasDefaultAction) {
                            modelInterface.defaultActionInvoked();
                        }
                    }

                    Components.Body {
                        id: bodyLabel
                        width: parent.width
                        modelInterface: delegateRoot.modelInterface
                        Accessible.ignored: true
                    }
                }
            }

            Components.Icon {
                id: icon
                modelInterface: delegateRoot.modelInterface
                suppressed: badge.showsPicture
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
