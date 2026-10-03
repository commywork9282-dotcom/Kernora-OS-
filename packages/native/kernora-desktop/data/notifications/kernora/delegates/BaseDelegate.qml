/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts

import "../components" as Components

RowLayout {
    id: baseDelegate

    Layout.fillWidth: true

    property Components.ModelInterface modelInterface: Components.ModelInterface {}

    property Components.Body body
    property Components.Icon icon
    property Item footer
    readonly property bool menuOpen: Boolean(body?.menuOpen)
                                     || Boolean(footer?.menuOpen)
    readonly property bool dragging: Boolean(icon?.dragging) || Boolean(footer?.dragging)
    readonly property bool hasBodyText: modelInterface.body.length > 0

    spacing: 16

    Accessible.role: Accessible.NoRole
    Accessible.name: modelInterface.summary
    Accessible.description: modelInterface.accessibleDescription
}
