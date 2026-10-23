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
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.sessions as Sessions
import "m3"

PlasmoidItem {
    id: root

    Plasmoid.icon: "start-here-kde"
    Plasmoid.title: i18n("Applications")
    preferredRepresentation: compactRepresentation
    hideOnWindowDeactivate: true
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
        query: root.fullRepresentationItem ? root.fullRepresentationItem.query : ""
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
        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: Item {
        id: full

        readonly property string query: view.query

        Layout.preferredWidth: 760
        Layout.preferredHeight: Math.max(Layout.minimumHeight, Math.min(680, Math.ceil(view.idealHeight)))
        Layout.minimumWidth: 520
        Layout.minimumHeight: 440

        LauncherView {
            id: view
            anchors.fill: parent
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

        Connections {
            target: root
            function onExpandedChanged(): void {
                if (root.expanded) {
                    view.reset();
                }
            }
        }
    }
}
