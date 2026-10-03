/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kernora.m3

Kirigami.SelectableLabel {
    id: bodyLabel

    property ModelInterface modelInterface

    Layout.fillWidth: true
    Layout.alignment: Qt.AlignTop

    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    font: M3.bodyMedium
    color: M3.surfaceVariantContent

    wrapMode: TextEdit.Wrap

    text: "<style>a { color: " + M3.primary + "; }</style>" + modelInterface.body

    selectByMouse: !Kirigami.Settings.tabletMode

    onLinkActivated: Qt.openUrlExternally(link)

    onClicked: modelInterface.bodyClicked()

    Binding {
        target: modelInterface
        property: "bodyCursorShape"
        value: bodyLabel.cursorShape
    }
}
