/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

import org.kernora.m3

Item {
    id: badge

    property ModelInterface modelInterface

    readonly property bool critical: modelInterface.urgency === NotificationManager.Notifications.CriticalUrgency
    readonly property string iconName: {
        const icon = modelInterface.iconName;
        if (icon.length === 0 || icon.startsWith("/") || icon.includes(":")) {
            return "";
        }
        return icon;
    }
    readonly property bool showsPicture: !appIcon.valid && iconName.length === 0 && picture.valid

    Layout.alignment: Qt.AlignTop
    implicitWidth: 40
    implicitHeight: 40

    Kirigami.Icon {
        id: appIcon
        anchors.fill: parent
        source: badge.modelInterface.applicationIconSource || ""
        visible: valid
    }

    Picture {
        id: picture
        anchors.fill: parent
        radius: width / 2
        visible: badge.showsPicture
        source: badge.modelInterface.icon
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: !appIcon.valid && !badge.showsPicture
        color: badge.critical ? M3.errorContainer : M3.primaryContainer

        Kirigami.Icon {
            anchors.centerIn: parent
            width: 24
            height: 24
            source: badge.iconName || "notifications"
            color: badge.critical ? M3.errorContainerContent : M3.primaryContainerContent
        }
    }
}
