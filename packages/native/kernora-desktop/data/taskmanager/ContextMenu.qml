/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2026 Kernora Developers

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.plasmoid

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras

import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.taskmanager as TaskManagerApplet

import "code/layoutmetrics.js" as LayoutMetrics

PlasmaExtras.Menu {
    id: menu

    required property TaskManagerApplet.Backend backend
    required property Mpris.Mpris2Model mpris2Source
    required property /*QModelIndex*/var modelIndex

    readonly property var atm: TaskManager.AbstractTasksModel

    property bool showAllPlaces: false

    placement: {
        if (Plasmoid.location === PlasmaCore.Types.LeftEdge) {
            return PlasmaExtras.Menu.RightPosedTopAlignedPopup;
        } else if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
            return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup;
        } else if (Plasmoid.location === PlasmaCore.Types.RightEdge) {
            return PlasmaExtras.Menu.LeftPosedTopAlignedPopup;
        } else {
            return PlasmaExtras.Menu.TopPosedLeftAlignedPopup;
        }
    }

    minimumWidth: visualParent.width

    onStatusChanged: {
        if (visualParent && get(atm.LauncherUrlWithoutIcon).toString() !== "" && status === PlasmaExtras.Menu.Open) {
            activitiesDesktopsMenu.refresh();

        } else if (status === PlasmaExtras.Menu.Closed) {
            menu.destroy();
        }
    }

    Component.onCompleted: {
        backend.showAllPlaces.connect(showContextMenuWithAllPlaces);
    }

    Component.onDestruction: {
        backend.showAllPlaces.disconnect(showContextMenuWithAllPlaces);
    }

    function showContextMenuWithAllPlaces(): void {
        visualParent.showContextMenu({showAllPlaces: true});
    }

    function get(modelProp: int): var {
        return tasksModel.data(modelIndex, modelProp)
    }

    function show(): void {
        Plasmoid.contextualActionsAboutToShow();

        loadDynamicLaunchActions(get(atm.LauncherUrlWithoutIcon));
        openRelative();
    }

    function newMenuItem(parent: QtObject): PlasmaExtras.MenuItem {
        return Qt.createQmlObject(`
            import org.kde.plasma.extras as PlasmaExtras

            PlasmaExtras.MenuItem {}
        `, parent);
    }

    function newSeparator(parent: QtObject): PlasmaExtras.MenuItem {
        return Qt.createQmlObject(`
            import org.kde.plasma.extras as PlasmaExtras

            PlasmaExtras.MenuItem { separator: true }
            `, parent);
    }

    function loadDynamicLaunchActions(launcherUrl: url): void {
        const sections = [];

        const placesActions = backend.placesActions(launcherUrl, showAllPlaces, menu);

        if (placesActions.length > 0) {
            sections.push({
                title: i18n("Places"),
                group: "places",
                actions: placesActions
            });
        } else {
            sections.push({
                title:   i18n("Recent Files"),
                group:   "recents",
                actions: backend.recentDocumentActions(launcherUrl, menu)
            });
        }

        sections.push({
            title: i18n("Actions"),
            group: "actions",
            actions: backend.jumpListActions(launcherUrl, menu)
        });

        sections.forEach((section) => {
            if (typeof section.actions[0] === "string") {
                section.title = section.actions.shift();
            }
        });

        const textMetrics = Qt.createQmlObject("import QtQuick; TextMetrics {}", menu);
        textMetrics.elide = Qt.ElideRight;
        textMetrics.elideWidth = LayoutMetrics.maximumContextMenuTextWidth();

        sections.forEach(section => {
            if (section["actions"].length > 0 || section["group"] === "actions") {
                if (
                    (section["group"] !== "actions") ||
                    (section["group"] === "actions" && (sections[0]["actions"].length > 0 || sections[1]["actions"].length > 0))
                ) {
                    var sectionHeader = newMenuItem(menu);
                    sectionHeader.text = section["title"];
                    sectionHeader.section = true;
                    menu.addMenuItem(sectionHeader, startNewInstanceItem);
                }
            }

            for (var i = 0; i < section["actions"].length; ++i) {
                var item = newMenuItem(menu);
                item.action = section["actions"][i];

                textMetrics.text = item.action.text;
                item.action.text = textMetrics.elidedText;

                menu.addMenuItem(item, startNewInstanceItem);
            }
        });

        const playerData = mpris2Source.playerForLauncherUrl(launcherUrl, get(atm.AppPid));

        if (playerData && playerData.canControl && !(get(atm.WinIdList) !== undefined && get(atm.WinIdList).length > 1)) {
            const playing = playerData.playbackStatus === Mpris.PlaybackStatus.Playing;
            let menuItem = menu.newMenuItem(menu);
            menuItem.text = i18nc("Play previous track", "Previous Track");
            menuItem.icon = "media-skip-backward";
            menuItem.enabled = Qt.binding(() => {
                return playerData.canGoPrevious;
            });
            menuItem.clicked.connect(() => {
                playerData.Previous();
            });
            menu.addMenuItem(menuItem, startNewInstanceItem);

            menuItem = menu.newMenuItem(menu);
            menuItem.text = Qt.binding(() => {
                return playing && playerData.canPause ? i18nc("Pause playback", "Pause") : i18nc("Start playback", "Play");
            });
            menuItem.icon = Qt.binding(() => {
                return playing && playerData.canPause ? "media-playback-pause" : "media-playback-start";
            });
            menuItem.enabled = Qt.binding(() => {
                return playing ? playerData.canPause : playerData.canPlay;
            });
            menuItem.clicked.connect(() => {
                if (playing) {
                    playerData.Pause();
                } else {
                    playerData.Play();
                }
            });
            menu.addMenuItem(menuItem, startNewInstanceItem);

            menuItem = menu.newMenuItem(menu);
            menuItem.text = i18nc("Play next track", "Next Track");
            menuItem.icon = "media-skip-forward";
            menuItem.enabled = Qt.binding(() => {
                return playerData.canGoNext;
            });
            menuItem.clicked.connect(() => {
                playerData.Next();
            });
            menu.addMenuItem(menuItem, startNewInstanceItem);

            menuItem = menu.newMenuItem(menu);
            menuItem.text = i18nc("Stop playback", "Stop");
            menuItem.icon = "media-playback-stop";
            menuItem.enabled = Qt.binding(() => {
                return playerData.canStop;
            });
            menuItem.clicked.connect(() => {
                playerData.Stop();
            });
            menu.addMenuItem(menuItem, startNewInstanceItem);

            if (!menu.visualParent.hasAudioStream) {
                menu.addMenuItem(newSeparator(menu), startNewInstanceItem);
            }

            if (!closeWindowItem.visible && playerData.canQuit) {
                menuItem = menu.newMenuItem(menu);
                menuItem.text = i18nc("Quit media player app", "Quit");
                menuItem.icon = "application-exit";
                menuItem.visible = Qt.binding(() => {
                    return !closeWindowItem.visible;
                });
                menuItem.clicked.connect(() => {
                    playerData.Quit();
                });
                menu.addMenuItem(menuItem);
            }

            if (get(atm.IsLauncher) && !startNewInstanceItem.visible && playerData.canRaise) {
                menuItem = menu.newMenuItem(menu);
                menuItem.text = i18nc("Open or bring to the front window of media player app", "Restore");
                menuItem.icon = playerData.iconName;
                menuItem.visible = Qt.binding(() => {
                    return !startNewInstanceItem.visible;
                });
                menuItem.clicked.connect(() => {
                    playerData.Raise();
                });
                menu.addMenuItem(menuItem, startNewInstanceItem);
            }
        }

        if (menu.visualParent.hasAudioStream) {
            const muteItem = menu.newMenuItem(menu);
            muteItem.checkable = true;
            muteItem.checked = Qt.binding(() => {
                return menu.visualParent && menu.visualParent.muted;
            });
            muteItem.clicked.connect(() => {
                menu.visualParent.toggleMuted();
            });
            muteItem.text = i18n("Mute");
            muteItem.icon = "audio-volume-muted";
            menu.addMenuItem(muteItem, startNewInstanceItem);

            menu.addMenuItem(newSeparator(menu), startNewInstanceItem);
        }
    }

    PlasmaExtras.MenuItem {
        id: startNewInstanceItem
        visible: get(atm.CanLaunchNewInstance)
        text: i18n("Open New Window")
        icon: "window-new"

        onClicked: tasksModel.requestNewInstance(modelIndex)
    }

    PlasmaExtras.MenuItem {
        id: virtualDesktopsMenuItem

        visible: virtualDesktopInfo.numberOfDesktops > 1
            && (visualParent && !get(atm.IsLauncher)
            && !get(atm.IsStartup)
            && get(atm.IsVirtualDesktopsChangeable))

        enabled: visible

        text: i18n("Move to &Desktop")
        icon: "virtual-desktops"

        readonly property Connections virtualDesktopsMenuConnections: Connections {
            target: virtualDesktopInfo

            function onNumberOfDesktopsChanged(): void {
                Qt.callLater(virtualDesktopsMenu.refresh);
            }
            function onDesktopIdsChanged(): void {
                Qt.callLater(virtualDesktopsMenu.refresh);
            }
            function onDesktopNamesChanged(): void {
                Qt.callLater(virtualDesktopsMenu.refresh);
            }
        }

        readonly property PlasmaExtras.Menu _virtualDesktopsMenu: PlasmaExtras.Menu {
            id: virtualDesktopsMenu

            visualParent: virtualDesktopsMenuItem.action

            function refresh(): void {
                clearMenuItems();

                if (virtualDesktopInfo.numberOfDesktops <= 1 || !virtualDesktopsMenuItem.enabled) {
                    return;
                }

                let menuItem = menu.newMenuItem(virtualDesktopsMenu);
                menuItem.text = i18n("Move &To Current Desktop");
                menuItem.enabled = Qt.binding(() => {
                    return menu.visualParent && menu.get(atm.VirtualDesktops).indexOf(virtualDesktopInfo.currentDesktop) === -1;
                });
                menuItem.clicked.connect(() => {
                    tasksModel.requestVirtualDesktops(menu.modelIndex, [virtualDesktopInfo.currentDesktop]);
                });

                menuItem = menu.newMenuItem(virtualDesktopsMenu);
                menuItem.text = i18n("&All Desktops");
                menuItem.checkable = true;
                menuItem.checked = Qt.binding(() => {
                    return menu.visualParent && menu.get(atm.IsOnAllVirtualDesktops);
                });
                menuItem.clicked.connect(() => {
                    tasksModel.requestVirtualDesktops(menu.modelIndex, []);
                });
                backend.setActionGroup(menuItem.action);

                menu.newSeparator(virtualDesktopsMenu);

                for (let i = 0; i < virtualDesktopInfo.desktopNames.length; ++i) {
                    menuItem = menu.newMenuItem(virtualDesktopsMenu);
                    menuItem.text = virtualDesktopInfo.desktopNames[i];
                    menuItem.checkable = true;
                    menuItem.checked = Qt.binding((i => {
                        return () => menu.visualParent && menu.get(atm.VirtualDesktops).indexOf(virtualDesktopInfo.desktopIds[i]) > -1;
                    })(i));
                    menuItem.clicked.connect((i => {
                        return () => tasksModel.requestVirtualDesktops(menu.modelIndex, [virtualDesktopInfo.desktopIds[i]]);
                    })(i));
                    backend.setActionGroup(menuItem.action);
                }

                menu.newSeparator(virtualDesktopsMenu);

                menuItem = menu.newMenuItem(virtualDesktopsMenu);
                menuItem.text = i18n("&New Desktop");
                menuItem.icon = "list-add";
                menuItem.clicked.connect(() => {
                    tasksModel.requestNewVirtualDesktop(menu.modelIndex);
                });
            }

            Component.onCompleted: refresh()
        }
    }

     PlasmaExtras.MenuItem {
        id: activitiesDesktopsMenuItem

        visible: activityInfo.numberOfRunningActivities > 1
            && (visualParent && !get(atm.IsLauncher)
            && !get(atm.IsStartup))

        enabled: visible

        text: i18n("Show in &Activities")
        icon: "activities"

        readonly property Connections activityInfoConnections: Connections {
            target: activityInfo

            function onNumberOfRunningActivitiesChanged(): void {
                activitiesDesktopsMenu.refresh()
            }
        }

        readonly property PlasmaExtras.Menu _activitiesDesktopsMenu: PlasmaExtras.Menu {
            id: activitiesDesktopsMenu

            visualParent: activitiesDesktopsMenuItem.action

            function refresh(): void {
                clearMenuItems();

                if (activityInfo.numberOfRunningActivities <= 1) {
                    return;
                }

                let menuItem = menu.newMenuItem(activitiesDesktopsMenu);
                menuItem.text = i18n("Add To Current Activity");
                menuItem.enabled = Qt.binding(() => {
                    return menu.visualParent && menu.get(atm.Activities).length > 0 &&
                           menu.get(atm.Activities).indexOf(activityInfo.currentActivity) < 0;
                });
                menuItem.clicked.connect(() => {
                    tasksModel.requestActivities(menu.modelIndex, menu.get(atm.Activities).concat(activityInfo.currentActivity));
                });

                menuItem = menu.newMenuItem(activitiesDesktopsMenu);
                menuItem.text = i18n("All Activities");
                menuItem.checkable = true;
                menuItem.checked = Qt.binding(() => {
                    return menu.visualParent && menu.get(atm.Activities).length === 0;
                });
                menuItem.toggled.connect(checked => {
                    let newActivities = [];
                    if (!checked) {
                        newActivities = [activityInfo.currentActivity];
                    }
                    tasksModel.requestActivities(menu.modelIndex, newActivities);
                });

                menu.newSeparator(activitiesDesktopsMenu);

                const runningActivities = activityInfo.runningActivities();
                for (let i = 0; i < runningActivities.length; ++i) {
                    const activityId = runningActivities[i];

                    menuItem = menu.newMenuItem(activitiesDesktopsMenu);
                    menuItem.text = activityInfo.activityName(runningActivities[i]);
                    menuItem.icon = activityInfo.activityIcon(runningActivities[i]);
                    menuItem.checkable = true;
                    menuItem.checked = Qt.binding((activityId => {
                        return () => menu.visualParent && menu.get(atm.Activities).indexOf(activityId) >= 0;
                    })(activityId));
                    menuItem.toggled.connect((activityId => {
                        return checked => {
                            let newActivities = menu.get(atm.Activities);
                            if (checked) {
                                newActivities = newActivities.concat(activityId);
                            } else {
                                const index = newActivities.indexOf(activityId);
                                if (index < 0) {
                                    return;
                                }

                                newActivities.splice(index, 1);
                            }
                            return tasksModel.requestActivities(menu.modelIndex, newActivities);
                        };
                    })(activityId));
                }

                menu.newSeparator(activitiesDesktopsMenu);

                for (let i = 0; i < runningActivities.length; ++i) {
                    const activityId = runningActivities[i];
                    const onActivities = menu.get(atm.Activities);

                    if (onActivities.length === 1 && onActivities[0] === activityId) {
                        continue;
                    }

                    menuItem = menu.newMenuItem(activitiesDesktopsMenu);
                    menuItem.text = i18n("Move to %1", activityInfo.activityName(activityId))
                    menuItem.icon = activityInfo.activityIcon(activityId)
                    menuItem.clicked.connect((activityId => {
                        return () => tasksModel.requestActivities(menu.modelIndex, [activityId]);
                    })(activityId));
                }

                menu.newSeparator(activitiesDesktopsMenu);
            }

            Component.onCompleted: refresh()
        }
    }

    PlasmaExtras.MenuItem {
        id: launcherToggleAction

        visible: visualParent
            && !get(atm.IsLauncher)
            && !get(atm.IsStartup)
            && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            && (activityInfo.numberOfRunningActivities < 2)
            && !doesBelongToCurrentActivity()

        enabled: visualParent && get(atm.LauncherUrlWithoutIcon).toString() !== ""

        text: i18nd("kernora-ui", "Pin to panel")
        icon: "window-pin"

        function doesBelongToCurrentActivity(): bool {
            return tasksModel.launcherActivities(get(atm.LauncherUrlWithoutIcon))
                .some(activity => activity === activityInfo.currentActivity || activity === activityInfo.nullUuid);
        }

        onClicked: {
            tasksModel.requestAddLauncher(get(atm.LauncherUrl));
        }
    }

    PlasmaExtras.MenuItem {
        id: showLauncherInActivitiesItem

        text: i18nd("kernora-ui", "Pin to panel")
        icon: "window-pin"

        visible: visualParent
            && !get(atm.IsStartup)
            && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            && (activityInfo.numberOfRunningActivities >= 2)

        readonly property Connections activitiesLaunchersMenuConnections: Connections {
            target: activityInfo

            function onNumberOfRunningActivitiesChanged(): void {
                activitiesDesktopsMenu.refresh()
            }
        }

        readonly property PlasmaExtras.Menu _activitiesLaunchersMenu: PlasmaExtras.Menu {
            id: activitiesLaunchersMenu
            visualParent: showLauncherInActivitiesItem.action

            function refresh(): void {
                clearMenuItems();

                if (menu.visualParent === null) return;

                const createNewItem = (id, title, iconName, url, activities) => {
                    var result = menu.newMenuItem(activitiesLaunchersMenu);
                    result.text = title;
                    result.icon = iconName;

                    result.visible = true;
                    result.checkable = true;

                    result.checked = activities.some(activity => activity === id);

                    result.clicked.connect(() => {
                        if (result.checked) {
                            tasksModel.requestAddLauncherToActivity(url, id);
                        } else {
                            tasksModel.requestRemoveLauncherFromActivity(url, id);
                        }
                    });

                    return result;
                };

                if (menu.visualParent === null) return;

                const url = menu.get(atm.LauncherUrlWithoutIcon);

                const activities = tasksModel.launcherActivities(url);

                createNewItem(activityInfo.nullUuid, i18n("On All Activities"), "", url, activities);

                if (activityInfo.numberOfRunningActivities <= 1) {
                    return;
                }

                createNewItem(activityInfo.currentActivity, i18n("On The Current Activity"), activityInfo.activityIcon(activityInfo.currentActivity), url, activities);

                menu.newSeparator(activitiesLaunchersMenu);

                activityInfo.runningActivities()
                    .forEach(id => {
                        createNewItem(id, activityInfo.activityName(id), activityInfo.activityIcon(id), url, activities);
                    });
            }

            Component.onCompleted: {
                menu.visualParentChanged.connect(refresh);
                refresh();
            }
        }
    }

    PlasmaExtras.MenuItem {
        visible: (visualParent
                && get(atm.IsStartup) !== true
                && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
                && !launcherToggleAction.visible
                && activityInfo.numberOfRunningActivities < 2)

        text: i18nd("kernora-ui", "Unpin from panel")
        icon: "window-unpin"

        onClicked: {
            tasksModel.requestRemoveLauncher(get(atm.LauncherUrlWithoutIcon));
        }
    }

    PlasmaExtras.MenuItem {
        id: moreActionsMenuItem

        visible: (visualParent && !get(atm.IsLauncher) && !get(atm.IsStartup))

        enabled: visible

        text: i18n("More")
        icon: "view-more-symbolic"

        readonly property PlasmaExtras.Menu moreMenu: PlasmaExtras.Menu {
            visualParent: moreActionsMenuItem.action

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(atm.IsMovable)

                text: i18n("&Move")
                icon: "transform-move"

                onClicked: tasksModel.requestMove(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(atm.IsResizable)

                text: i18n("Re&size")
                icon: "transform-scale"

                onClicked: tasksModel.requestResize(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                visible: (menu.visualParent && !get(atm.IsLauncher) && !get(atm.IsStartup))

                enabled: menu.visualParent && get(atm.IsMaximizable)

                checkable: true
                checked: menu.visualParent && get(atm.IsMaximized)

                text: i18n("Ma&ximize")
                icon: "window-maximize"

                onClicked: tasksModel.requestToggleMaximized(modelIndex)
            }

            PlasmaExtras.MenuItem {
                visible: (menu.visualParent && !get(atm.IsLauncher) && !get(atm.IsStartup))

                enabled: menu.visualParent && get(atm.IsMinimizable)

                checkable: true
                checked: menu.visualParent && get(atm.IsMinimized)

                text: i18n("Mi&nimize")
                icon: "window-minimize"

                onClicked: tasksModel.requestToggleMinimized(modelIndex)
            }

            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.visualParent && menu.get(atm.IsKeepAbove)

                text: i18n("Keep &Above Others")
                icon: "window-keep-above"

                onClicked: tasksModel.requestToggleKeepAbove(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.visualParent && menu.get(atm.IsKeepBelow)

                text: i18n("Keep &Below Others")
                icon: "window-keep-below"

                onClicked: tasksModel.requestToggleKeepBelow(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(atm.IsFullScreenable)

                checkable: true
                checked: menu.visualParent && menu.get(atm.IsFullScreen)

                text: i18n("&Fullscreen")
                icon: "view-fullscreen"

                onClicked: tasksModel.requestToggleFullScreen(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(atm.IsShadeable)

                checkable: true
                checked: menu.visualParent && menu.get(atm.IsShaded)

                text: i18n("&Shade")
                icon: "window-shade"

                onClicked: tasksModel.requestToggleShaded(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                separator: true
            }

            PlasmaExtras.MenuItem {
                visible: (Plasmoid.configuration.groupingStrategy !== 0) && menu.get(atm.IsWindow)

                checkable: true
                checked: menu.visualParent && menu.get(atm.IsGroupable)

                text: i18n("Allow this program to be grouped")
                icon: "view-group"

                onClicked: tasksModel.requestToggleGrouping(menu.modelIndex)
            }
        }
    }

    PlasmaExtras.MenuItem { separator: true }

    PlasmaExtras.MenuItem {
        id: closeWindowItem
        visible: (visualParent && !get(atm.IsLauncher) && !get(atm.IsStartup))

        enabled: visualParent && get(atm.IsClosable)

        text: get(atm.IsGroupParent) ? i18nc("@item:inmenu", "&Close All") : i18n("&Close")
        icon: "window-close"

        onClicked: {
            if (tasks.groupDialog !== null && tasks.groupDialog.visualParent === visualParent) {
                tasks.groupDialog.visible = false;
            }

            tasksModel.requestClose(modelIndex);
        }
    }
}
