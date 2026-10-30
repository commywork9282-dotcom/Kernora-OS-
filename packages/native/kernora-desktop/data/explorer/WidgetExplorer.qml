/*
    SPDX-FileCopyrightText: 2011 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kwindowsystem
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.shell
import org.kernora.m3
import org.kernora.ui as UI
import "widgets.js" as Widgets

Item {
    id: main

    readonly property string kernoraPrefix: Widgets.kernoraPrefix
    readonly property bool forPanel: !!containment && containment.containmentType == 1
    readonly property int cardSpacing: 12
    readonly property int cardHeight: 236
    readonly property var kernoraOrder: ["clock", "glance", "weather", "calendar", "battery", "media", "photo", "note"]
    readonly property var pendingUninstalls: pendingUninstallTimer.applets
    property var kernoraShown: []
    property var otherShown: []

    property QtObject containment
    property PlasmaCore.Dialog sidePanel
    property bool draggingWidget: false
    property bool preventWindowHide: draggingWidget || moreMenu.visible
    property bool outputOnly: draggingWidget

    signal closed()

    width: 412
    height: 800
    opacity: draggingWidget ? 0.3 : 1

    function tr(text: string): string {
        return i18nd("kernora-ui", text);
    }

    function shell(text: string): string {
        return i18nd("plasma_shell_org.kde.plasma.desktop", text);
    }

    function kernoraRank(pluginName: string): int {
        const position = kernoraOrder.indexOf(pluginName.slice(kernoraPrefix.length));
        return position < 0 ? kernoraOrder.length : position;
    }

    function shownIn(repeater: Repeater, rank: var): var {
        const cards = [];
        for (let i = 0; i < repeater.count; ++i) {
            const card = repeater.itemAt(i);
            if (card && card.shown) {
                cards.push(card);
            }
        }
        cards.sort((a, b) => rank(a.pluginName) - rank(b.pluginName) || a.title.localeCompare(b.title));
        return cards.map(card => card.pluginName);
    }

    function refresh(): void {
        kernoraShown = shownIn(kernoraWidgets, kernoraRank);
        otherShown = shownIn(otherWidgets, pluginName => Widgets.rank(pluginName, forPanel));
    }

    function gridHeight(count: int): real {
        return count === 0 ? 0 : Math.ceil(count / 2) * (cardHeight + cardSpacing) - cardSpacing;
    }

    function addApplet(pluginName: string): void {
        widgetExplorer.addApplet(pluginName);
    }

    function removeInstances(pluginName: string): void {
        const applets = main.containment ? Array.from(main.containment.applets) : [];
        for (const applet of applets) {
            if (applet.pluginName !== pluginName) {
                continue;
            }
            const action = applet.internalAction("remove");
            if (action) {
                action.enabled = true;
                action.trigger();
            }
        }
    }

    function toggleUninstall(pluginName: string): void {
        const pending = pendingUninstallTimer.applets.slice();
        const index = pending.indexOf(pluginName);
        if (index > -1) {
            pending.splice(index, 1);
        } else {
            pending.push(pluginName);
        }
        pendingUninstallTimer.applets = pending;
        if (pending.length > 0) {
            pendingUninstallTimer.restart();
        } else {
            pendingUninstallTimer.stop();
        }
    }

    onForPanelChanged: Qt.callLater(refresh)

    onPreventWindowHideChanged: {
        if (!preventWindowHide && !sidePanel.active) {
            sidePanel.requestActivate();
        }
    }

    onClosed: {
        if (root.widgetExplorer.containment
                && root.widgetExplorer.containment.containmentType == 1
                && !root.widgetExplorer.containment.userConfiguring) {
            root.widgetExplorer.containment.internalAction("configure").trigger();
        }
    }

    onVisibleChanged: {
        if (!visible) {
            KWindowSystem.showingDesktop = false;
        }
    }

    Component.onCompleted: {
        if (!root.widgetExplorer) {
            root.widgetExplorer = widgetExplorerComponent.createObject(root);
        }
        root.widgetExplorer.containment = main.containment;
    }

    Component.onDestruction: {
        if (pendingUninstallTimer.running) {
            widgetExplorer.widgetsModel.filterQuery = "";
            widgetExplorer.widgetsModel.filterType = "";
            widgetExplorer.widgetsModel.searchTerm = "";
        } else {
            root.widgetExplorer.destroy();
            root.widgetExplorer = null;
        }
    }

    Component {
        id: widgetExplorerComponent

        WidgetExplorer {
            onShouldClose: main.closed()
        }
    }

    QQC2.Action {
        shortcut: "Escape"
        onTriggered: {
            if (searchInput.text.length > 0) {
                searchInput.text = "";
            } else {
                main.closed();
            }
        }
    }

    Timer {
        id: setModelTimer
        interval: 20
        running: true
        onTriggered: {
            kernoraWidgets.model = widgetExplorer.widgetsModel;
            otherWidgets.model = widgetExplorer.widgetsModel;
        }
    }

    MMenu {
        id: moreMenu
        parent: main
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 8
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            MText {
                Layout.fillWidth: true
                role: "headlineSmall"
                text: main.shell("Widgets")
                elide: Text.ElideRight
            }
            MIconButton {
                id: moreButton
                icon: "overflow-menu"
                text: main.tr("More")
                onClicked: {
                    const store = i18nd("plasmashellprivateplugin", "Download New Plasma Widgets");
                    moreMenu.items = Array.from(widgetExplorer.widgetsMenuActions)
                        .filter(action => !action.separator && action.text.length > 0 && action.text !== store)
                        .map(action => ({
                            icon: action.icon,
                            text: action.text.replace(/&(?!&)/g, ""),
                            action: () => action.trigger()
                        }));
                    moreMenu.openAt(moreButton, 0, moreButton.height);
                }
            }
            MIconButton {
                icon: "window-close"
                text: main.tr("Close")
                onClicked: main.closed()
            }
        }

        UI.SearchField {
            id: searchInput
            Layout.fillWidth: true
            placeholderText: main.tr("Search widgets")
            onTextChanged: {
                flick.contentY = 0;
                widgetExplorer.widgetsModel.searchTerm = text;
            }
            Component.onCompleted: {
                if (!Kirigami.InputMethod.willShowOnActive) {
                    forceActiveFocus();
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: flick
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: content.implicitHeight + 16
                interactive: Kirigami.Settings.hasTransientTouchInput
                boundsBehavior: Flickable.StopAtBounds
                opacity: setModelTimer.running ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: M3.durationMedium2
                    }
                }

                Kirigami.WheelHandler {
                    target: flick
                }

                Column {
                    id: content
                    width: flick.width
                    spacing: 12

                    MText {
                        visible: kernoraGrid.implicitHeight > 0
                        leftPadding: 4
                        role: "titleSmall"
                        color: M3.primary
                        text: "Kernora"
                    }

                    Item {
                        id: kernoraGrid
                        width: parent.width
                        implicitHeight: main.gridHeight(main.kernoraShown.length)
                        height: implicitHeight

                        Repeater {
                            id: kernoraWidgets

                            onItemAdded: Qt.callLater(main.refresh)
                            onItemRemoved: Qt.callLater(main.refresh)

                            delegate: WidgetCard {
                                id: kernoraCard
                                explorer: main
                                shown: !main.forPanel && kernoraCard.pluginName.startsWith(main.kernoraPrefix)
                                slot: main.kernoraShown.indexOf(kernoraCard.pluginName)
                                spacing: main.cardSpacing
                                pendingUninstalls: main.pendingUninstalls
                                width: (kernoraGrid.width - main.cardSpacing) / 2
                                height: main.cardHeight
                            }
                        }
                    }

                    MText {
                        visible: otherGrid.implicitHeight > 0
                        topPadding: kernoraGrid.implicitHeight > 0 ? 12 : 0
                        leftPadding: 4
                        role: "titleSmall"
                        color: M3.primary
                        text: main.tr("Other widgets")
                    }

                    Item {
                        id: otherGrid
                        width: parent.width
                        implicitHeight: main.gridHeight(main.otherShown.length)
                        height: implicitHeight

                        Repeater {
                            id: otherWidgets

                            onItemAdded: Qt.callLater(main.refresh)
                            onItemRemoved: Qt.callLater(main.refresh)

                            delegate: WidgetCard {
                                id: otherCard
                                explorer: main
                                shown: main.forPanel || !otherCard.pluginName.startsWith("org.kernora.")
                                slot: main.otherShown.indexOf(otherCard.pluginName)
                                spacing: main.cardSpacing
                                pendingUninstalls: main.pendingUninstalls
                                width: (otherGrid.width - main.cardSpacing) / 2
                                height: main.cardHeight
                            }
                        }
                    }
                }
            }

            MScrollIndicator {
                flickable: flick
            }
        }

        MButton {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            visible: pendingUninstallTimer.applets.length > 0
            icon: "edit-delete"
            text: i18ndcp("plasma_shell_org.kde.plasma.desktop", "@action:button uninstall widgets in widget explorer",
                          "Confirm Removal of One Widget", "Confirm Removal of %1 Widgets", pendingUninstallTimer.applets.length)
            onClicked: pendingUninstallTimer.uninstall()
        }
    }

    UI.EmptyState {
        anchors.centerIn: parent
        width: parent.width - 48
        visible: !setModelTimer.running && kernoraGrid.implicitHeight === 0 && otherGrid.implicitHeight === 0
        icon: "search"
        title: searchInput.text.length > 0 ? main.shell("No widgets matched the search terms") : main.shell("No widgets available")
    }
}
