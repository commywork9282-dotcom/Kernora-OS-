/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick 2.8
import QtQml 2.15

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.kquickcontrolsaddons 2.0
import org.kde.kirigami 2.20 as Kirigami

import org.kde.coreaddons 1.0 as KCoreAddons
import org.kde.kcmutils as KCMUtils
import org.kde.config as KConfig

import org.kde.notificationmanager as NotificationManager

import org.kde.plasma.private.notifications 2.0 as Notifications

import "kernora" as Kernora
import "kernora/global"

PlasmoidItem {
    id: root

    property alias clearHistoryAction: clearHistory

    readonly property int unreadCount: Math.min(99, historyModel.unreadNotificationsCount)

    readonly property bool inhibitedOrBroken: Globals.inhibited || !NotificationManager.Server.valid

    readonly property bool inPanel: (Plasmoid.location === PlasmaCore.Types.TopEdge
        || Plasmoid.location === PlasmaCore.Types.RightEdge
        || Plasmoid.location === PlasmaCore.Types.BottomEdge
        || Plasmoid.location === PlasmaCore.Types.LeftEdge)

    readonly property int effectiveStatus: historyModel.activeJobsCount > 0
                     || historyModel.unreadNotificationsCount > 0
                     || Globals.inhibited ? PlasmaCore.Types.ActiveStatus
                                          : PlasmaCore.Types.PassiveStatus
    onEffectiveStatusChanged: {
        const status = effectiveStatus;
        if (status === PlasmaCore.Types.PassiveStatus) {
            Qt.callLater(function() {
                Plasmoid.status = status;
            });
        } else {
            Plasmoid.status = status;
        }
    }

    Plasmoid.status: effectiveStatus

    toolTipSubText: {
        var lines = [];

        if (jobAggregator.count > 0) {
            let description = i18np("%1 running job", "%1 running jobs", jobAggregator.count);

            if (jobAggregator.summary) {
                if (jobAggregator.percentage > 0) {
                    description = i18nc("Job title (percentage)", "%1 (%2%)", jobAggregator.summary, jobAggregator.percentage);
                } else {
                    description = jobAggregator.summary;
                }
            } else if (jobAggregator.percentage > 0) {
                description = i18np("%1 running job (%2%)", "%1 running jobs (%2%)", jobAggregator.count, jobAggregator.percentage);
            }

            lines.push(description);
        }

        if (!NotificationManager.Server.valid) {
            lines.push(i18n("Notification service not available"));
        } else {
            var actualUnread = historyModel.unreadNotificationsCount - Globals.popupNotificationsModel.activeNotificationsCount;
            if (actualUnread > 0) {
                lines.push(i18np("%1 unread notification", "%1 unread notifications", actualUnread));
            }

            if (Globals.inhibited) {
                var inhibitedUntil = notificationSettings.notificationsInhibitedUntil
                var inhibitedUntilTime = inhibitedUntil.getTime();
                var inhibitedUntilValid = !isNaN(inhibitedUntilTime);
                var dateNow = Date.now();

                if (inhibitedUntilValid && inhibitedUntilTime - dateNow > 0
                        && inhibitedUntilTime - dateNow < 100 * 24 * 60 * 60 * 1000 ) {
                        lines.push(i18n("Do not disturb until %1; middle-click to exit now",
                                     KCoreAddons.Format.formatRelativeDateTime(inhibitedUntil, Locale.ShortFormat)));
                } else {
                    lines.push(i18n("Do not disturb mode active; middle-click to exit"));
                }
            } else {
                if (lines.length === 0) {
                    lines.push(i18n("No unread notifications"));
                }
                lines.push(i18n("Middle-click to enter do not disturb mode"));
            }
        }

        return lines.join("\n");
    }

    Plasmoid.icon: {
        let iconName;
        if (root.inhibitedOrBroken) {
            iconName = "notifications-disabled";
        } else if (root.unreadCount > 0) {
            iconName = "notification-active";
        } else {
            iconName = "notification-inactive"
        }

        if (inPanel) {
            return symbolicizeIconName(iconName);
        }

        return iconName;
    }

    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 1 : Kirigami.Units.gridUnit * 10

    onExpandedChanged: expanded => {
        if (!expanded) {
            historyModel.lastRead = undefined;
            historyModel.collapseAllGroups();
        }
    }

    compactRepresentation: Kernora.CompactRepresentation {
        activeCount: Globals.popupNotificationsModel.activeNotificationsCount
        unreadCount: root.unreadCount

        jobsCount: historyModel.activeJobsCount
        jobsPercentage: historyModel.jobsPercentage

        inhibited: root.inhibitedOrBroken
    }

    fullRepresentation: Kernora.FullRepresentation {
    }

    NotificationManager.Settings {
        id: notificationSettings
    }

    NotificationManager.Notifications {
        id: historyModel
        showExpired: true
        showDismissed: true
        showJobs: notificationSettings.jobsInNotifications
        sortMode: NotificationManager.Notifications.SortByDate
        groupMode: NotificationManager.Notifications.GroupApplicationsFlat
        groupLimit: 2
        expandUnread: true
        blacklistedDesktopEntries: notificationSettings.historyBlacklistedApplications
        blacklistedNotifyRcNames: notificationSettings.historyBlacklistedServices
        urgencies: {
            var urgencies = NotificationManager.Notifications.CriticalUrgency
                          | NotificationManager.Notifications.NormalUrgency;
            if (notificationSettings.lowPriorityHistory) {
                urgencies |= NotificationManager.Notifications.LowUrgency;
            }
            return urgencies;
        }

        onCountChanged: {
            if (count === 0) {
                closePlasmoid();
            }
        }
    }

    Notifications.JobAggregator {
        id: jobAggregator
        sourceModel: NotificationManager.Notifications {
            id: jobAggregatorModel
            showExpired: historyModel.showExpired
            showDismissed: historyModel.showDismissed
            showJobs: historyModel.showJobs
            showNotifications: false
            blacklistedDesktopEntries: historyModel.blacklistedDesktopEntries
            blacklistedNotifyRcNames: historyModel.blacklistedNotifyRcNames
            urgencies: historyModel.urgencies
        }
    }

    function closePlasmoid() {
        if (root.hideOnWindowDeactivate && !(root.width > root.switchWidth && root.height > root.switchHeight)) {
            root.expanded = false;
        }
    }

    function action_configure() {
        KCMUtils.KCMLauncher.openSystemSettings("kcm_notifications");
    }

    function symbolicizeIconName(iconName) {
        const symbolicSuffix = "-symbolic";
        if (iconName.endsWith(symbolicSuffix)) {
            return iconName;
        }

        return iconName + symbolicSuffix;
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            id: clearHistory
            text: i18n("Clear All Notifications")
            icon.name: "edit-clear-history"
            visible: historyModel.expiredNotificationsCount > 0
            onTriggered: {
                historyModel.clear(NotificationManager.Notifications.ClearExpired);
                historyModel.countChanged.connect(closeWhenCleared)
            }
            function closeWhenCleared() {
                if (historyModel.count === 0) {
                    closePlasmoid();
                }
                historyModel.countChanged.disconnect(closeWhenCleared)
            }
        }
    ]

    PlasmaCore.Action {
        id: configureAction
        text: i18n("&Configure Event Notifications and Actions…")
        icon.name: "configure"
        visible: KConfig.KAuthorized.authorizeControlModule("kcm_notifications");
        onTriggered: KCMUtils.KCMLauncher.openSystemSettings("kcm_notifications");
    }

    Component.onCompleted: {
        Globals.adopt(root);

        Plasmoid.setInternalAction("configure", configureAction)
    }
    Component.onDestruction: {
        Globals.forget(root);
    }
}
