/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import org.kde.coreaddons as KCoreAddons
import org.kde.config as KConfig
import org.kde.kcmutils as KCMUtils

import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.notifications as Notifications

import org.kernora.m3
import org.kernora.ui

import "global"
import "delegates" as Delegates
import "components" as Components

PlasmaExtras.Representation {
    readonly property int dndMorningHour: 6
    readonly property int dndEveningHour: 20
    readonly property var appletInterface: root

    Layout.minimumWidth: 360
    Layout.minimumHeight: 320
    Layout.preferredWidth: 408
    Layout.preferredHeight: 560
    Layout.maximumWidth: Kirigami.Units.gridUnit * 80
    Layout.maximumHeight: Kirigami.Units.gridUnit * 40

    Layout.fillHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    collapseMarginsHint: true

    Keys.onDownPressed: list.forceActiveFocus(Qt.TabFocusReason);

    Connections {
        target: root
        function onExpandedChanged() {
            if (root.expanded) {
                list.positionViewAtBeginning();
                list.currentIndex = -1;
            }
        }
    }

    header: Item {
        implicitHeight: 64

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 24
                rightMargin: 12
                topMargin: 8
            }
            spacing: 4

            MText {
                Layout.fillWidth: true
                role: "headlineSmall"
                text: Plasmoid.title
            }

            MIconButton {
                id: dndButton
                enabled: NotificationManager.Server.valid
                variant: Globals.inhibited ? "tonal" : "standard"
                icon: "notifications-disabled"
                text: i18n("Do not disturb")
                Accessible.role: Accessible.CheckBox
                Accessible.checkable: true
                Accessible.checked: Globals.inhibited
                KeyNavigation.down: list
                onClicked: {
                    if (Globals.inhibited) {
                        Globals.revokeInhibitions();
                    } else {
                        dndMenu.date = new Date();
                        dndMenu.open(0, dndButton.height);
                    }
                }

                PlasmaExtras.ModelContextMenu {
                    id: dndMenu
                    property date date
                    visualParent: dndButton

                    onClicked: {
                        notificationSettings.notificationsInhibitedUntil = model.date;
                        notificationSettings.save();
                    }

                    model: {
                        var model = [];

                        var d = dndMenu.date;
                        d.setHours(d.getHours() + 1);
                        d.setSeconds(0);
                        model.push({date: d, text: i18n("For 1 hour")});

                        d = dndMenu.date;
                        d.setHours(d.getHours() + 4);
                        d.setSeconds(0);
                        model.push({date: d, text: i18n("For 4 hours")});

                        if (dndMenu.date.getHours() < dndEveningHour) {
                            d = dndMenu.date;
                            d.setHours(dndEveningHour);
                            d.setMinutes(0);
                            d.setSeconds(0);
                            model.push({date: d, text: i18n("Until this evening")});
                        }

                        if (dndMenu.date.getHours() > dndMorningHour) {
                            d = dndMenu.date;
                            d.setDate(d.getDate() + 1);
                            d.setHours(dndMorningHour);
                            d.setMinutes(0);
                            d.setSeconds(0);
                            model.push({date: d, text: i18n("Until tomorrow morning")});
                        }

                        if (dndMenu.date.getDay() >= 5) {
                            d = dndMenu.date;
                            d.setHours(dndMorningHour);
                            d.setDate(d.getDate() + (7 - d.getDay() + 1));
                            d.setMinutes(0);
                            d.setSeconds(0);
                            model.push({date: d, text: i18n("Until Monday")});
                        }

                        d = dndMenu.date;
                        d.setFullYear(d.getFullYear() + 1);
                        model.push({date: d, text: i18n("Until manually disabled")});

                        return model;
                    }
                }
            }

            MIconButton {
                icon: "configure"
                text: i18nd("plasma_applet_org.kde.plasma.notifications", "Configure")
                visible: KConfig.KAuthorized.authorizeControlModule("kcm_notifications")
                onClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_notifications")
            }
        }
    }

    footer: Item {
        implicitHeight: footerRow.visible ? footerRow.implicitHeight + 24 : 12

        RowLayout {
            id: footerRow
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 24
                rightMargin: 16
            }
            spacing: 12
            visible: dndStatus.text !== "" || root.clearHistoryAction.visible

            MText {
                id: dndStatus
                Layout.fillWidth: true
                role: "bodySmall"
                color: M3.surfaceVariantContent
                wrapMode: Text.WordWrap
                maximumLineCount: 3
            text: {
                if (!Globals.inhibited) {
                    return "";
                }

                var inhibitedUntil = notificationSettings.notificationsInhibitedUntil;
                var inhibitedUntilTime = inhibitedUntil.getTime();
                var inhibitedByApp = notificationSettings.notificationsInhibitedByApplication;
                var inhibitedByMirroredScreens = notificationSettings.inhibitNotificationsWhenScreensMirrored
                                                    && notificationSettings.screensMirrored;
                var dateNow = Date.now();

                var sections = [];

                if (!isNaN(inhibitedUntilTime) && inhibitedUntilTime - dateNow > 0 &&
                    inhibitedUntilTime - dateNow < 100 * 24 * 60 * 60 * 1000 ) {
                    const endTime = KCoreAddons.Format.formatRelativeDateTime(inhibitedUntil, Locale.ShortFormat);
                    const lowercaseEndTime = endTime[0] + endTime.slice(1);
                    sections.push(i18nc("Do not disturb until date", "Automatically ends: %1", lowercaseEndTime));
                }

                if (inhibitedByApp) {
                    var inhibitionAppNames = notificationSettings.notificationInhibitionApplications;
                    var inhibitionAppReasons = notificationSettings.notificationInhibitionReasons;

                    for (var i = 0, length = inhibitionAppNames.length; i < length; ++i) {
                        var name = inhibitionAppNames[i];
                        var reason = inhibitionAppReasons[i];

                        if (reason) {
                            sections.push(i18nc("Do not disturb until app has finished (reason)", "While %1 is active (%2)", name, reason));
                        } else {
                            sections.push(i18nc("Do not disturb until app has finished", "While %1 is active", name));
                        }
                    }
                }

                if (inhibitedByMirroredScreens) {
                    sections.push(i18nc("Do not disturb because external mirrored screens connected", "Screens are mirrored"))
                }

                return sections.join(" · ");
            }
                visible: text !== ""
            }

            Item {
                Layout.fillWidth: dndStatus.text === ""
            }

            MButton {
                id: clearAllButton
                variant: "tonal"
                icon: "edit-clear-history"
                text: i18nd("kernora-notifications", "Clear all")
                visible: root.clearHistoryAction.visible
                onClicked: root.clearHistoryAction.trigger()
            }
        }
    }

    PlasmaComponents3.ScrollView {
        id: scrollView
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 12
        }
        background: null
        focus: true

        contentItem: ListView {
            id: list
            width: scrollView.availableWidth
            focus: true
            model: root.expanded ? historyModel : null
            currentIndex: -1

            topMargin: 4
            bottomMargin: 4
            spacing: M3.slabGap

            KeyNavigation.up: dndButton

            Keys.onDeletePressed: {
                var idx = historyModel.index(currentIndex, 0);
                if (historyModel.data(idx, NotificationManager.Notifications.ClosableRole)) {
                    historyModel.close(idx);
                }
            }
            Keys.onEnterPressed: event => { Keys.returnPressed(event) }
            Keys.onReturnPressed: {
                var idx = historyModel.index(currentIndex, 0);
                if (historyModel.data(idx, NotificationManager.Notifications.HasDefaultActionRole)) {
                    historyModel.invokeDefaultAction(idx);
                    return;
                }

                var urls = historyModel.data(idx, NotificationManager.Notifications.UrlsRole);
                if (urls && urls.length === 1) {
                    Qt.openUrlExternally(urls[0]);
                    return;
                }

            }
            Keys.onLeftPressed: setGroupExpanded(currentIndex, LayoutMirroring.enabled)
            Keys.onRightPressed: setGroupExpanded(currentIndex, !LayoutMirroring.enabled)

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Home:
                    currentIndex = 0;
                    break;
                case Qt.Key_End:
                    currentIndex = count - 1;
                    break;
                }
            }

            function setGroupExpanded(row, expanded) {
                var rowIdx = historyModel.index(row, 0);
                var persistentRowIdx = historyModel.makePersistentModelIndex(rowIdx);
                var persistentGroupIdx = historyModel.makePersistentModelIndex(historyModel.groupIndex(rowIdx));

                historyModel.setData(rowIdx, expanded, NotificationManager.Notifications.IsGroupExpandedRole);

                if (!persistentRowIdx || !persistentRowIdx.valid) {
                    if (persistentGroupIdx && persistentGroupIdx.valid) {
                        list.positionViewAtIndex(persistentGroupIdx.row, ListView.Contain);
                        if (list.currentIndex > -1) {
                            list.currentIndex = persistentGroupIdx.row;
                        }
                    }
                }
            }

            highlightMoveDuration: 0
            highlightResizeDuration: 0
            highlight: Rectangle {
                z: 2
                color: "transparent"
                radius: 8
                border.width: 2
                border.color: M3.primary
                visible: list.activeFocus
            }

            section {
                property: "desktopEntry"
                criteria: ViewSection.FullString
            }

            delegate: DraggableDelegate {
                id: delegate
                width: ListView.view.width
                opacity: 0

                required property int index
                required property var model

                property real oldY: -1
                property int oldListCount: -1
                onYChanged: {
                    if (oldY < 0 || oldListCount === list.count) {
                        oldY = y;
                        return;
                    }
                    traslAnim.from = oldY - y;
                    traslAnim.restart()
                    oldY = y;
                    oldListCount = list.count;
                }
                transform: Translate {
                    id: transl
                }
                NumberAnimation {
                    id: traslAnim
                    target: transl
                    properties: "y"
                    to: 0
                    duration: Kirigami.Units.longDuration
                }

                ListView.onAdd: appearAnim.restart();
                Component.onCompleted: {
                    Qt.callLater(() => {
                        if (!appearAnim.running) {
                            opacity = 1;
                        }
                    });
                    oldListCount = list.count;
                }

                SequentialAnimation {
                    id: appearAnim
                    PropertyAction { target: delegate; property: "opacity"; value: 0 }
                    PauseAnimation { duration: Kirigami.Units.longDuration}
                    NumberAnimation {
                        target: delegate
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Kirigami.Units.longDuration
                    }
                }

                draggable: !model.isGroup && model.type != NotificationManager.Notifications.JobType

                readonly property real outerRadius: M3.cornerCard
                readonly property real innerRadius: M3.cornerCardInner
                topPadding: 16
                bottomPadding: model.isGroup ? 8 : 16
                leftPadding: 16
                rightPadding: 12
                background: Rectangle {
                    color: M3.surfaceContainerHigh
                    topLeftRadius: delegate.index === 0 ? delegate.outerRadius : delegate.innerRadius
                    topRightRadius: topLeftRadius
                    bottomLeftRadius: delegate.index === list.count - 1 ? delegate.outerRadius : delegate.innerRadius
                    bottomRightRadius: bottomLeftRadius
                }

                onDismissRequested: historyModel.close(historyModel.index(index, 0));

                contentItem: Loader {
                    id: delegateLoader

                    sourceComponent: {
                        if (model.isGroup) {
                            return groupDelegate;
                        } else if (model.isInGroup) {
                            return notificationGroupedDelegate;
                        } else {
                            return notificationDelegate;
                        }
                    }

                    readonly property Components.ModelInterface modelInterface: Components.ModelInterface {
                        notificationType: model.type

                        inGroup: model.isInGroup
                        inHistory: true

                        applicationName: model.applicationName
                        applicationIconSource: model.applicationIconName
                        originName: model.originName || ""

                        time: model.updated || model.created

                        configurable: !inGroup && model.configurable

                        dismissable: model.type === NotificationManager.Notifications.JobType
                            && model.jobState !== NotificationManager.Notifications.JobStateStopped
                            && model.dismissed
                            && notificationSettings.permanentJobPopups
                        dismissed: model.dismissed || false
                        closable: model.closable

                        summary: model.summary
                        body: model.body || ""
                        icon: model.image || model.iconName
                        iconName: model.iconName || ""

                        urls: model.urls || []

                        jobState: model.jobState || 0
                        percentage: model.percentage || 0
                        jobError: model.jobError || 0
                        suspendable: !!model.suspendable
                        killable: !!model.killable
                        jobDetails: model.jobDetails || null

                        configureActionLabel: model.configureActionLabel || ""

                        actionNames: {
                            let names = [... (model.actionNames || [])];
                            if (delegateLoader.addDefaultAction) {
                                names.unshift("default");
                            }
                            return names;
                        }
                        actionLabels: {
                            let labels = [... (model.actionLabels || [])];
                            if (delegateLoader.addDefaultAction) {
                                labels.unshift(model.defaultActionLabel);
                            }
                            return labels;
                        }

                        onCloseClicked: delegate.close()

                        onDismissClicked: {
                            model.dismissed = false;
                            root.closePlasmoid();
                        }
                        onConfigureClicked: historyModel.configure(historyModel.index(index, 0))

                        onActionInvoked: {
                            if (actionName === "default") {
                                historyModel.invokeDefaultAction(historyModel.index(index, 0));
                            } else {
                                historyModel.invokeAction(historyModel.index(index, 0), actionName);
                            }

                            delegateLoader.expire();
                        }
                        onOpenUrl: {
                            Qt.openUrlExternally(url);
                            delegateLoader.expire();
                        }
                        onFileActionInvoked: {
                            if (action.objectName === "movetotrash" || action.objectName === "deletefile") {
                                delegate.close();
                            } else {
                                delegateLoader.expire();
                            }
                        }

                        onSuspendJobClicked: historyModel.suspendJob(historyModel.index(index, 0))
                        onResumeJobClicked: historyModel.resumeJob(historyModel.index(index, 0))
                        onKillJobClicked: historyModel.killJob(historyModel.index(index, 0))
                    }

                    readonly property bool addDefaultAction: (model.hasDefaultAction
                                                            && model.defaultActionLabel
                                                            && (model.actionLabels || []).indexOf(model.defaultActionLabel) === -1) ? true : false
                    function expire() {
                        if (model.resident) {
                            model.expired = true;
                        } else {
                            historyModel.expire(historyModel.index(index, 0));
                        }
                    }

                    Component {
                        id: groupDelegate
                        Components.NotificationHeader {
                            showIcon: true
                            modelInterface {
                                applicationName: model.applicationName
                                applicationIconSource: model.applicationIconName
                                originName: model.originName || ""

                                configurable: model.configurable
                                closable: model.closable

                                onCloseClicked: historyModel.close(historyModel.index(index, 0));
                                onConfigureClicked: historyModel.configure(historyModel.index(index, 0))
                            }
                            closeButtonTooltip: i18n("Close Group")
                        }
                    }
                    Component {
                        id: notificationDelegate
                        Delegates.DelegateHistory {
                            Layout.fillWidth: true
                            modelInterface: delegateLoader.modelInterface
                        }
                    }
                    Component {
                        id: notificationGroupedDelegate
                        ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Delegates.DelegateHistoryGrouped {
                                Layout.fillWidth: true
                                modelInterface: delegateLoader.modelInterface
                            }

                            MButton {
                                Layout.leftMargin: 16
                                variant: "text"
                                icon: model.isGroupExpanded ? "arrow-up" : "arrow-down"
                                text: model.isGroupExpanded ? i18n("Show Fewer")
                                                            : i18nc("Expand to show n more notifications",
                                                                    "Show %1 More", (model.groupChildrenCount - model.expandedGroupChildrenCount))
                                visible: (model.groupChildrenCount > model.expandedGroupChildrenCount || model.isGroupExpanded)
                                    && delegate.ListView.nextSection !== delegate.ListView.section
                                onClicked: list.setGroupExpanded(model.index, !model.isGroupExpanded)
                            }
                        }
                    }
                }
            }

            Loader {
                anchors.centerIn: parent
                width: parent.width - 48

                active: list.count === 0
                visible: active
                asynchronous: true

                sourceComponent: NotificationManager.Server.valid ? noUnreadMessage : notAvailableMessage
            }

            Component {
                id: noUnreadMessage

                EmptyState {
                    anchors.centerIn: parent
                    width: parent.width

                    icon: "notifications"
                    title: i18nd("kernora-notifications", "No notifications")
                }
            }

            Component {
                id: notAvailableMessage

                EmptyState {
                    readonly property NotificationManager.ServerInfo currentOwner: NotificationManager.Server.currentOwner

                    anchors.centerIn: parent
                    width: parent.width

                    icon: "notifications-disabled"
                    title: i18n("Notification service not available")
                    text: currentOwner && currentOwner.vendor && currentOwner.name
                                ? i18nc("Vendor and product name", "Notifications are currently provided by '%1 %2'", currentOwner.vendor, currentOwner.name)
                                : ""
                }
            }
        }
    }
}
