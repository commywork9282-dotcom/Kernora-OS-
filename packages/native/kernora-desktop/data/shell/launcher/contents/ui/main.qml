/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.coreaddons as KCoreAddons
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.sessions as Sessions
import org.kernora.bartint
import "m3"

PlasmoidItem {
    id: root

    readonly property bool googlebook: Plasmoid.configuration.menuStyle !== "classic"

    Plasmoid.icon: "start-here-kde"
    Plasmoid.title: i18n("Applications")
    preferredRepresentation: googlebook ? fullRepresentation : compactRepresentation
    hideOnWindowDeactivate: true
    activationTogglesExpanded: true
    toolTipMainText: ""
    toolTipSubText: ""

    Kicker.RootModel {
        id: rootModel

        autoPopulate: false
        appletInterface: root
        appNameFormat: 0
        flat: true
        sorted: true
        showSeparators: false
        showTopLevelItems: false
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: false

        Component.onCompleted: {
            favoritesModel.initForClient("org.kernora.launcher.favorites.instance-" + Plasmoid.id);
            if (!Plasmoid.configuration.favoritesPortedToKAstats) {
                if (favoritesModel.count < 1) {
                    favoritesModel.portOldFavorites(Plasmoid.configuration.favorites);
                }
                Plasmoid.configuration.favoritesPortedToKAstats = true;
            }
            refresh();
        }
    }

    readonly property string panelOpacityRequest: Plasmoid.configuration.panelOpacityRequest
    onPanelOpacityRequestChanged: {
        const mode = parseInt(panelOpacityRequest, 10);
        const view = root.Window.window;
        if (mode >= 0 && mode <= 2 && view && view.opacityMode !== undefined) {
            view.opacityMode = mode;
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: source => disconnectSource(source)
    }

    Timer {
        property bool again: false
        interval: again ? 70000 : 3000
        repeat: true
        running: Plasmoid.configuration.reclaimShortcuts
        onTriggered: {
            executable.connectSource("/usr/libexec/kernora-panel-shortcuts");
            if (again) {
                Plasmoid.configuration.reclaimShortcuts = false;
            }
            again = true;
        }
    }

    property var appsModel: null
    Connections {
        target: rootModel
        function onRefreshed(): void {
            root.appsModel = rootModel.modelForRow(0);
        }
    }

    Kicker.RunnerModel {
        id: runnerModel
        appletInterface: root
        mergeResults: true
        favoritesModel: rootModel.favoritesModel
        query: !root.googlebook && root.fullRepresentationItem ? root.fullRepresentationItem.query : ""
    }

    Sessions.SessionManagement {
        id: session
    }

    KCoreAddons.KUser {
        id: user
    }

    function launch(model: var, index: int): void {
        if (model && model.trigger && model.trigger(index, "", null)) {
            root.expanded = false;
        }
    }

    compactRepresentation: LauncherButton {
        active: root.expanded
        square: Plasmoid.configuration.buttonShape !== "round"
        onClicked: root.expanded = !root.expanded
    }

    function quoted(text: string): string {
        return "'" + text.replace(/'/g, "'\\''") + "'";
    }

    function runDetached(command: string): void {
        executable.connectSource(command + " >/dev/null 2>&1 &");
    }

    function searchWeb(text: string): void {
        runDetached("librewolf --search " + quoted(text));
    }

    function searchStore(text: string): void {
        runDetached("kernora-store " + quoted("search:" + text));
    }

    function showAppInfo(storageId: string): void {
        const id = storageId.replace(/\.desktop$/, "");
        if (id.startsWith("waydroid.")) {
            runDetached("kernora-settings android");
        } else if (id.length > 0) {
            runDetached("kernora-store " + quoted("appstream:" + id));
        }
    }

    function taskManager(): var {
        let top = root;
        while (top.parent) {
            top = top.parent;
        }
        const pending = [top];
        while (pending.length > 0) {
            const item = pending.shift();
            if (item !== root && typeof item.hasLauncher === "function"
                    && typeof item.addLauncher === "function" && typeof item.removeLauncher === "function") {
                return item;
            }
            for (const child of item.children) {
                pending.push(child);
            }
        }
        return null;
    }

    property bool acceptActivations: false
    Timer {
        id: settle
        interval: 2000
        running: true
        onTriggered: root.acceptActivations = true
    }
    onGooglebookChanged: {
        root.acceptActivations = false;
        settle.restart();
    }
    readonly property bool arranging: (Plasmoid.containment?.corona?.editMode ?? false) || (Plasmoid.containment?.userConfiguring ?? false)
    onExpandedChanged: {
        if (root.googlebook && root.acceptActivations && !root.arranging && drawer.item) {
            drawer.item.toggle(true);
        }
    }

    Connections {
        target: LauncherState
        enabled: root.googlebook
        function onOpenRequested(screen: string): void {
            if (drawer.item && screen === drawer.item.screenName && !drawer.item.visible) {
                drawer.item.toggle(false);
            }
        }
        function onCloseRequested(): void {
            if (drawer.item && drawer.item.visible) {
                drawer.item.dismiss();
            }
        }
    }

    Loader {
        id: drawer
        active: root.googlebook
        sourceComponent: DrawerWindow {
            launcher: root
            appsModel: root.appsModel
        }
    }

    fullRepresentation: Item {
        id: full

        readonly property string query: classic.item ? classic.item.query : ""

        Layout.minimumWidth: root.googlebook ? pill.implicitWidth : 520
        Layout.preferredWidth: root.googlebook ? pill.implicitWidth : 760
        Layout.maximumWidth: root.googlebook ? pill.implicitWidth : Number.POSITIVE_INFINITY
        Layout.minimumHeight: root.googlebook ? pill.implicitHeight : 440
        Layout.preferredHeight: root.googlebook ? pill.implicitHeight
            : Math.max(440, Math.min(680, Math.ceil(classic.item ? classic.item.idealHeight : 640)))
        Layout.fillHeight: root.googlebook

        DrawerButton {
            id: pill
            anchors.fill: parent
            visible: root.googlebook
            active: drawer.item ? drawer.item.shown : false
            onPressed: {
                if (drawer.item) {
                    drawer.item.notePress();
                }
            }
            onClicked: {
                if (drawer.item) {
                    drawer.item.clickToggle();
                }
            }
        }

        Loader {
            id: classic
            anchors.fill: parent
            active: !root.googlebook
            focus: true
            sourceComponent: LauncherView {
                focus: true

                appsModel: root.appsModel
                pinnedModel: rootModel.favoritesModel
                resultsModel: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null

                userName: user.fullName.length > 0 ? user.fullName : user.loginName
                userFace: user.faceIconUrl
                canLock: session.canLock
                canLogout: session.canLogout
                canShutdown: session.canShutdown

                onLaunch: (model, index) => root.launch(model, index)
                onRequestClose: root.expanded = false
                onOpenSettings: {
                    root.expanded = false;
                    KCMUtils.KCMLauncher.openSystemSettings("kcm_landingpage");
                }
                onLockScreen: {
                    root.expanded = false;
                    session.lock();
                }
                onLogOut: {
                    root.expanded = false;
                    session.requestLogout();
                }
                onShutDown: {
                    root.expanded = false;
                    session.requestShutdown();
                }
                onRestart: {
                    root.expanded = false;
                    session.requestReboot();
                }
            }
        }

        Connections {
            target: root
            function onExpandedChanged(): void {
                if (root.expanded && classic.item) {
                    classic.item.reset();
                }
            }
        }
    }
}
