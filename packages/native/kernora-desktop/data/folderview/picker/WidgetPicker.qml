/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kwindowsystem
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.shell as Shell
import org.kernora.m3
import "../HomeGrid.js" as HomeGrid

PlasmaCore.Dialog {
    id: window

    property rect area: Qt.rect(0, 0, 0, 0)
    property QtObject containment: null
    property real cellWidth: 144
    property real cellHeight: 100

    signal adding(string plugin)

    type: PlasmaCore.Dialog.AppletPopup
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
    visible: false

    x: area.x
    y: area.y

    function open(): void {
        scene.show();
    }

    onActiveChanged: {
        if (!active && !scene.dragging) {
            scene.hide();
        }
    }

    mainItem: Item {
        id: scene

        readonly property var appNames: ({
            "battery": i18nd("kernora-ui", "Battery"),
            "calendar": i18nd("kernora-ui", "Calendar"),
            "clock": i18nd("kernora-ui", "Clock"),
            "kernora": "Kernora",
            "player": i18nd("kernora-ui", "Media Player"),
            "notes": i18nd("kernora-ui", "Notes"),
            "photos": i18nd("kernora-ui", "Photos"),
            "taskmanager": i18nd("kernora-ui", "Task Manager"),
            "weather": i18nd("kernora-ui", "Weather")
        })
        readonly property var categoryNames: ({
            "essentials": i18nd("kernora-ui", "Essentials"),
            "others": i18nd("kernora-ui", "Suggested for you")
        })
        readonly property var apps: HomeGrid.apps.map(app => Object.assign({ name: appNames[app.id] || app.id }, app))
            .sort((a, b) => a.name.localeCompare(b.name))

        property real progress: 0
        property bool shown: false
        property bool dragging: false
        property string selected: "suggestions"
        property string query: ""
        property string addPlugin: ""
        property var info: ({})

        width: dragging ? 1 : window.area.width
        height: dragging ? 1 : window.area.height

        function ms(value: real): int {
            return Math.max(1, Math.round(value * M3.motionScale));
        }

        function show(): void {
            selected = "suggestions";
            query = "";
            search.text = "";
            addPlugin = "";
            dragging = false;
            explorer.containment = window.containment;
            collect();
            shown = true;
            window.visible = true;
            window.requestActivate();
            scene.forceActiveFocus();
            closeAnimation.stop();
            openAnimation.restart();
        }

        function hide(): void {
            if (!shown) {
                return;
            }
            shown = false;
            openAnimation.stop();
            closeAnimation.restart();
        }

        function finish(): void {
            window.visible = false;
            dragging = false;
        }

        function collect(): void {
            const found = {};
            for (let i = 0; i < collector.count; ++i) {
                const entry = collector.objectAt(i);
                if (entry && String(entry.pluginName).indexOf(HomeGrid.prefix) === 0) {
                    found[entry.pluginName] = { name: entry.name, description: entry.description };
                }
            }
            info = found;
        }

        function widgetName(plugin: string): string {
            return info[plugin] ? info[plugin].name : plugin;
        }

        function widgetDescription(plugin: string): string {
            return info[plugin] ? info[plugin].description : "";
        }

        function installed(plugins: var): var {
            return plugins.filter(plugin => !!info[plugin]);
        }

        function matches(plugin: string): bool {
            const text = query.trim().toLowerCase();
            if (text.length === 0) {
                return true;
            }
            return widgetName(plugin).toLowerCase().indexOf(text) >= 0
                || widgetDescription(plugin).toLowerCase().indexOf(text) >= 0;
        }

        readonly property var visibleApps: apps.filter(app => installed(app.plugins).some(plugin => matches(plugin)))
        readonly property var pageSections: {
            if (query.trim().length > 0) {
                const plugins = [];
                for (const app of visibleApps) {
                    for (const plugin of installed(app.plugins)) {
                        if (matches(plugin)) {
                            plugins.push(plugin);
                        }
                    }
                }
                return plugins.length > 0 ? [{ title: "", plugins: plugins }] : [];
            }
            if (selected === "suggestions") {
                return HomeGrid.suggestions.map(group => ({ title: categoryNames[group.id] || "", plugins: installed(group.plugins) }))
                    .filter(group => group.plugins.length > 0);
            }
            const app = apps.find(entry => entry.id === selected);
            return app ? [{ title: "", plugins: installed(app.plugins) }] : [];
        }

        function add(plugin: string): void {
            window.adding(plugin);
            explorer.addApplet(plugin);
            hide();
        }

        Keys.onEscapePressed: hide()

        Shell.WidgetExplorer {
            id: explorer
        }

        Instantiator {
            id: collector
            model: explorer.widgetsModel
            delegate: QtObject {
                required property string pluginName
                required property string name
                required property string description
            }
            onObjectAdded: Qt.callLater(scene.collect)
            onObjectRemoved: Qt.callLater(scene.collect)
        }

        NumberAnimation {
            id: openAnimation
            target: scene
            property: "progress"
            to: 1
            duration: scene.ms(450)
            easing.type: Easing.Bezier
            easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
        }

        SequentialAnimation {
            id: closeAnimation
            NumberAnimation {
                target: scene
                property: "progress"
                to: 0
                duration: scene.ms(250)
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
            }
            ScriptAction {
                script: scene.finish()
            }
        }

        Rectangle {
            anchors.fill: parent
            color: M3.scrim
            opacity: 0.32 * scene.progress * sheet.opacity
        }

        MouseArea {
            anchors.fill: parent
            enabled: scene.shown && !scene.dragging
            onClicked: scene.hide()
        }

        Rectangle {
            id: sheet

            readonly property real leftWidth: Math.round(width * 0.33)

            width: parent.width
            height: parent.height - 24
            y: parent.height - height * scene.progress
            topLeftRadius: 28
            topRightRadius: 28
            color: M3.surfaceContainer

            Behavior on opacity {
                NumberAnimation {
                    duration: scene.ms(150)
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: scene.addPlugin = ""
            }

            DragHandler {
                target: null
                yAxis.enabled: true
                xAxis.enabled: false
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                enabled: handleArea.containsMouse || active
                onActiveChanged: {
                    if (!active && translation.y > 96) {
                        scene.hide();
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 16
                width: 32
                height: 4
                radius: 2
                color: M3.outline
            }

            MouseArea {
                id: handleArea
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 36
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            MText {
                id: title
                anchors.horizontalCenter: parent.horizontalCenter
                y: 44
                role: "headlineSmall"
                text: i18nd("kernora-ui", "Widgets")
                color: M3.surfaceContent
            }

            Item {
                id: leftPane

                x: 24
                y: title.y + title.height + 8
                width: sheet.leftWidth - 24
                height: sheet.height - y - 8

                Rectangle {
                    id: searchBox

                    y: 24
                    width: parent.width - 24
                    height: 48
                    radius: 24
                    color: M3.dark ? M3.surfaceContainerHighest : M3.surfaceContainerLowest

                    MIcon {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        size: 24
                        source: "search"
                        color: M3.surfaceVariantContent
                    }

                    QQC2.TextField {
                        id: search

                        anchors.left: parent.left
                        anchors.leftMargin: 44
                        anchors.right: clearButton.visible ? clearButton.left : parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        placeholderText: i18nd("kernora-ui", "Search")
                        placeholderTextColor: M3.surfaceVariantContent
                        color: M3.surfaceContent
                        font: M3.bodyLarge
                        onTextChanged: {
                            scene.query = text;
                            scene.addPlugin = "";
                        }
                        Keys.onEscapePressed: scene.hide()
                    }

                    MIconButton {
                        id: clearButton
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text.length > 0
                        icon: "window-close"
                        text: i18nd("kernora-ui", "Clear text from search box")
                        onClicked: search.text = ""
                    }
                }

                ListView {
                    id: appList

                    anchors.top: searchBox.bottom
                    anchors.topMargin: 16
                    anchors.bottom: parent.bottom
                    width: parent.width - 24
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: scene.query.trim().length > 0 ? scene.visibleApps
                        : [{ id: "suggestions", name: i18nd("kernora-ui", "Suggestions"), icon: "", plugins: [] }].concat(scene.visibleApps)

                    delegate: Item {
                        id: row

                        required property var modelData
                        readonly property bool current: scene.query.trim().length === 0 && scene.selected === modelData.id

                        width: ListView.view.width
                        height: 88

                        Rectangle {
                            anchors.fill: parent
                            radius: 28
                            color: row.current ? M3.secondaryContainer : "transparent"
                        }

                        MStateLayer {
                            radius: 28
                            color: M3.surfaceContent
                            hovered: rowMouse.containsMouse && !row.current
                            pressed: rowMouse.pressed
                            pressPoint: Qt.point(rowMouse.mouseX, rowMouse.mouseY)
                        }

                        Item {
                            id: appIcon
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 48
                            height: 48

                            Rectangle {
                                anchors.fill: parent
                                radius: 24
                                visible: row.modelData.id === "suggestions"
                                color: M3.dark ? M3.surfaceContent : "#ffffff"

                                MIcon {
                                    anchors.centerIn: parent
                                    size: 24
                                    source: "preferences-desktop-widgets"
                                    color: M3.primary
                                }
                            }

                            Kirigami.Icon {
                                anchors.fill: parent
                                visible: row.modelData.id !== "suggestions"
                                source: row.modelData.icon
                                animated: false
                            }
                        }

                        Column {
                            anchors.left: appIcon.right
                            anchors.leftMargin: 16
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter

                            MText {
                                width: parent.width
                                role: "titleMedium"
                                text: row.modelData.name
                                color: row.current ? M3.secondaryContainerContent : M3.surfaceContent
                            }
                            MText {
                                width: parent.width
                                visible: row.modelData.id !== "suggestions"
                                role: "bodyMedium"
                                text: i18ndp("kernora-ui", "%1 widget", "%1 widgets", scene.installed(row.modelData.plugins || []).length)
                                color: row.current ? M3.secondaryContainerContent : M3.surfaceVariantContent
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                scene.selected = row.modelData.id;
                                scene.addPlugin = "";
                                if (search.text.length > 0) {
                                    search.text = "";
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: rightPane

                x: sheet.leftWidth
                y: leftPane.y + 24
                width: sheet.width - sheet.leftWidth - 24
                height: sheet.height - y - 24
                radius: 28
                color: M3.dark ? M3.surfaceContainerHighest : M3.surfaceContainerLowest
                clip: true

                MText {
                    anchors.centerIn: parent
                    visible: scene.pageSections.length === 0
                    role: "titleLarge"
                    text: i18nd("kernora-ui", "No widgets found")
                    color: M3.surfaceVariantContent
                }

                Flickable {
                    id: page

                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: sections.implicitHeight + 48
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: sections

                        x: 24
                        y: 24
                        width: page.width - 48
                        spacing: 24

                        Repeater {
                            model: scene.pageSections

                            delegate: Column {
                                id: section

                                required property var modelData

                                width: sections.width
                                spacing: 16

                                MText {
                                    visible: section.modelData.title.length > 0
                                    role: "titleMedium"
                                    text: section.modelData.title
                                    color: M3.surfaceContent
                                }

                                Flow {
                                    width: parent.width
                                    spacing: 16

                                    Repeater {
                                        model: section.modelData.plugins

                                        delegate: WidgetCell {
                                            required property string modelData
                                            plugin: modelData
                                            name: scene.widgetName(modelData)
                                            description: scene.widgetDescription(modelData)
                                            span: HomeGrid.span(modelData)
                                            kind: HomeGrid.kind(modelData)
                                            cellWidth: window.cellWidth
                                            cellHeight: window.cellHeight
                                            showAdd: scene.addPlugin === modelData
                                            onTapped: scene.addPlugin = scene.addPlugin === modelData ? "" : modelData
                                            onAddRequested: scene.add(modelData)
                                            onDragStarted: scene.dragging = true
                                            onDragFinished: {
                                                scene.shown = false;
                                                scene.progress = 0;
                                                scene.finish();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                MScrollIndicator {
                    flickable: page
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }
            }
        }
    }
}
