/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

AppWindow {
    id: app

    width: 460
    height: 740
    minimumWidth: 400
    minimumHeight: 600
    color: M3.surface
    visible: true
    title: i18n("Quick Share")

    property string tab: "receive"
    property var files: []
    property bool fromFiles: false
    property bool madeVisible: false
    property bool triedVisible: false
    property bool shown: false

    readonly property bool on: QuickShare.enabled
    readonly property string mode: QuickShare.visibility
    readonly property var devices: QuickShare.devices
    property var target: null
    property string transferId: ""
    readonly property var transfer: transferId.length > 0 ? (QuickShare.transfers.find(t => t.id === transferId) || null) : null
    readonly property bool confirming: target !== null && transferId.length > 0
    readonly property string phase: transfer ? transfer.phase : (confirming ? "connecting" : "")
    readonly property bool failed: ["rejected", "failed"].includes(phase)
    readonly property bool started: ["transferring", "finished"].includes(phase)

    property var watched: []
    property var dismissed: []
    readonly property var incoming: {
        const fresh = QuickShare.transfers.filter(t => !t.outgoing && app.watched.includes(t.id) && !app.dismissed.includes(t.id)
                                                       && ["waiting", "transferring", "finished"].includes(t.phase));
        return fresh.length > 0 ? fresh[fresh.length - 1] : null;
    }

    function watch(): void {
        const live = QuickShare.transfers.filter(t => !t.outgoing && ["waiting", "transferring"].includes(t.phase)
                                                      && !app.watched.includes(t.id)).map(t => t.id);
        if (live.length > 0) {
            app.watched = app.watched.concat(live);
        }
    }

    readonly property string firstName: files.length > 0 ? fileName(files[0]) : ""
    readonly property bool singleImage: files.length === 1 && /\.(png|jpe?g|gif|webp|bmp|avif)$/i.test(firstName)
    readonly property string shapeOf: M3.classic ? "circle" : "cookie9"

    function fileName(path: string): string {
        const parts = String(path).split("/");
        return decodeURIComponent(parts[parts.length - 1] || path);
    }

    function deviceIcon(kind: string): string {
        return kind === "computer" ? "kernora-laptop" : (kind === "tablet" ? "kernora-tablet" : "phone");
    }

    function remaining(seconds: int): string {
        return seconds > 60 ? i18n("%1 min", Math.ceil(seconds / 60)) : i18n("%1 sec", Math.max(1, seconds));
    }

    function visibilityText(): string {
        if (!app.on) {
            return i18n("Quick Share is off");
        }
        if (app.mode === "everyone") {
            return i18n("Visible to everyone");
        }
        if (app.mode === "temporary") {
            return i18n("Temporarily visible to everyone");
        }
        return i18n("Hidden");
    }

    function visibilityDetail(): string {
        return app.on && app.mode === "temporary" ? i18n("%1 left", app.remaining(QuickShare.visibleFor)) : "";
    }

    function revealHero(): void {
        const flick = receivePage.contentItem;
        flick.contentY = Math.max(0, flick.contentHeight - flick.height);
    }

    function visibilityIcon(): string {
        return app.mode === "everyone" ? "kernora-everyone" : (app.mode === "temporary" ? "kernora-timer" : "view-hidden");
    }

    function what(transfer: var): string {
        if (!transfer) {
            return "";
        }
        switch (transfer.kind) {
        case "url":
            return i18n("a link");
        case "text":
            return i18n("text");
        case "wifi":
            return i18n("a Wi-Fi network");
        default:
            return transfer.files.length === 1 ? transfer.files[0] : i18np("%1 file", "%1 files", transfer.files.length);
        }
    }

    function progress(transfer: var): real {
        return transfer && transfer.total > 0 ? Math.min(1, transfer.done / transfer.total) : 0;
    }

    function handleArguments(args: var): void {
        const picked = args.filter(argument => !String(argument).startsWith("--"));
        if (picked.length === 0) {
            return;
        }
        app.files = picked;
        app.fromFiles = !app.shown;
        app.target = null;
        app.transferId = "";
        app.tab = "send";
    }

    function next(): void {
        if (!app.target) {
            return;
        }
        app.transferId = "pending";
        QuickShare.send(app.target.id, app.files, id => {
            if (id.length === 0) {
                app.transferId = "";
                app.showMessage(i18n("Could not send to %1", app.target.name), "", null);
                return;
            }
            app.transferId = id;
        });
    }

    function stopSending(): void {
        if (app.transfer && !app.failed && app.phase !== "finished") {
            QuickShare.cancel(app.transfer.id);
        }
        app.transferId = "";
        app.target = null;
    }

    function startOver(): void {
        app.stopSending();
        app.files = [];
        app.fromFiles = false;
    }

    function becomeVisible(): void {
        if (app.triedVisible || app.tab !== "receive" || !QuickShare.available || !app.on || app.mode.length === 0) {
            return;
        }
        app.triedVisible = true;
        if (app.mode === "hidden") {
            QuickShare.setVisibility("temporary");
            app.madeVisible = true;
        }
    }

    onTabChanged: {
        becomeVisible();
        if (tab === "send") {
            QuickShare.startDiscovery();
        } else if (!confirming) {
            QuickShare.stopDiscovery();
        }
    }

    onPhaseChanged: {
        if (fromFiles && (phase === "transferring" || phase === "finished" || phase === "cancelled")) {
            app.close();
        }
    }

    onOnChanged: becomeVisible()
    onModeChanged: becomeVisible()

    Component.onCompleted: {
        watch();
        handleArguments(startArguments);
        if (tab === "receive") {
            becomeVisible();
        }
        shown = true;
    }

    onClosing: {
        QuickShare.stopDiscovery();
        if (madeVisible && mode === "temporary") {
            QuickShare.setVisibility("hidden");
        }
    }

    readonly property bool available: QuickShare.available

    onAvailableChanged: {
        if (available) {
            becomeVisible();
            if (tab === "send") {
                QuickShare.startDiscovery();
            }
        }
    }

    Connections {
        target: QuickShare
        function onChanged(): void {
            app.watch();
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: app.tab === "send" && !app.confirming
        onTriggered: QuickShare.startDiscovery()
    }

    component Card: Rectangle {
        default property alias content: body.data
        property int padding: 20
        implicitHeight: body.implicitHeight + padding * 2
        radius: M3.radius("card", height) + (M3.classic ? 0 : 4)
        color: M3.surfaceContainer

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: parent.padding
            spacing: 12
        }
    }

    component Glyph: Item {
        id: glyph
        property string shape: app.shapeOf
        property color color: M3.primaryContainer
        property color ink: M3.primaryContainerContent
        property string icon: "kernora-quickshare"
        property real iconScale: 0.45
        property bool spinning: false

        MShape {
            id: backdrop
            anchors.fill: parent
            shape: glyph.shape
            color: glyph.color
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 24000
                loops: Animation.Infinite
                running: glyph.spinning && glyph.visible && M3.motionScale > 0 && !M3.classic
            }
        }
        MIcon {
            anchors.centerIn: parent
            size: Math.round(glyph.width * glyph.iconScale)
            source: glyph.icon
            color: glyph.ink
        }
    }

    component Pulse: Item {
        id: pulse
        property bool running: true
        opacity: running ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: M3.durationMedium2 } }
        Repeater {
            model: 3
            delegate: Rectangle {
                id: ring
                required property int index
                anchors.centerIn: parent
                width: pulse.width
                height: width
                radius: width / 2
                color: M3.withAlpha(M3.primary, 0.12)
                opacity: 0
                scale: 0.5
                SequentialAnimation {
                    running: pulse.running && pulse.visible && M3.motionScale > 0
                    loops: Animation.Infinite
                    PauseAnimation { duration: ring.index * 900 }
                    ParallelAnimation {
                        NumberAnimation { target: ring; property: "scale"; from: 0.5; to: 1; duration: 2700; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ring; property: "opacity"; from: 1; to: 0; duration: 2700; easing.type: Easing.InQuad }
                    }
                    PauseAnimation { duration: (2 - ring.index) * 900 }
                }
            }
        }
    }

    component Avatar: Item {
        id: avatar
        property string icon
        property string badge
        property string shape: M3.classic ? "circle" : "cookie12"
        property color color: M3.secondaryContainer
        property color ink: M3.secondaryContainerContent
        implicitWidth: 56
        implicitHeight: 56

        MShape {
            anchors.fill: parent
            shape: avatar.shape
            color: avatar.color
        }
        MIcon {
            anchors.centerIn: parent
            size: Math.round(avatar.width * 0.46)
            source: avatar.icon
            color: avatar.ink
        }
        Rectangle {
            visible: avatar.badge.length > 0
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -4
            anchors.bottomMargin: -4
            width: 26
            height: 26
            radius: 13
            color: M3.tertiary
            border.width: 2
            border.color: M3.surfaceContainer
            MIcon {
                anchors.centerIn: parent
                size: 15
                source: avatar.badge
                color: M3.tertiaryContent
            }
        }
    }

    component Preview: Rectangle {
        implicitWidth: 132
        implicitHeight: 148
        radius: M3.classic ? M3.cornerCard : 28
        color: M3.surfaceContainerHighest

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RoundedClip {
                    anchors.fill: parent
                    radius: 16
                    visible: app.singleImage && thumbnail.status === Image.Ready
                    Image {
                        id: thumbnail
                        anchors.fill: parent
                        source: app.singleImage ? app.files[0] : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 256
                        asynchronous: true
                    }
                }
                Avatar {
                    anchors.centerIn: parent
                    visible: !(app.singleImage && thumbnail.status === Image.Ready)
                    width: 64
                    height: 64
                    shape: M3.classic ? "circle" : "clover4"
                    icon: app.files.length === 1 ? Files.iconName(app.files[0]) : "folder-documents"
                    color: M3.tertiaryContainer
                    ink: M3.tertiaryContainerContent
                }
            }
            MText {
                Layout.fillWidth: true
                role: "labelLarge"
                color: M3.surfaceContent
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                text: app.files.length === 1 ? app.firstName : i18n("%1 Files", app.files.length)
            }
        }
    }

    component DeviceRow: Rectangle {
        id: row
        required property var device
        required property int index
        required property int count
        readonly property bool selected: app.target !== null && app.target.id === device.id
        readonly property real outer: M3.classic ? M3.cornerCard : 24
        readonly property real inner: M3.classic ? M3.cornerCard : 6
        signal picked()

        implicitHeight: 72
        topLeftRadius: index === 0 ? outer : inner
        topRightRadius: topLeftRadius
        bottomLeftRadius: index === count - 1 ? outer : inner
        bottomRightRadius: bottomLeftRadius
        color: selected ? M3.primaryContainer : M3.surfaceContainer
        Behavior on color { ColorAnimation { duration: M3.durationMedium2 } }

        MStateLayer {
            anchors.fill: parent
            topLeftRadius: row.topLeftRadius
            topRightRadius: row.topRightRadius
            bottomLeftRadius: row.bottomLeftRadius
            bottomRightRadius: row.bottomRightRadius
            color: row.selected ? M3.primaryContainerContent : M3.surfaceContent
            hovered: rowMouse.containsMouse
            pressed: rowMouse.pressed
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 20
            spacing: 14

            Avatar {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                icon: app.deviceIcon(row.device.kind)
                color: row.selected ? M3.primary : M3.secondaryContainer
                ink: row.selected ? M3.primaryContent : M3.secondaryContainerContent
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                MText {
                    Layout.fillWidth: true
                    role: row.selected ? "titleMediumEmphasized" : "titleMedium"
                    color: row.selected ? M3.primaryContainerContent : M3.surfaceContent
                    text: row.device.name
                    elide: Text.ElideRight
                }
                MText {
                    Layout.fillWidth: true
                    role: "bodySmall"
                    color: row.selected ? M3.primaryContainerContent : M3.surfaceVariantContent
                    text: row.device.kind === "computer" ? i18n("Computer") : (row.device.kind === "tablet" ? i18n("Tablet") : i18n("Phone"))
                }
            }
            MIcon {
                visible: row.selected
                size: 24
                source: "dialog-positive"
                color: M3.primaryContainerContent
            }
        }
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.picked()
            onDoubleClicked: {
                row.picked();
                app.next();
            }
        }
    }

    component NavItem: Item {
        id: nav
        required property string key
        required property string icon
        required property string iconOn
        required property string label
        readonly property bool current: app.tab === key

        Layout.fillWidth: true
        Layout.fillHeight: true

        MMorph {
            id: morph
            active: nav.current
        }

        Item {
            id: indicator
            anchors.horizontalCenter: parent.horizontalCenter
            y: 12
            width: 64
            height: 32

            Rectangle {
                anchors.centerIn: parent
                height: parent.height
                width: M3.classic ? parent.width : parent.width * (0.5 + 0.5 * morph.value)
                radius: M3.radius("indicator", height)
                color: M3.secondaryContainer
                opacity: M3.classic ? (nav.current ? 1 : 0) : Math.min(1, morph.value * 2)
            }
            MStateLayer {
                anchors.fill: parent
                radius: M3.radius("indicator", height)
                color: M3.surfaceContent
                hovered: navMouse.containsMouse
                pressed: navMouse.pressed
            }
            MIcon {
                anchors.centerIn: parent
                size: 24
                source: nav.current ? nav.iconOn : nav.icon
                color: nav.current ? M3.secondaryContainerContent : M3.surfaceVariantContent
            }
        }
        MText {
            anchors.top: indicator.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            role: nav.current ? "labelMediumEmphasized" : "labelMedium"
            color: nav.current ? M3.surfaceContent : M3.surfaceVariantContent
            text: nav.label
        }
        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.PageTab
            Accessible.name: nav.label
            onClicked: app.tab = nav.key
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 12
            Layout.topMargin: 20
            spacing: 8

            MText {
                Layout.fillWidth: true
                role: "headlineLarge"
                color: M3.surfaceContent
                text: i18n("Quick Share")
                elide: Text.ElideRight
            }
            MIconButton {
                icon: "configure"
                text: i18n("Quick Share settings")
                onClicked: Process.startDetached("kernora-settings", ["quickshare"])
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 16
            currentIndex: app.tab === "send" ? 1 : 0

            QQC2.ScrollView {
                id: receivePage
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: receivePage.availableWidth
                    spacing: 12

                    Card {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16

                        MText {
                            Layout.fillWidth: true
                            role: "labelLarge"
                            color: M3.surfaceVariantContent
                            text: i18n("You'll appear as")
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Avatar {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                icon: "kernora-laptop"
                                badge: app.on ? app.visibilityIcon() : ""
                                color: M3.primaryContainer
                                ink: M3.primaryContainerContent
                            }
                            MText {
                                Layout.fillWidth: true
                                role: "titleLarge"
                                color: M3.surfaceContent
                                text: QuickShare.name
                                elide: Text.ElideRight
                            }
                            MIconButton {
                                icon: "document-edit"
                                text: i18n("Rename")
                                enabled: app.on
                                onClicked: nameDialog.open()
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: app.visibilityDetail().length > 0 ? 64 : 56
                            radius: M3.classic ? M3.cornerCardInner : height / 2
                            color: M3.surfaceContainerHighest
                            opacity: app.on ? 1 : 0.6

                            MStateLayer {
                                anchors.fill: parent
                                radius: parent.radius
                                color: M3.surfaceContent
                                hovered: visibilityMouse.containsMouse
                                pressed: visibilityMouse.pressed
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 14
                                spacing: 12
                                MIcon {
                                    size: 22
                                    source: app.on ? app.visibilityIcon() : "kernora-quickshare"
                                    color: M3.surfaceVariantContent
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    MText {
                                        Layout.fillWidth: true
                                        role: "bodyLarge"
                                        color: M3.surfaceContent
                                        text: app.visibilityText()
                                        elide: Text.ElideRight
                                    }
                                    MText {
                                        Layout.fillWidth: true
                                        role: "bodySmall"
                                        color: M3.surfaceVariantContent
                                        text: app.visibilityDetail()
                                        visible: text.length > 0
                                    }
                                }
                                MIcon {
                                    size: 22
                                    source: "arrow-down"
                                    color: M3.surfaceVariantContent
                                }
                            }
                            MouseArea {
                                id: visibilityMouse
                                anchors.fill: parent
                                enabled: app.on
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: i18n("Device visibility")
                                onClicked: visibilityDialog.open()
                            }
                        }
                    }

                    Card {
                        id: hero
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        padding: 24

                        readonly property var incoming: app.incoming
                        onStageChanged: {
                            if (["asking", "receiving", "received"].includes(stage)) {
                                Qt.callLater(app.revealHero);
                            }
                        }

                        readonly property string stage: !QuickShare.available ? "missing"
                            : !app.on ? "off"
                            : incoming && incoming.phase === "waiting" ? "asking"
                            : incoming && incoming.phase === "transferring" ? "receiving"
                            : incoming && incoming.phase === "finished" ? "received"
                            : app.mode === "hidden" ? "hidden" : "ready"

                        MText {
                            Layout.fillWidth: true
                            role: "labelLarge"
                            color: M3.surfaceVariantContent
                            text: i18n("Sharing with you")
                        }

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            implicitWidth: 164
                            implicitHeight: 164

                            Pulse {
                                anchors.centerIn: parent
                                width: 164
                                height: 164
                                running: hero.stage === "ready" || hero.stage === "asking"
                            }
                            Glyph {
                                anchors.centerIn: parent
                                width: 124
                                height: 124
                                shape: M3.classic ? "circle" : (hero.stage === "received" ? "sunny" : hero.stage === "asking" ? "softBurst" : "cookie9")
                                spinning: hero.stage === "ready"
                                color: hero.stage === "off" || hero.stage === "hidden" || hero.stage === "missing" ? M3.surfaceContainerHighest : M3.primaryContainer
                                ink: hero.stage === "off" || hero.stage === "hidden" || hero.stage === "missing" ? M3.surfaceVariantContent : M3.primaryContainerContent
                                icon: hero.stage === "received" ? "dialog-positive"
                                    : hero.stage === "asking" || hero.stage === "receiving" ? app.deviceIcon(hero.incoming ? hero.incoming.device_kind : "")
                                    : hero.stage === "hidden" ? "view-hidden" : "kernora-quickshare"
                            }
                        }

                        MText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            role: "headlineSmall"
                            color: M3.surfaceContent
                            wrapMode: Text.Wrap
                            text: {
                                switch (hero.stage) {
                                case "missing":
                                    return i18n("Quick Share isn't running");
                                case "off":
                                    return i18n("Quick Share is off");
                                case "asking":
                                    return i18n("%1 wants to share", hero.incoming.device || i18n("A device nearby"));
                                case "receiving":
                                    return i18n("Receiving from %1", hero.incoming.device || i18n("a device nearby"));
                                case "received":
                                    return i18n("Received from %1", hero.incoming.device || i18n("a device nearby"));
                                case "hidden":
                                    return i18n("You're hidden");
                                default:
                                    return i18n("Ready to receive");
                                }
                            }
                        }
                        MText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            role: "bodyMedium"
                            color: M3.surfaceVariantContent
                            wrapMode: Text.Wrap
                            text: {
                                switch (hero.stage) {
                                case "missing":
                                    return i18n("Restart your computer to start Quick Share again.");
                                case "off":
                                    return i18n("Turn it on to share with phones and computers nearby.");
                                case "asking":
                                    return hero.incoming.pin.length > 0
                                        ? i18n("%1 · Secure connection ID: %2", app.what(hero.incoming), hero.incoming.pin)
                                        : app.what(hero.incoming);
                                case "receiving":
                                    return i18n("%1 · %2%", app.what(hero.incoming), Math.round(100 * app.progress(hero.incoming)));
                                case "received":
                                    return app.what(hero.incoming);
                                case "hidden":
                                    return i18n("Nobody nearby can see this computer. Become visible to receive.");
                                default:
                                    return i18n("Keep this computer unlocked. Phones nearby will see %1.", QuickShare.name);
                                }
                            }
                        }

                        MLinearProgress {
                            wavy: false
                            Layout.fillWidth: true
                            Layout.leftMargin: 24
                            Layout.rightMargin: 24
                            visible: hero.stage === "receiving"
                            value: app.progress(hero.incoming)
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 4
                            spacing: 8
                            visible: hero.stage !== "ready" && hero.stage !== "missing"

                            MButton {
                                visible: hero.stage === "asking"
                                variant: "outlined"
                                text: i18n("Decline")
                                onClicked: QuickShare.decline(hero.incoming.id)
                            }
                            MButton {
                                visible: hero.stage === "asking"
                                variant: "filled"
                                text: i18n("Accept")
                                onClicked: QuickShare.accept(hero.incoming.id)
                            }
                            MButton {
                                visible: hero.stage === "receiving"
                                variant: "outlined"
                                text: i18n("Cancel")
                                onClicked: QuickShare.cancel(hero.incoming.id)
                            }
                            MButton {
                                visible: hero.stage === "received" && hero.incoming.kind === "files"
                                variant: "tonal"
                                icon: "folder-open"
                                text: i18n("Open folder")
                                onClicked: Process.openUrl(Qt.resolvedUrl("file://" + QuickShare.folder))
                            }
                            MButton {
                                visible: hero.stage === "received"
                                variant: "text"
                                text: i18n("Done")
                                onClicked: app.dismissed = app.dismissed.concat([hero.incoming.id])
                            }
                            MButton {
                                visible: hero.stage === "off"
                                variant: "filled"
                                text: i18n("Turn on")
                                onClicked: QuickShare.setEnabled(true)
                            }
                            MButton {
                                visible: hero.stage === "hidden"
                                variant: "filled"
                                icon: "kernora-timer"
                                text: i18n("Visible for 10 min")
                                onClicked: QuickShare.setVisibility("temporary")
                            }
                        }
                    }

                    Item {
                        Layout.preferredHeight: 4
                    }
                }
            }

            Item {
                id: sendPage

                DropArea {
                    anchors.fill: parent
                    enabled: !app.confirming
                    onDropped: drop => {
                        if (drop.hasUrls) {
                            app.handleArguments(drop.urls.map(url => String(url)));
                            app.fromFiles = false;
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.bottomMargin: 12
                    spacing: 12
                    visible: app.files.length === 0

                    Item {
                        Layout.fillHeight: true
                    }
                    Glyph {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 160
                        shape: M3.classic ? "circle" : "clover4"
                        icon: "kernora-upload"
                        color: M3.tertiaryContainer
                        ink: M3.tertiaryContainerContent
                        iconScale: 0.4
                    }
                    MText {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        horizontalAlignment: Text.AlignHCenter
                        role: "headlineSmall"
                        color: M3.surfaceContent
                        text: i18n("Share with devices nearby")
                    }
                    MText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        role: "bodyMedium"
                        color: M3.surfaceVariantContent
                        wrapMode: Text.Wrap
                        text: i18n("Choose files or drop them here. You can also right-click a file in Files and pick Send with Quick Share.")
                    }
                    MButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        variant: "filled"
                        icon: "document-open"
                        text: i18n("Choose files")
                        enabled: app.on
                        onClicked: fileDialog.open()
                    }
                    MText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        role: "bodySmall"
                        color: M3.error
                        visible: !app.on
                        text: i18n("Turn on Quick Share first.")
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.bottomMargin: 12
                    spacing: 12
                    visible: app.files.length > 0 && !app.confirming

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 76
                        radius: M3.classic ? M3.cornerCard : 24
                        color: M3.surfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 14

                            RoundedClip {
                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 52
                                radius: 14
                                visible: app.singleImage && smallThumb.status === Image.Ready
                                Image {
                                    id: smallThumb
                                    anchors.fill: parent
                                    source: app.singleImage ? app.files[0] : ""
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: 128
                                    asynchronous: true
                                }
                            }
                            Avatar {
                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 52
                                visible: !(app.singleImage && smallThumb.status === Image.Ready)
                                shape: M3.classic ? "circle" : "clover4"
                                icon: app.files.length === 1 ? Files.iconName(app.files[0]) : "folder-documents"
                                color: M3.tertiaryContainer
                                ink: M3.tertiaryContainerContent
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                MText {
                                    Layout.fillWidth: true
                                    role: "titleMedium"
                                    color: M3.surfaceContent
                                    elide: Text.ElideMiddle
                                    text: app.files.length === 1 ? app.firstName : i18n("%1 Files", app.files.length)
                                }
                                MText {
                                    Layout.fillWidth: true
                                    role: "bodySmall"
                                    color: M3.surfaceVariantContent
                                    text: i18n("Ready to send")
                                }
                            }
                            MButton {
                                variant: "text"
                                text: i18n("Change")
                                onClicked: fileDialog.open()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Layout.leftMargin: 4
                        spacing: 10
                        MText {
                            Layout.fillWidth: true
                            role: "titleSmall"
                            color: M3.primary
                            text: app.on ? i18n("Select the device you'd like to share files with") : i18n("Quick Share is turned off")
                            wrapMode: Text.Wrap
                        }
                        MLoadingIndicator {
                            implicitWidth: 28
                            implicitHeight: 28
                            visible: app.on && app.devices.length > 0
                            running: visible
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: deviceList
                            anchors.fill: parent
                            clip: true
                            spacing: 2
                            model: app.devices
                            visible: app.devices.length > 0
                            delegate: DeviceRow {
                                required property var modelData
                                width: ListView.view.width
                                device: modelData
                                count: deviceList.count
                                onPicked: app.target = modelData
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width
                            spacing: 16
                            visible: app.devices.length === 0

                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 120
                                implicitHeight: 120
                                Pulse {
                                    anchors.fill: parent
                                    running: app.on
                                }
                                MLoadingIndicator {
                                    anchors.centerIn: parent
                                    implicitWidth: 64
                                    implicitHeight: 64
                                    contained: true
                                    visible: app.on
                                    running: visible
                                }
                            }
                            MText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                role: "titleMedium"
                                color: M3.surfaceContent
                                wrapMode: Text.Wrap
                                text: app.on ? i18n("Looking for nearby devices…") : i18n("Turn on Quick Share to see devices nearby.")
                            }
                            MText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                role: "bodySmall"
                                color: M3.surfaceVariantContent
                                wrapMode: Text.Wrap
                                visible: app.on
                                text: i18n("Make sure both devices are unlocked, close together and on the same Wi-Fi. If a phone isn't listed, open Quick Share on it and choose Everyone.")
                            }
                            MButton {
                                Layout.alignment: Qt.AlignHCenter
                                visible: !app.on
                                variant: "tonal"
                                text: i18n("Turn on")
                                onClicked: {
                                    QuickShare.setEnabled(true);
                                    QuickShare.startDiscovery();
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Item {
                            Layout.fillWidth: true
                        }
                        MButton {
                            variant: "outlined"
                            text: i18n("Cancel")
                            onClicked: app.fromFiles ? app.close() : app.startOver()
                        }
                        MButton {
                            enabled: app.target !== null
                            variant: "filled"
                            text: i18n("Next")
                            onClicked: app.next()
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.bottomMargin: 12
                    spacing: 16
                    visible: app.confirming

                    MText {
                        Layout.fillWidth: true
                        role: "headlineSmall"
                        color: M3.surfaceContent
                        wrapMode: Text.Wrap
                        text: app.failed ? i18n("Can't share")
                            : app.phase === "finished" ? i18n("Sent")
                            : app.phase === "transferring" ? i18n("Sending…")
                            : i18n("Share with this device?")
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 20

                        Preview {}

                        MIcon {
                            size: 28
                            source: "go-next"
                            color: M3.surfaceVariantContent
                        }

                        Item {
                            implicitWidth: 132
                            implicitHeight: 148

                            Item {
                                id: targetDevice
                                width: 104
                                height: 104
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top

                                Pulse {
                                    anchors.centerIn: parent
                                    width: 150
                                    height: 150
                                    running: !app.failed && !app.started
                                }
                                MCircularProgress {
                                    anchors.fill: parent
                                    visible: !app.failed && !app.started
                                    running: visible
                                    wavy: false
                                }
                                Avatar {
                                    anchors.centerIn: parent
                                    width: 84
                                    height: 84
                                    shape: M3.classic ? "circle" : (app.failed ? "puffyDiamond" : app.phase === "finished" ? "sunny" : "cookie12")
                                    icon: app.failed ? "dialog-error" : app.phase === "finished" ? "dialog-positive" : app.deviceIcon(app.target ? app.target.kind : "")
                                    color: app.failed ? M3.errorContainer : M3.primaryContainer
                                    ink: app.failed ? M3.errorContainerContent : M3.primaryContainerContent
                                }
                            }
                            MText {
                                anchors.top: targetDevice.bottom
                                anchors.topMargin: 14
                                width: parent.width
                                role: "labelLarge"
                                color: M3.surfaceContent
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: app.target ? app.target.name : ""
                            }
                        }
                    }

                    MText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        role: "titleMedium"
                        color: M3.surfaceContent
                        visible: !app.failed && !app.started && app.transfer !== null && app.transfer.pin.length > 0
                        text: app.transfer ? i18n("Secure connection ID: %1", app.transfer.pin) : ""
                    }
                    MText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        role: "bodyMedium"
                        color: M3.surfaceVariantContent
                        wrapMode: Text.Wrap
                        text: app.failed ? (app.phase === "rejected" ? i18n("The device you're trying to share with did not accept")
                                                                     : i18n("Something went wrong. Please try again."))
                            : app.phase === "finished" ? i18n("%1 got your files.", app.target ? app.target.name : "")
                            : app.phase === "transferring" ? i18n("%1%", Math.round(100 * app.progress(app.transfer)))
                            : app.phase === "waiting" && app.target ? i18n("Waiting for %1 to accept…", app.target.name)
                            : i18n("Connecting…")
                    }
                    MLinearProgress {
                        wavy: false
                        Layout.fillWidth: true
                        Layout.leftMargin: 32
                        Layout.rightMargin: 32
                        visible: app.phase === "transferring"
                        value: app.progress(app.transfer)
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Item {
                            Layout.fillWidth: true
                        }
                        MButton {
                            visible: app.phase !== "finished"
                            variant: "outlined"
                            text: app.failed ? i18n("Close") : i18n("Cancel")
                            onClicked: app.fromFiles ? app.close() : app.stopSending()
                        }
                        MButton {
                            visible: app.failed
                            variant: "filled"
                            text: i18n("Try again")
                            onClicked: {
                                app.transferId = "";
                                app.target = null;
                                QuickShare.startDiscovery();
                            }
                        }
                        MButton {
                            visible: app.phase === "finished"
                            variant: "filled"
                            text: i18n("Done")
                            onClicked: app.startOver()
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 80
            color: M3.surfaceContainer

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                NavItem {
                    key: "receive"
                    icon: "folder-download"
                    iconOn: "kernora-download-on"
                    label: i18n("Receive")
                }
                NavItem {
                    key: "send"
                    icon: "kernora-upload"
                    iconOn: "kernora-upload-on"
                    label: i18n("Send")
                }
            }
        }
    }

    ChoiceDialog {
        id: visibilityDialog
        title: i18n("Device visibility")
        currentValue: app.mode
        options: [
            { value: "everyone", label: i18n("Everyone"), description: i18n("Any device nearby can share with you") },
            { value: "temporary", label: i18n("Everyone for 10 minutes"), description: i18n("Then you're hidden again") },
            { value: "hidden", label: i18n("Hidden"), description: i18n("No one can share with you") }
        ]
        onChosen: value => {
            app.madeVisible = false;
            QuickShare.setVisibility(value);
        }
    }

    Dialog {
        id: nameDialog
        title: i18n("Device name")
        text: i18n("How your device appears to others in Quick Share.")
        acceptText: i18n("Rename")
        acceptEnabled: nameField.text.trim().length > 0 && nameField.text.trim().length <= 60
        onOpened: {
            nameField.text = QuickShare.name;
            nameField.forceActiveFocus();
        }
        onAccepted: QuickShare.setName(nameField.text.trim())
        InputField {
            id: nameField
            Layout.fillWidth: true
            label: i18n("Device name")
            onAccepted: {
                if (nameDialog.acceptEnabled) {
                    nameDialog.accept();
                }
            }
        }
    }

    Dialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose files to send")
        fileMode: Dialogs.FileDialog.OpenFiles
        onAccepted: {
            app.files = selectedFiles.map(url => String(url));
            app.target = null;
            app.transferId = "";
            QuickShare.startDiscovery();
        }
    }
}
