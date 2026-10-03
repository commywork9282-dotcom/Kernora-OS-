/*
    SPDX-FileCopyrightText: 2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

pragma Singleton
import QtQuick 2.8
import QtQuick.Window 2.12
import QtQuick.Layouts 1.1
import QtQml 2.15

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.kquickcontrolsaddons 2.0
import org.kde.kirigami 2.11 as Kirigami

import org.kde.notificationmanager as NotificationManager
import org.kde.taskmanager 0.1 as TaskManager

import org.kde.plasma.private.notifications 2.0 as Notifications

import ".."

QtObject {
    id: globals

    signal timeChanged

    property bool inhibited: false

    onInhibitedChanged: {
        if (!inhibited) {
            popupNotificationsModel.showInhibitionSummary();
        }

        var pa = pulseAudio.item;
        if (!pa) {
            return;
        }

        var stream = pa.notificationStream;
        if (!stream) {
            return;
        }

        if (inhibited) {
            if (!stream.muted) {
                notificationSettings.notificationSoundsInhibited = true;
                stream.mute();
            }
        } else {
            if (notificationSettings.notificationSoundsInhibited) {
                stream.unmute();
            }
            notificationSettings.notificationSoundsInhibited = false;
        }
        notificationSettings.save();
    }

    property var plasmoidItem: null
    property var plasmoid: null

    property var plasmoidItems: []

    property int popupLocation: {
        if (Kirigami.Settings.isMobile) {
            return Qt.AlignTop | Qt.AlignHCenter;
        }

        switch (notificationSettings.popupPosition) {
        case NotificationManager.Settings.CloseToWidget:
            if (!plasmoid) {
                return Qt.AlignBottom | Qt.AlignRight;
            }

            var alignment = 0;
            if (plasmoid.location === PlasmaCore.Types.LeftEdge) {
                alignment |= Qt.AlignLeft;
            } else if (plasmoid.location === PlasmaCore.Types.RightEdge) {
                alignment |= Qt.AlignRight;
            }

            if (plasmoid.location === PlasmaCore.Types.TopEdge) {
                alignment |= Qt.AlignTop;
            } else if (plasmoid.location === PlasmaCore.Types.BottomEdge) {
                alignment |= Qt.AlignBottom;
            }
            return alignment;

        case NotificationManager.Settings.TopLeft:
            return Qt.AlignTop | Qt.AlignLeft;
        case NotificationManager.Settings.TopCenter:
            return Qt.AlignTop | Qt.AlignHCenter;
        case NotificationManager.Settings.TopRight:
            return Qt.AlignTop | Qt.AlignRight;
        case NotificationManager.Settings.BottomLeft:
            return Qt.AlignBottom | Qt.AlignLeft;
        case NotificationManager.Settings.BottomCenter:
            return Qt.AlignBottom | Qt.AlignHCenter;
        case NotificationManager.Settings.BottomRight:
            return Qt.AlignBottom | Qt.AlignRight;
        }
    }

    readonly property rect screenRect: {
        if (!plasmoid) {
            return Qt.rect(0, 0, -1, -1);
        }

        const containment = plasmoid.containment;
        let rect = Qt.rect(containment.screenGeometry.x + containment.availableScreenRect.x,
                           containment.screenGeometry.y + containment.availableScreenRect.y,
                           containment.availableScreenRect.width,
                           containment.availableScreenRect.height);

        if (visualParent && notificationSettings.popupPosition === NotificationManager.Settings.CloseToWidget
            && plasmoid.formFactor === PlasmaCore.Types.Horizontal) {
            const visualParentWindow = visualParent.Window.window;
            if (visualParentWindow) {
                const left = Math.max(rect.left, visualParentWindow.x);
                const right = Math.min(rect.right, visualParentWindow.x + visualParentWindow.width);
                rect = Qt.rect(left, rect.y, right - left, rect.height);
            }
        }

        return rect;
    }
    onScreenRectChanged: repositionTimer.start()

    readonly property Item visualParent: {
        if (!plasmoidItem) {
            return null;
        }
        return (plasmoid && plasmoid.systemTrayRepresentation)
            || plasmoidItem.compactRepresentationItem
            || plasmoidItem.fullRepresentationItem;
    }
    onVisualParentChanged: positionPopups()

    property QtObject obstructingDialog: null
    readonly property QtObject focusDialog: plasmoid ? plasmoid.focussedPlasmaDialog : null
    onFocusDialogChanged: {
        if (focusDialog && !(focusDialog instanceof NotificationPopup)) {
            obstructingDialog = focusDialog;
        }
        positionPopups()
    }
    onObstructingDialogChanged: repositionTimer.start()

    property int popupWidth: 360
    property int popupEdgeDistance: 12
    property int popupSpacing: 8

    readonly property real popupMaximumScreenFill: 0.8

    onPopupLocationChanged: Qt.callLater(positionPopups)

    Component.onCompleted: checkInhibition()

    function adopt(plasmoid) {
        globals.plasmoidItems.push(plasmoid);
        ratePlasmoids();
    }

    function forget(plasmoid) {
        globals.plasmoidItems = globals.plasmoidItems.filter(p => p !== plasmoid);
        ratePlasmoids();
    }

    function ratePlasmoids() {
        var plasmoidScore = function(plasmoidItem) {
            if (!plasmoidItem || plasmoidItem.plasmoid) {
                return 0;
            }

            const plasmoid = plasmoidItem.plasmoid;
            var score = 0;

            switch (plasmoid.location) {
            case PlasmaCore.Types.LeftEdge:
                score += 1;
                break;
            case PlasmaCore.Types.RightEdge:
                score += 2;
                break;
            case PlasmaCore.Types.TopEdge:
                score += 3;
                break;
            case PlasmaCore.Types.BottomEdge:
                score += 4;
            }

            if (!plasmoidItem.expanded) {
                ++score;
            }

            if (plasmoid && plasmoid.containment.screen === 0) {
                ++score;
            }

            return score;
        }

        var newPlasmoidItems = plasmoidItems;
        newPlasmoidItems.sort(function (a, b) {
            var scoreA = plasmoidScore(a);
            var scoreB = plasmoidScore(b);
            if (scoreA < scoreB) {
                return 1;
            } else if (scoreA > scoreB) {
                return -1;
            } else {
                return 0;
            }
        });
        globals.plasmoidItems = newPlasmoidItems;
        globals.plasmoidItem = newPlasmoidItems[0];
        globals.plasmoid = globals.plasmoidItem.plasmoid;
    }

    function checkInhibition() {
        globals.inhibited = Qt.binding(function() {
            var inhibited = false;

            if (!NotificationManager.Server.valid) {
                return false;
            }

            var inhibitedUntil = notificationSettings.notificationsInhibitedUntil;
            if (!isNaN(inhibitedUntil.getTime())) {
                inhibited |= (Date.now() < inhibitedUntil.getTime());
            }

            if (notificationSettings.notificationsInhibitedByApplication) {
                inhibited |= true;
            }

            if (notificationSettings.inhibitNotificationsWhenScreensMirrored) {
                inhibited |= notificationSettings.screensMirrored;
            }

            return inhibited;
        });
    }

    function revokeInhibitions() {
        notificationSettings.notificationsInhibitedUntil = undefined;
        notificationSettings.revokeApplicationInhibitions();
        notificationSettings.screensMirrored = false;

        notificationSettings.save();
    }

    function rectIntersect(rect1 , rect2 ) {
        return rect1.x < rect2.x + rect2.width
                && rect2.x < rect1.x + rect1.width
                && rect1.y < rect2.y + rect2.height
                && rect2.y < rect1.y + rect1.height;
    }

    function positionPopups() {
        if (!plasmoid) {
            return;
        }

        const screenRect = globals.screenRect;
        if (screenRect.width <= 0 || screenRect.height <= 0) {
            return;
        }
        if (!globals.visualParent) {
            return;
        }

        let effectivePopupLocation = popupLocation;

        const visualParent = globals.visualParent;
        const visualParentWindow = visualParent.Window.window;

        if (visualParentWindow) {
            if (!(effectivePopupLocation & (Qt.AlignLeft | Qt.AlignHCenter | Qt.AlignRight))) {
                const iconHCenter = visualParent.mapToItem(null , 0, 0).x + visualParent.width / 2;

                if (iconHCenter < visualParentWindow.width / 2) {
                    effectivePopupLocation |= Qt.AlignLeft;
                } else {
                    effectivePopupLocation |= Qt.AlignRight;
                }
            }
        }

        if (!(effectivePopupLocation & (Qt.AlignTop | Qt.AlignBottom))) {
            const screenVCenter = screenRect.y + screenRect.height / 2;
            const iconVCenter = visualParent.mapToGlobal(0, visualParent.height / 2).y;

            if (iconVCenter < screenVCenter) {
                effectivePopupLocation |= Qt.AlignTop;
            } else {
                effectivePopupLocation |= Qt.AlignBottom;
            }
        }

        let y = screenRect.y;
        if (effectivePopupLocation & Qt.AlignBottom) {
            y += screenRect.height - popupEdgeDistance;
        } else {
            y += popupEdgeDistance;
        }

        for (var i = 0; i < popupInstantiator.count; ++i) {
            let popup = popupInstantiator.objectAt(i);
            if (!popup) {
                continue;
            }


            const leftMostX = screenRect.x + popupEdgeDistance;
            const rightMostX = screenRect.x + screenRect.width - popupEdgeDistance - popup.width;

            if (screenRect.width < popup.width || effectivePopupLocation & Qt.AlignHCenter) {
                popup.x = screenRect.x + (screenRect.width - popup.width) / 2
            } else if (effectivePopupLocation & Qt.AlignLeft) {
                popup.x = leftMostX;
            } else if (effectivePopupLocation & Qt.AlignRight) {
                popup.x = rightMostX;
            }

            if (effectivePopupLocation & Qt.AlignTop) {
                if (obstructingDialog && obstructingDialog.visible
                        && rectIntersect(obstructingDialog, Qt.rect(popup.x, y, popup.width, popup.height))) {
                    y = obstructingDialog.y + obstructingDialog.height + popupEdgeDistance;
                }
                popup.y = y;
                y += popup.height + (popup.height > 0 ? popupSpacing : 0);
            } else {
                y -= popup.height;
                if (obstructingDialog && obstructingDialog.visible
                        && rectIntersect(obstructingDialog, Qt.rect(popup.x, y, popup.width, popup.height))) {
                    y = obstructingDialog.y - popup.height - popupEdgeDistance;
                }
                popup.y = y;
                if (popup.height > 0) {
                    y -= popupSpacing;
                }
            }

            var visible = true;
            if (i > 0) {
                if (effectivePopupLocation & Qt.AlignTop) {
                    visible = (popup.y + popup.height < screenRect.y + (screenRect.height * popupMaximumScreenFill));
                } else {
                    visible = (popup.y > screenRect.y + (screenRect.height * (1 - popupMaximumScreenFill)));
                }
            }

            popup.visible = visible;
        }
    }

    property QtObject popupNotificationsModel: NotificationManager.Notifications {
        limit: plasmoid ? (Math.ceil(globals.screenRect.height / (Kirigami.Units.gridUnit * 4))) : 0
        showExpired: false
        showDismissed: false
        showAddedDuringInhibition: false
        blacklistedDesktopEntries: notificationSettings.popupBlacklistedApplications
        blacklistedNotifyRcNames: notificationSettings.popupBlacklistedServices
        whitelistedDesktopEntries: globals.inhibited ? notificationSettings.doNotDisturbPopupWhitelistedApplications : []
        whitelistedNotifyRcNames: globals.inhibited ? notificationSettings.doNotDisturbPopupWhitelistedServices : []
        showJobs: notificationSettings.jobsInNotifications
        sortMode: NotificationManager.Notifications.SortByTypeAndUrgency
        sortOrder: Qt.AscendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        window: visualParent ? visualParent.Window.window : null
        urgencies: {
            var urgencies = 0;

            if (!globals.inhibited || notificationSettings.criticalPopupsInDoNotDisturbMode) {
                urgencies |= NotificationManager.Notifications.CriticalUrgency;
            }

            if (!globals.inhibited) {
                urgencies |= NotificationManager.Notifications.NormalUrgency;
            }

            if (!globals.inhibited && notificationSettings.lowPriorityPopups) {
                urgencies |=NotificationManager.Notifications.LowUrgency;
            }

            return urgencies;
        }
    }

    property QtObject notificationSettings: NotificationManager.Settings {
        onNotificationsInhibitedUntilChanged: globals.checkInhibition()
    }

    property QtObject tasksModel: TaskManager.TasksModel {
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
    }

    property QtObject timeSource: P5Support.DataSource {
        engine: "time"
        connectedSources: ["Local"]
        interval: 60000
        intervalAlignment: P5Support.Types.AlignToMinute
        onDataChanged: {
            checkInhibition();
            globals.timeChanged();
        }
    }

    property Instantiator popupInstantiator: Instantiator {
        model: popupNotificationsModel
        delegate: NotificationPopup {
            id: popup
            readonly property var notificationId: model.notificationId

            popupWidth: globals.popupWidth

            isCritical: model.urgency === NotificationManager.Notifications.CriticalUrgency || (model.urgency === NotificationManager.Notifications.NormalUrgency && notificationSettings.keepNormalAlwaysOnTop)

            modelTimeout: model.timeout
            defaultTimeout: notificationSettings.popupTimeout + (model.urls && model.urls.length > 0 ? 5000 : 0)
            dismissTimeout: !notificationSettings.permanentJobPopups
                            && model.type === NotificationManager.Notifications.JobType
                            && model.jobState !== NotificationManager.Notifications.JobStateStopped
                            ? defaultTimeout : 0

            modelInterface {
                notificationType: model.type

                applicationName: model.applicationName
                applicationIconSource: model.applicationIconName
                originName: model.originName || ""

                time: model.updated || model.created

                configurable: model.configurable
                dismissable: model.type === NotificationManager.Notifications.JobType
                    && model.jobState !== NotificationManager.Notifications.JobStateStopped
                    && notificationSettings.permanentJobPopups
                closable: model.closable

                summary: model.summary
                body: model.body || ""
                accessibleDescription: model.accessibleDescription
                icon: model.image || model.iconName
                iconName: model.iconName || ""
                hasDefaultAction: model.hasDefaultAction || false

                urls: model.urls || []
                urgency: model.urgency || NotificationManager.Notifications.NormalUrgency

                jobState: model.jobState || 0
                percentage: model.percentage || 0
                jobError: model.jobError || 0
                suspendable: !!model.suspendable
                killable: !!model.killable
                jobDetails: model.jobDetails || null

                configureActionLabel: model.configureActionLabel || ""
                actionNames: model.actionNames
                actionLabels: model.actionLabels

                hasReplyAction: model.hasReplyAction || false
                replyActionLabel: model.replyActionLabel || ""
                replyPlaceholderText: model.replyPlaceholderText || ""
                replySubmitButtonText: model.replySubmitButtonText || ""
                replySubmitButtonIconName: model.replySubmitButtonIconName || ""

                onCloseClicked: popupNotificationsModel.close(popupNotificationsModel.index(index, 0))
                onDismissClicked: model.dismissed = true
                onConfigureClicked: popupNotificationsModel.configure(popupNotificationsModel.index(index, 0))
                onDefaultActionInvoked: {
                    if (defaultActionFallbackWindowIdx) {
                        if (!defaultActionFallbackWindowIdx.valid) {
                            console.warn("Failed fallback notification activation as window no longer exists");
                            return;
                        }

                        if (tasksModel.data(defaultActionFallbackWindowIdx, TaskManager.AbstractTasksModel.IsGroupParent)) {
                            let highestStacking = -1;
                            let highestIdx = undefined;

                            for (let i = 0; i < tasksModel.rowCount(defaultActionFallbackWindowIdx); ++i) {
                                const idx = tasksModel.index(i, 0, defaultActionFallbackWindowIdx);

                                const stacking = tasksModel.data(idx, TaskManager.AbstractTasksModel.StackingOrder);

                                if (stacking > highestStacking) {
                                    highestStacking = stacking;
                                    highestIdx = tasksModel.makePersistentModelIndex(defaultActionFallbackWindowIdx.row, i);
                                }
                            }

                            if (highestIdx && highestIdx.valid) {
                                tasksModel.requestActivate(highestIdx);
                                if (!model.resident) {
                                    popupNotificationsModel.close(popupNotificationsModel.index(index, 0))
                                }

                            }
                            return;
                        }

                        tasksModel.requestActivate(defaultActionFallbackWindowIdx);
                        if (!model.resident) {
                            popupNotificationsModel.close(popupNotificationsModel.index(index, 0))
                        }
                        return;
                    }

                    const behavior = model.resident ? NotificationManager.Notifications.None : NotificationManager.Notifications.Close;
                    popupNotificationsModel.invokeDefaultAction(popupNotificationsModel.index(index, 0), behavior)
                }
                onActionInvoked: actionName => {
                    const behavior = model.resident ? NotificationManager.Notifications.None : NotificationManager.Notifications.Close;
                    popupNotificationsModel.invokeAction(popupNotificationsModel.index(index, 0), actionName, behavior)
                }
                onReplied: text => {
                    const behavior = model.resident ? NotificationManager.Notifications.None : NotificationManager.Notifications.Close;
                    popupNotificationsModel.reply(popupNotificationsModel.index(index, 0), text, behavior);
                }
                onOpenUrl: url => {
                    Qt.openUrlExternally(url);
                    if (model.resident) {
                        model.expired = true;
                    } else {
                        popupNotificationsModel.close(popupNotificationsModel.index(index, 0))
                    }
                }
                onFileActionInvoked: action => {
                    if (!model.resident
                        || (action.objectName === "movetotrash" || action.objectName === "deletefile")) {
                        popupNotificationsModel.close(popupNotificationsModel.index(index, 0));
                    } else {
                        model.expired = true;
                    }
                }
                onForceActiveFocusRequested: {
                    plasmoid.forceActivateWindow(popup);
                }

                onSuspendJobClicked: popupNotificationsModel.suspendJob(popupNotificationsModel.index(index, 0))
                onResumeJobClicked: popupNotificationsModel.resumeJob(popupNotificationsModel.index(index, 0))
                onKillJobClicked: popupNotificationsModel.killJob(popupNotificationsModel.index(index, 0))
            }

            onHoverEntered: model.read = true
            onExpired: {
                if (model.resident) {
                    model.expired = true;
                } else {
                    popupNotificationsModel.expire(popupNotificationsModel.index(index, 0))
                }
            }
            onHeightChanged: globals.positionPopups()

            Component.onCompleted: {
                if (globals.inhibited) {
                    model.wasAddedDuringInhibition = false;
                }

                if (model.type === NotificationManager.Notifications.NotificationType && model.desktopEntry) {
                    if (!model.notifyRcName) {
                        notificationSettings.registerKnownApplication(model.desktopEntry);
                        notificationSettings.save();
                    }

                    if (!model.hasDefaultAction) {
                        for (let i = 0; i < tasksModel.rowCount(); ++i) {
                            const idx = tasksModel.index(i, 0);

                            const appId = tasksModel.data(idx, TaskManager.AbstractTasksModel.AppId);
                            if (appId === model.desktopEntry + ".desktop") {
                                defaultActionFallbackWindowIdx = tasksModel.makePersistentModelIndex(i);
                                hasDefaultAction = true;
                                break;
                            }
                        }
                    }
                }

                popupNotificationsModel.stopTimeout(popupNotificationsModel.index(index, 0));
            }
        }
        onObjectAdded: (index, object) => {
            positionPopups();
            object.visible = true;
        }
        onObjectRemoved: (index, object) => {
            var notificationId = object.notificationId
            popupNotificationsModel.startTimeout(notificationId);

            positionPopups();
        }
    }

    property QtObject pulseAudio: Loader {
        source: "PulseAudio.qml"
    }

    property Timer repositionTimer: Timer {
        interval: 250
        onTriggered: positionPopups()
    }

    property Connections visualParentWindowConnections: Connections {
        target: visualParent ? visualParent.Window.window : null
        function onXChanged() {
            repositionTimer.start();
        }
        function onYChanged() {
            repositionTimer.start();
        }
        function onWidthChanged() {
            repositionTimer.start();
        }
        function onHeightChanged() {
            repositionTimer.start();
        }
    }
    property Connections obstructingDialogConnections: Connections {
        target: obstructingDialog
        function onVisibleChanged() {
            repositionTimer.start();
        }
        function onXChanged() {
            repositionTimer.start();
        }
        function onYChanged() {
            repositionTimer.start();
        }
        function onWidthChanged() {
            repositionTimer.start();
        }
        function onHeightChanged() {
            repositionTimer.start();
        }
    }

    property Binding serverInhibitedBinding: Binding {
        target: NotificationManager.Server
        property: "inhibited"
        value: globals.inhibited
        restoreMode: Binding.RestoreBinding
    }

    function toggleDoNotDisturbMode() {
        var oldInhibited = globals.inhibited;
        if (oldInhibited) {
            globals.revokeInhibitions();
        } else {
            var d = new Date();
            d.setFullYear(d.getFullYear() + 1);
            notificationSettings.notificationsInhibitedUntil = d;
            notificationSettings.save();
        }

        checkInhibition();

        if (globals.inhibited !== oldInhibited) {
            shortcuts.showDoNotDisturbOsd(globals.inhibited);
        }
    }

    property Notifications.GlobalShortcuts shortcuts: Notifications.GlobalShortcuts {
        onToggleDoNotDisturbTriggered: globals.toggleDoNotDisturbMode()
    }
}
