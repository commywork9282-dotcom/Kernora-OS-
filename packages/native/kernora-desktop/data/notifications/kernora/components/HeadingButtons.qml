/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts

import org.kde.notificationmanager as NotificationManager

import org.kde.coreaddons as KCoreAddons

import org.kernora.m3

import "../global"

RowLayout {
    id: headingButtons

    property ModelInterface modelInterface: ModelInterface {}
    property string closeButtonTooltip: i18nd("plasma_applet_org.kde.plasma.notifications", "Close")

    readonly property string __applicationName: modelInterface.applicationName + (modelInterface.originName ? " · " + modelInterface.originName : "")

    readonly property string ageText: generateRemainingText() || agoText
    property string agoText: ""

    Connections {
        target: modelInterface
        function onTimeChanged() {
            headingButtons.updateAgoText()
        }
    }
    function updateAgoText() {
        agoText = generateAgoText();
    }

    spacing: 0

    Component.onCompleted: updateAgoText()

    Connections {
        target: Globals
        function onTimeChanged() {
            headingButtons.updateAgoText()
        }
    }

    function generateAgoText() {
        const time = modelInterface.time;
        if (!time || isNaN(time.getTime())
                || modelInterface.jobState === NotificationManager.Notifications.JobStateRunning
                || modelInterface.jobState === NotificationManager.Notifications.JobStateSuspended) {
            return "";
        }

        var deltaMinutes = Math.floor((Date.now() - time.getTime()) / 1000 / 60);
        if (deltaMinutes < 1) {
            return modelInterface.inHistory
                ? i18ndc("plasma_applet_org.kde.plasma.notifications", "Notification was added less than a minute ago, keep short", "Just now")
                : "";
        }

        if (deltaMinutes < 60) {
            return i18ndcp("plasma_applet_org.kde.plasma.notifications", "Notification was added minutes ago, keep short", "%1 min ago", "%1 min ago", deltaMinutes);
        }
        if (deltaMinutes < 60 * 22) {
            return Qt.formatTime(time, Qt.locale().timeFormat(Locale.ShortFormat).replace(/.ss?/i, ""));
        }

        return KCoreAddons.Format.formatRelativeDate(time, Locale.ShortFormat);
    }

    function generateRemainingText() {
        if (modelInterface.notificationType !== NotificationManager.Notifications.JobType
            || modelInterface.jobState !== NotificationManager.Notifications.JobStateRunning) {
            return "";
        }

        var details = modelInterface.jobDetails;
        if (!details || !details.speed) {
            return "";
        }

        var remaining = details.totalBytes - details.processedBytes;
        if (remaining <= 0) {
            return "";
        }

        var eta = remaining / details.speed;
        if (eta < 0.5) {
            return "";
        }

        if (eta < 60) {
            return i18ndcp("plasma_applet_org.kde.plasma.notifications", "seconds remaining, keep short",
                          "%1 s remaining", "%1 s remaining", Math.round(eta));
        }
        if (eta < 60 * 60) {
            return i18ndcp("plasma_applet_org.kde.plasma.notifications", "minutes remaining, keep short",
                          "%1 min remaining", "%1 min remaining",
                          Math.round(eta / 60));
        }
        if (eta < 60 * 60 * 5) {
            return i18ndcp("plasma_applet_org.kde.plasma.notifications", "hours remaining, keep short",
                          "%1 h remaining", "%1 h remaining",
                          Math.round(eta / 60 / 60));
        }

        return "";
    }

    MIconButton {
        id: configureButton
        visible: modelInterface.configurable
        size: 32
        iconSize: 18
        icon: "configure"
        text: modelInterface.configureActionLabel || i18nd("plasma_applet_org.kde.plasma.notifications", "Configure")
        Accessible.description: __applicationName
        onClicked: modelInterface.configureClicked()
    }

    MIconButton {
        id: dismissButton
        visible: modelInterface.dismissable
        size: 32
        iconSize: 18
        icon: modelInterface.dismissed ? "window-restore" : "window-minimize"
        text: modelInterface.dismissed
            ? i18ndc("plasma_applet_org.kde.plasma.notifications", "Opposite of minimize", "Restore")
            : i18nd("plasma_applet_org.kde.plasma.notifications", "Minimize")
        Accessible.description: __applicationName
        onClicked: modelInterface.dismissClicked()
    }

    MIconButton {
        id: closeButton
        visible: modelInterface.closable
        size: 32
        iconSize: 18
        icon: "window-close"
        text: headingButtons.closeButtonTooltip
        Accessible.description: __applicationName
        onClicked: modelInterface.closeClicked()
    }
}
