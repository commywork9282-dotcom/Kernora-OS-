/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
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
    property string app: ""
    property var entries: []
    property string current: ""
    property rect avoid: Qt.rect(0, 0, 0, 0)
    readonly property real coverBottom: Math.max(0, avoid.y + avoid.height - (area.y + area.height - scene.sheetHeight))
    readonly property real coverTop: Math.max(0, area.y + scene.sheetHeight - avoid.y)
    readonly property bool atTop: avoid.height > 0 && coverTop < coverBottom

    signal applied(string entry)
    signal adding(string entry)

    type: PlasmaCore.Dialog.AppletPopup
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
    visible: false

    x: Math.round(area.x + (area.width - scene.width) / 2)
    y: Math.round(atTop ? area.y : area.y + area.height - scene.height)

    function open(): void {
        scene.show();
    }

    function close(): void {
        scene.hide();
    }

    onActiveChanged: {
        if (!active) {
            scene.hide();
        }
    }

    mainItem: Item {
        id: scene

        readonly property real shadow: 24
        readonly property real gutter: 24
        readonly property real contentWidth: {
            let total = 0;
            for (const entry of window.entries) {
                total += scene.cellOf(entry) + (total > 0 ? cells.spacing : 0);
            }
            return total;
        }
        readonly property real sheetWidth: Math.min(window.area.width - 2 * gutter,
                                                     Math.max(480, contentWidth + 2 * gutter + 32))
        readonly property real panelHeight: cells.implicitHeight + 32
        readonly property real sheetHeight: 24 + title.implicitHeight + 20 + panelHeight + gutter

        property real progress: 0
        property bool shown: false
        property string selected: ""
        property var info: ({})

        width: sheetWidth + 2 * shadow
        height: sheetHeight + shadow

        function cellOf(entry: string): real {
            const span = HomeGrid.span(entry);
            return Math.max(Math.round((span[0] * window.cellWidth - 16) * 0.6), 176);
        }

        function ms(value: real): int {
            return Math.max(1, Math.round(value * M3.motionScale));
        }

        function show(): void {
            selected = "";
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

        function collect(): void {
            const found = {};
            for (let i = 0; i < collector.count; ++i) {
                const entry = collector.objectAt(i);
                if (entry && String(entry.pluginName).indexOf(HomeGrid.prefix) === 0) {
                    found[entry.pluginName] = entry.name;
                }
            }
            info = found;
        }

        function widgetName(entry: string): string {
            if (names.variants[entry]) {
                return names.variants[entry];
            }
            const plugin = HomeGrid.plugin(entry);
            return info[plugin] || plugin;
        }

        function same(entry: string): bool {
            return HomeGrid.plugin(entry) === HomeGrid.plugin(window.current);
        }

        WidgetNames {
            id: names
        }

        Shell.WidgetExplorer {
            id: explorer
        }

        Instantiator {
            id: collector
            model: explorer.widgetsModel
            delegate: QtObject {
                required property string pluginName
                required property string name
            }
            onObjectAdded: Qt.callLater(scene.collect)
            onObjectRemoved: Qt.callLater(scene.collect)
        }

        NumberAnimation {
            id: openAnimation
            target: scene
            property: "progress"
            to: 1
            duration: scene.ms(400)
            easing.type: Easing.Bezier
            easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
        }

        SequentialAnimation {
            id: closeAnimation
            NumberAnimation {
                target: scene
                property: "progress"
                to: 0
                duration: scene.ms(200)
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
            }
            ScriptAction {
                script: window.visible = false
            }
        }

        Keys.onEscapePressed: scene.hide()

        Item {
            anchors.fill: parent
            clip: true

            Kirigami.ShadowedRectangle {
                id: sheet

                readonly property real travel: (1 - scene.progress) * (scene.sheetHeight + scene.shadow)

                x: scene.shadow
                y: window.atTop ? -travel : scene.shadow + travel
                width: scene.sheetWidth
                height: scene.sheetHeight
                color: M3.surfaceContainer
                corners.topLeftRadius: window.atTop ? 0 : 28
                corners.topRightRadius: window.atTop ? 0 : 28
                corners.bottomLeftRadius: window.atTop ? 28 : 0
                corners.bottomRightRadius: window.atTop ? 28 : 0
                shadow.size: 18
                shadow.yOffset: window.atTop ? 2 : -2
                shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.36 : 0.16)

                MouseArea {
                    anchors.fill: parent
                    onClicked: scene.selected = ""
                }

                MText {
                    id: title
                    y: 24
                    width: parent.width
                    role: "headlineSmall"
                    horizontalAlignment: Text.AlignHCenter
                    text: names.apps[window.app] || window.app
                    color: M3.surfaceContent
                }

                Rectangle {
                    id: panel

                    x: scene.gutter
                    y: title.y + title.implicitHeight + 20
                    width: parent.width - 2 * scene.gutter
                    height: scene.panelHeight
                    radius: 28
                    color: M3.dark ? M3.surfaceContainerHighest : M3.surfaceContainerLowest
                    clip: true

                    Flickable {
                        id: strip

                        anchors.fill: parent
                        anchors.margins: 16
                        contentWidth: cells.width
                        contentHeight: height
                        interactive: contentWidth > width
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.HorizontalFlick

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse
                            onWheel: event => {
                                const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                                strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width, strip.contentX - delta));
                            }
                        }

                        Row {
                            id: cells

                            x: Math.max(0, (strip.width - width) / 2)
                            spacing: 8

                            Repeater {
                                model: window.entries

                                WidgetCell {
                                    required property string modelData

                                    plugin: HomeGrid.plugin(modelData)
                                    name: scene.widgetName(modelData)
                                    description: ""
                                    kind: HomeGrid.kind(modelData)
                                    span: HomeGrid.span(modelData)
                                    cellWidth: window.cellWidth
                                    cellHeight: window.cellHeight
                                    current: modelData === window.current
                                    draggable: false
                                    showAdd: scene.selected === modelData
                                    onTapped: {
                                        if (modelData === window.current) {
                                            scene.selected = "";
                                        } else if (scene.same(modelData)) {
                                            scene.selected = "";
                                            window.applied(modelData);
                                        } else {
                                            scene.selected = modelData;
                                        }
                                    }
                                    onAddRequested: {
                                        window.adding(modelData);
                                        explorer.addApplet(plugin);
                                        scene.hide();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
