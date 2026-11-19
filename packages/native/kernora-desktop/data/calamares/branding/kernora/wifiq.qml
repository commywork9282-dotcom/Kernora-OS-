/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.ui 1.0

import QtQuick
import QtQuick.Controls
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kernora.m3

PixelPage {
    id: page

    icon: "wifi"
    title: qsTr("Connect to Wi‑Fi")
    description: qsTr("Kernora will get the latest updates and set the time. You can skip this and connect later.")
    secondaryText: page.online ? "" : qsTr("Skip")
    secondaryAction: () => ViewManager.next()

    property var wireless: []
    property var wired: []
    property string asking: ""

    readonly property bool wifiAvailable: devices.wirelessDeviceAvailable && enabledConnections.wirelessHwEnabled
    readonly property bool online: wired.some(row => row.state === PlasmaNM.Enums.Activated)
        || wireless.some(row => row.state === PlasmaNM.Enums.Activated)

    PlasmaNM.EnabledConnections {
        id: enabledConnections
    }

    PlasmaNM.AvailableDevices {
        id: devices
    }

    PlasmaNM.Handler {
        id: handler
    }

    PlasmaNM.NetworkModel {
        id: networkModel
    }

    PlasmaNM.AppletProxyModel {
        id: connections
        sourceModel: networkModel
    }

    Timer {
        interval: 10000
        repeat: true
        running: page.visible && enabledConnections.wirelessEnabled
        triggeredOnStart: true
        onTriggered: handler.requestScan("")
    }

    Instantiator {
        id: rows

        model: connections
        delegate: QtObject {
            required property var model
            readonly property int type: model.Type
            readonly property string name: model.ItemUniqueName
            readonly property int state: model.ConnectionState
            readonly property string uuid: model.Uuid
            readonly property string connectionPath: model.ConnectionPath
            readonly property string devicePath: model.DevicePath
            readonly property string specificPath: model.SpecificPath
            readonly property int signal: model.Signal
            readonly property int securityType: model.SecurityType
        }
        onObjectAdded: rebuild.restart()
        onObjectRemoved: rebuild.restart()
    }

    Connections {
        target: connections
        function onDataChanged() {
            rebuild.restart();
        }
        function onLayoutChanged() {
            rebuild.restart();
        }
    }

    Timer {
        id: rebuild

        interval: 150
        onTriggered: {
            const wireless = [];
            const wired = [];
            for (let i = 0; i < rows.count; ++i) {
                const row = rows.objectAt(i);
                if (!row) {
                    continue;
                }
                const copy = { type: row.type, name: row.name, state: row.state, uuid: row.uuid, connectionPath: row.connectionPath,
                    devicePath: row.devicePath, specificPath: row.specificPath, signal: row.signal, securityType: row.securityType };
                if (row.type === PlasmaNM.Enums.Wireless) {
                    wireless.push(copy);
                } else if (row.type === PlasmaNM.Enums.Wired && row.uuid.length > 0) {
                    wired.push(copy);
                }
            }
            const rank = row => row.state === PlasmaNM.Enums.Activated ? 0 : row.state === PlasmaNM.Enums.Activating ? 1 : row.uuid.length > 0 ? 2 : 3;
            wireless.sort((a, b) => rank(a) - rank(b) || b.signal - a.signal);
            wired.sort((a, b) => rank(a) - rank(b));
            page.wireless = wireless.slice(0, 12);
            page.wired = wired.filter(row => row.state === PlasmaNM.Enums.Activated || row.state === PlasmaNM.Enums.Activating).slice(0, 1);
        }
    }

    function secured(row: var): bool {
        return row.securityType !== PlasmaNM.Enums.NoneSecurity && row.securityType !== PlasmaNM.Enums.UnknownSecurity;
    }

    function needsPassword(row: var): bool {
        return [PlasmaNM.Enums.StaticWep, PlasmaNM.Enums.WpaPsk, PlasmaNM.Enums.Wpa2Psk, PlasmaNM.Enums.SAE].includes(row.securityType);
    }

    function stateText(row: var): string {
        switch (row.state) {
        case PlasmaNM.Enums.Activated:
            return qsTr("Connected");
        case PlasmaNM.Enums.Activating:
            return qsTr("Connecting…");
        }
        if (row.uuid.length > 0) {
            return qsTr("Saved");
        }
        return secured(row) ? "" : qsTr("Open network");
    }

    function signalSymbol(row: var): string {
        if (row.type === PlasmaNM.Enums.Wired) {
            return "lan";
        }
        return row.signal >= 75 ? "signal_wifi_4_bar" : row.signal >= 50 ? "network_wifi_3_bar" : row.signal >= 25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }

    function activate(row: var): void {
        if (row.state === PlasmaNM.Enums.Activated || row.state === PlasmaNM.Enums.Activating) {
            return;
        }
        if (row.uuid.length > 0) {
            handler.activateConnection(row.connectionPath, row.devicePath, row.specificPath);
        } else if (needsPassword(row)) {
            page.asking = row.name;
        } else {
            handler.addAndActivateConnection(row.devicePath, row.specificPath);
        }
    }

    Column {
        anchors.fill: parent
        spacing: 2

        Rectangle {
            visible: !page.wifiAvailable && page.wired.length === 0
            width: parent.width
            height: noWifi.implicitHeight + 40
            radius: 24
            color: M3.surfaceContainerHigh

            MText {
                id: noWifi
                x: 24
                y: 20
                width: parent.width - 48
                role: "bodyLarge"
                text: qsTr("This computer has no Wi‑Fi. Connect a network cable or skip this step.")
                color: M3.surfaceVariantContent
                wrapMode: Text.Wrap
            }
        }

        Repeater {
            model: page.wired.concat(page.wireless)

            Item {
                id: row

                required property int index
                required property var modelData
                readonly property bool first: index === 0
                readonly property bool last: index === page.wired.length + page.wireless.length - 1
                readonly property bool asking: page.asking.length > 0 && page.asking === modelData.name
                readonly property bool selected: modelData.state === PlasmaNM.Enums.Activated

                width: parent.width
                height: asking ? 72 + 76 : 72

                Rectangle {
                    anchors.fill: parent
                    color: row.selected ? M3.secondaryContainer : M3.surfaceContainerHigh
                    topLeftRadius: row.first ? 24 : 6
                    topRightRadius: row.first ? 24 : 6
                    bottomLeftRadius: row.last ? 24 : 6
                    bottomRightRadius: row.last ? 24 : 6
                }

                MIcon {
                    x: 20
                    y: 24
                    size: 24
                    source: page.symbol(page.signalSymbol(row.modelData))
                    color: row.selected ? M3.secondaryContainerContent : M3.surfaceVariantContent
                }

                Column {
                    x: 60
                    y: (72 - height) / 2
                    width: parent.width - 120

                    MText {
                        width: parent.width
                        role: "bodyLarge"
                        text: row.modelData.type === PlasmaNM.Enums.Wired ? qsTr("Network cable") : row.modelData.name
                        elide: Text.ElideRight
                        color: row.selected ? M3.secondaryContainerContent : M3.surfaceContent
                    }

                    MText {
                        visible: text.length > 0
                        width: parent.width
                        role: "bodyMedium"
                        text: page.stateText(row.modelData)
                        color: row.selected ? M3.secondaryContainerContent : M3.surfaceVariantContent
                    }
                }

                MIcon {
                    visible: row.selected || page.secured(row.modelData)
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    y: 26
                    size: 20
                    source: page.symbol(row.selected ? "check" : "lock")
                    color: row.selected ? M3.secondaryContainerContent : M3.surfaceVariantContent
                }

                MStateLayer {
                    width: parent.width
                    height: 72
                    radius: 6
                    color: M3.surfaceContent
                    hovered: rowMouse.containsMouse
                    pressed: rowMouse.pressed
                }

                MouseArea {
                    id: rowMouse
                    width: parent.width
                    height: 72
                    enabled: row.modelData.type !== PlasmaNM.Enums.Wired
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.activate(row.modelData)
                }

                Row {
                    visible: row.asking
                    x: 20
                    y: 72
                    width: parent.width - 40
                    height: 64
                    spacing: 12

                    SetupField {
                        id: secret
                        width: parent.width - join.width - 12
                        first: true
                        last: true
                        symbol: "password"
                        label: qsTr("Password")
                        password: true
                        onAccepted: if (join.enabled) join.clicked()
                        onVisibleChanged: if (visible) forceActiveFocus()
                    }

                    MButton {
                        id: join
                        anchors.verticalCenter: secret.verticalCenter
                        height: 56
                        variant: "filled"
                        text: qsTr("Connect")
                        enabled: secret.text.length >= 8 || (row.modelData.securityType === PlasmaNM.Enums.StaticWep && secret.text.length >= 5)
                        onClicked: {
                            handler.addAndActivateConnection(row.modelData.devicePath, row.modelData.specificPath, secret.text);
                            secret.text = "";
                            page.asking = "";
                        }
                    }
                }
            }
        }
    }

    function onActivate() {
        handler.requestScan("");
    }

    function onLeave() {
        page.asking = "";
    }
}
