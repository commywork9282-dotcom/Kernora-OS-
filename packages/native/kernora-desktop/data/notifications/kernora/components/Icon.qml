/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3

Item {
    id: iconItem
    Layout.alignment: Qt.AlignTop

    property ModelInterface modelInterface
    property bool suppressed: false
    readonly property bool dragging: jobIconLoader.item?.dragging ?? false
    readonly property bool jobIconShown: jobIconLoader.item?.shown ?? false

    implicitWidth: 48
    implicitHeight: 48

    visible: (picture.valid && !suppressed) || jobIconShown

    Picture {
        id: picture
        anchors.fill: parent
        radius: M3.cornerImage
        visible: !iconItem.jobIconShown
        source: iconItem.modelInterface.icon
    }

    Loader {
        id: jobIconLoader
        anchors.fill: parent
        active: modelInterface.jobDetails?.effectiveDestUrl ?? false
        sourceComponent: JobIconItem {
            modelInterface: iconItem.modelInterface
        }
    }
}
