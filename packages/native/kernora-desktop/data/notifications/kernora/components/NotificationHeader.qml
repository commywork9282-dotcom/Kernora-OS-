/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

import org.kernora.m3

RowLayout {
    id: notificationHeading

    property ModelInterface modelInterface: ModelInterface {}
    property alias closeButtonTooltip: headingButtons.closeButtonTooltip
    property bool showIcon: false

    readonly property bool critical: modelInterface.urgency === NotificationManager.Notifications.CriticalUrgency

    spacing: 8

    Kirigami.Icon {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        source: modelInterface.applicationIconSource
        visible: notificationHeading.showIcon && valid
    }

    MIcon {
        size: 18
        source: "dialog-warning"
        color: M3.error
        visible: notificationHeading.critical
    }

    MText {
        id: headingLabel
        Layout.fillWidth: true
        role: "labelLarge"
        color: notificationHeading.critical ? M3.error : M3.surfaceVariantContent
        elide: Text.ElideMiddle
        text: [modelInterface.applicationName, modelInterface.originName, headingButtons.ageText]
            .filter(part => part && part.length > 0).join(" · ")

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            active: headingButtons.agoText !== ""
            subText: modelInterface.time ? modelInterface.time.toLocaleString(Qt.locale(), Locale.LongFormat) : ""
        }
    }

    HeadingButtons {
        id: headingButtons
        modelInterface: notificationHeading.modelInterface
    }
}
