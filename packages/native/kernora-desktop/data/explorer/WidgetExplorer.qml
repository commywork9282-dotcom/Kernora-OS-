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

Item {
    id: main

    readonly property string kernoraPrefix: "org.kernora.widget."
    readonly property bool forPanel: !!containment && containment.containmentType == 1
    readonly property int cardSpacing: 12
    readonly property int cardHeight: 228
    readonly property var kernoraOrder: ["clock", "glance", "weather", "calendar", "battery", "media", "photo", "note"]
    property var kernoraKinds: []

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

    function rank(kind: string): int {
        const position = kernoraOrder.indexOf(kind);
        return position < 0 ? kernoraOrder.length : position;
    }

    function before(kind: string, other: string): bool {
        return rank(kind) < rank(other) || (rank(kind) === rank(other) && kind < other);
    }

    function refreshKinds(): void {
        const kinds = [];
        for (let i = 0; i < kernoraWidgets.count; ++i) {
            const item = kernoraWidgets.itemAt(i);
            if (item && item.shown) {
                kinds.push(item.kind);
            }
        }
        kernoraKinds = kinds;
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
        const pending = pendingUninstallTimer.applets;
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
                        implicitHeight: main.kernoraKinds.length === 0 ? 0
                            : Math.ceil(main.kernoraKinds.length / 2) * (main.cardHeight + main.cardSpacing) - main.cardSpacing
                        height: implicitHeight

                        Repeater {
                            id: kernoraWidgets

                            onItemAdded: Qt.callLater(main.refreshKinds)
                            onItemRemoved: Qt.callLater(main.refreshKinds)

                            delegate: Item {
                                id: card

                                required property var model
                                required property int index
                                readonly property string pluginName: model.pluginName
                                readonly property string kind: pluginName.slice(main.kernoraPrefix.length)

                                readonly property bool shown: !main.forPanel && pluginName.startsWith(main.kernoraPrefix)
                                readonly property int slot: main.kernoraKinds.filter(other => main.before(other, card.kind)).length

                                visible: shown
                                x: (slot % 2) * (width + main.cardSpacing)
                                y: Math.floor(slot / 2) * (height + main.cardSpacing)
                                width: (kernoraGrid.width - main.cardSpacing) / 2
                                height: main.cardHeight

                                Accessible.role: Accessible.Button
                                Accessible.name: model.name
                                Accessible.description: model.description

                                Kirigami.ShadowedRectangle {
                                    id: cardSurface
                                    readonly property var shadowSpec: M3.elevationOf("card")
                                    anchors.fill: parent
                                    radius: M3.classic ? M3.cornerCard : 24
                                    color: !M3.classic ? M3.surfaceContainerHigh : M3.dark ? M3.surfaceContainerHighest : M3.surfaceContainerLowest
                                    shadow.size: M3.classic ? shadowSpec.blur * 2 : 0
                                    shadow.yOffset: M3.classic ? shadowSpec.offset : 0
                                    shadow.color: Qt.rgba(0, 0, 0, shadowSpec.opacity)

                                    MStateLayer {
                                        radius: cardSurface.radius
                                        hovered: cardHover.hovered
                                        pressed: cardTap.pressed
                                        dragged: cardDrag.active
                                        pressPoint: Qt.point(cardTap.mouseX, cardTap.mouseY)
                                    }
                                }

                                Rectangle {
                                    id: stage
                                    x: 8
                                    y: 8
                                    width: parent.width - 16
                                    height: 132
                                    radius: M3.classic ? M3.cornerCardInner : cardSurface.radius - 8
                                    color: M3.classic ? M3.withAlpha(M3.surfaceContent, M3.dark ? 0.06 : 0.04) : M3.surfaceContainerLowest

                                    WidgetPreview {
                                        anchors.fill: parent
                                        kind: card.kind
                                        icon: card.model.decoration
                                    }

                                    Rectangle {
                                        id: badge
                                        readonly property bool removing: badgeHover.hovered && !cardDrag.active
                                        visible: card.model.running > 0
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        height: 28
                                        width: Math.max(28, badgeRow.implicitWidth + 14)
                                        radius: 14
                                        color: removing ? M3.inverseSurface : M3.primary

                                        Accessible.role: Accessible.Button
                                        Accessible.name: main.shell("Remove all instances")

                                        Row {
                                            id: badgeRow
                                            anchors.centerIn: parent
                                            spacing: 2

                                            MIcon {
                                                anchors.verticalCenter: parent.verticalCenter
                                                size: 18
                                                source: badge.removing ? "window-close" : "checkmark"
                                                color: badge.removing ? M3.inverseOnSurface : M3.primaryContent
                                            }
                                            MText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: card.model.running > 1
                                                role: "labelMedium"
                                                text: card.model.running
                                                color: badge.removing ? M3.inverseOnSurface : M3.primaryContent
                                            }
                                        }

                                        HoverHandler {
                                            id: badgeHover
                                            margin: 6
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: main.removeInstances(card.pluginName)
                                        }
                                    }
                                }

                                ColumnLayout {
                                    anchors.top: stage.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 14
                                    anchors.topMargin: 12
                                    spacing: 2

                                    MText {
                                        Layout.fillWidth: true
                                        role: "titleSmall"
                                        text: card.model.name
                                        elide: Text.ElideRight
                                    }
                                    MText {
                                        Layout.fillWidth: true
                                        role: "bodySmall"
                                        text: card.model.description
                                        color: M3.surfaceVariantContent
                                        wrapMode: Text.Wrap
                                        elide: Text.ElideRight
                                        maximumLineCount: 3
                                    }
                                }

                                HoverHandler {
                                    id: cardHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                MouseArea {
                                    id: cardTap
                                    anchors.fill: parent
                                    z: -1
                                    onClicked: widgetExplorer.addApplet(card.pluginName)
                                }

                                WidgetDrag {
                                    id: cardDrag
                                    anchors.fill: parent
                                    z: -2
                                    pluginName: card.pluginName
                                    preview: stage
                                    onStarted: main.draggingWidget = true
                                    onFinished: main.draggingWidget = false
                                }
                            }
                        }
                    }

                    MText {
                        visible: otherList.implicitHeight > 0
                        topPadding: kernoraGrid.implicitHeight > 0 ? 12 : 0
                        leftPadding: 4
                        role: "titleSmall"
                        color: M3.primary
                        text: main.tr("Other widgets")
                    }

                    Column {
                        id: otherList
                        width: parent.width
                        spacing: 2

                        Repeater {
                            id: otherWidgets

                            delegate: UI.ListItem {
                                id: row

                                required property var model
                                required property int index
                                readonly property string pluginName: model.pluginName
                                readonly property bool pendingUninstall: pendingUninstallTimer.applets.indexOf(pluginName) > -1

                                visible: main.forPanel || !pluginName.startsWith("org.kernora.")
                                enabled: model.isSupported
                                opacity: pendingUninstall ? 0.6 : (enabled ? 1 : 0.38)
                                title: model.name
                                subtitle: model.isSupported ? model.description : model.unsupportedMessage
                                onClicked: widgetExplorer.addApplet(row.pluginName)

                                leading: Component {
                                    Rectangle {
                                        implicitWidth: 40
                                        implicitHeight: 40
                                        radius: 20
                                        color: M3.surfaceContainerHighest

                                        Kirigami.Icon {
                                            anchors.centerIn: parent
                                            implicitWidth: 24
                                            implicitHeight: 24
                                            source: row.model.decoration
                                            animated: false
                                        }
                                    }
                                }

                                trailing: Component {
                                    Row {
                                        MIconButton {
                                            visible: row.model.running > 0
                                            icon: "edit-clear-all"
                                            text: main.shell("Remove all instances")
                                            onClicked: main.removeInstances(row.pluginName)
                                        }
                                        MIconButton {
                                            visible: row.model.local
                                            icon: row.pendingUninstall ? "edit-undo" : "edit-delete"
                                            text: row.pendingUninstall ? main.shell("Undo uninstall")
                                                                       : i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:tooltip uninstall a widget", "Uninstall")
                                            onClicked: main.toggleUninstall(row.pluginName)
                                        }
                                    }
                                }

                                WidgetDrag {
                                    id: rowDrag
                                    anchors.fill: parent
                                    z: -1
                                    enabled: !row.pendingUninstall
                                    pluginName: row.pluginName
                                    preview: row
                                    onStarted: main.draggingWidget = true
                                    onFinished: main.draggingWidget = false
                                }
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
        visible: !setModelTimer.running && kernoraGrid.implicitHeight === 0 && otherList.implicitHeight === 0
        icon: "search"
        title: searchInput.text.length > 0 ? main.shell("No widgets matched the search terms") : main.shell("No widgets available")
    }
}
