/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts

import org.kde.notificationmanager as NotificationManager

import org.kernora.m3

MText {
    id: summaryLabel

    Layout.fillWidth: true

    property ModelInterface modelInterface
    property alias metrics: summaryLabelTextMetrics

    role: "titleSmall"
    color: M3.surfaceContent
    maximumLineCount: 3
    wrapMode: Text.Wrap
    elide: Text.ElideRight
    text: {
        if (modelInterface.notificationType === NotificationManager.Notifications.JobType) {
            if (modelInterface.jobState === NotificationManager.Notifications.JobStateSuspended) {
                if (modelInterface.summary) {
                    return i18ndc("plasma_applet_org.kde.plasma.notifications", "Job name, e.g. Copying is paused", "%1 (Paused)", modelInterface.summary);
                }
            } else if (modelInterface.jobState === NotificationManager.Notifications.JobStateStopped) {
                if (modelInterface.jobError) {
                    if (modelInterface.summary) {
                        return i18ndc("plasma_applet_org.kde.plasma.notifications", "Job name, e.g. Copying has failed", "%1 (Failed)", modelInterface.summary);
                    } else {
                        return i18nd("plasma_applet_org.kde.plasma.notifications", "Job Failed");
                    }
                } else {
                    if (modelInterface.summary) {
                        return i18ndc("plasma_applet_org.kde.plasma.notifications", "Job name, e.g. Copying has finished", "%1 (Finished)", modelInterface.summary);
                    } else {
                        return i18nd("plasma_applet_org.kde.plasma.notifications", "Job Finished");
                    }
                }
            }
        }
        if (modelInterface.summary && modelInterface.summary.toLocaleLowerCase().trim() != modelInterface.applicationName.toLocaleLowerCase().trim()) {
            return modelInterface.summary;
        }
        return "";
    }
    visible: text !== ""

    TextMetrics {
        id: summaryLabelTextMetrics
        font: summaryLabel.font
        text: summaryLabel.text
    }
}
