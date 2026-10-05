/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Window
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import org.kde.notification

AppWindow {
    id: app

    width: 560
    height: 500
    minimumWidth: 400
    minimumHeight: 380
    color: M3.surfaceContainer
    visible: false
    title: i18n("Screenshot")

    property url frozen
    property int frozenWidth: 0
    property int frozenHeight: 0
    property url saved
    property string mode: "region"

    function start(): void {
        app.hide();
        startTimer.restart();
    }
    Timer {
        id: startTimer
        interval: 250
        onTriggered: Screenshot.captureActiveScreen(false, (ok, url, width, height) => {
            if (!ok) {
                app.fail(url);
                return;
            }
            app.frozen = url;
            app.frozenWidth = width;
            app.frozenHeight = height;
            overlay.open();
        })
    }

    function fail(message: string): void {
        saved = "";
        failure.text = message || i18n("The screen could not be captured.");
        app.show();
        app.raise();
    }

    function finish(url: url): void {
        overlay.hide();
        saved = Screenshot.save(url);
        if (String(saved).length === 0) {
            fail(i18n("The screenshot could not be saved."));
            return;
        }
        Screenshot.copyToClipboard(saved);
        shutterSound.sendEvent();
        failure.text = "";
        app.show();
        app.raise();
        app.requestActivate();
    }

    function capture(): void {
        if (mode === "screen") {
            finish(frozen);
        } else if (mode === "window") {
            overlay.hide();
            Screenshot.captureInteractive(0, false, (ok, url) => ok ? app.finish(url) : app.fail(""));
        } else if (selection.valid) {
            const scale = frozenWidth / overlay.width;
            finish(Screenshot.crop(frozen, Math.round(selection.x * scale), Math.round(selection.y * scale),
                                   Math.round(selection.width * scale), Math.round(selection.height * scale)));
        }
    }

    function handleArguments(args: var): void {
        start();
    }
    Component.onCompleted: start()

    Window {
        id: overlay

        function open(): void {
            selection.touched = false;
            showFullScreen();
            raise();
            requestActivate();
            selection.reset();
        }
        onWidthChanged: {
            if (!selection.touched) {
                selection.reset();
            }
        }
        onHeightChanged: {
            if (!selection.touched) {
                selection.reset();
            }
        }

        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
        color: "black"
        title: i18n("Take a screenshot")

        onClosing: close => {
            if (!app.visible) {
                Qt.quit();
            }
        }

        Image {
            anchors.fill: parent
            source: app.frozen
            fillMode: Image.Stretch
            cache: false
        }

        Item {
            id: selection

            property real startX: 0
            property real startY: 0
            property bool touched: false
            readonly property bool valid: width >= 4 && height >= 4
            visible: app.mode === "region"

            function reset(): void {
                width = overlay.width * 0.5;
                height = overlay.height * 0.5;
                x = overlay.width * 0.25;
                y = overlay.height * 0.25;
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 2
                border.color: M3.primary
            }
            Repeater {
                model: [[0, 0], [1, 0], [0, 1], [1, 1]]
                delegate: Rectangle {
                    required property var modelData
                    x: modelData[0] * selection.width - width / 2
                    y: modelData[1] * selection.height - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: M3.primary
                    border.width: 2
                    border.color: M3.primaryContent
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: 8
                visible: selection.valid
                width: sizeLabel.implicitWidth + 20
                height: 28
                radius: M3.classic ? M3.cornerTooltip : 14
                color: M3.inverseSurface
                Text {
                    id: sizeLabel
                    anchors.centerIn: parent
                    color: M3.inverseOnSurface
                    font: M3.labelMedium
                    text: Math.round(selection.width * app.frozenWidth / Math.max(1, overlay.width)) + " × "
                        + Math.round(selection.height * app.frozenWidth / Math.max(1, overlay.width))
                }
            }
        }
        Rectangle { visible: selection.visible; color: "#99000000"; x: 0; y: 0; width: parent.width; height: selection.y }
        Rectangle { visible: selection.visible; color: "#99000000"; x: 0; y: selection.y + selection.height; width: parent.width; height: parent.height - y }
        Rectangle { visible: selection.visible; color: "#99000000"; x: 0; y: selection.y; width: selection.x; height: selection.height }
        Rectangle { visible: selection.visible; color: "#99000000"; x: selection.x + selection.width; y: selection.y; width: parent.width - x; height: selection.height }
        Rectangle { visible: app.mode === "window"; anchors.fill: parent; color: "#66000000" }

        MouseArea {
            anchors.fill: parent
            enabled: app.mode === "region"
            cursorShape: Qt.CrossCursor
            property bool moving: false
            property point grab
            onPressed: mouse => {
                selection.touched = true;
                const inside = mouse.x > selection.x && mouse.x < selection.x + selection.width
                    && mouse.y > selection.y && mouse.y < selection.y + selection.height;
                moving = inside;
                if (inside) {
                    grab = Qt.point(mouse.x - selection.x, mouse.y - selection.y);
                } else {
                    selection.startX = mouse.x;
                    selection.startY = mouse.y;
                    selection.x = mouse.x;
                    selection.y = mouse.y;
                    selection.width = 0;
                    selection.height = 0;
                }
            }
            onPositionChanged: mouse => {
                if (moving) {
                    selection.x = Math.max(0, Math.min(overlay.width - selection.width, mouse.x - grab.x));
                    selection.y = Math.max(0, Math.min(overlay.height - selection.height, mouse.y - grab.y));
                } else {
                    const x = Math.max(0, Math.min(overlay.width, mouse.x));
                    const y = Math.max(0, Math.min(overlay.height, mouse.y));
                    selection.x = Math.min(selection.startX, x);
                    selection.y = Math.min(selection.startY, y);
                    selection.width = Math.abs(x - selection.startX);
                    selection.height = Math.abs(y - selection.startY);
                }
            }
            onDoubleClicked: app.capture()
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            width: toolbar.implicitWidth + 24
            height: 72
            radius: M3.classic ? M3.cornerCard : 36
            color: M3.surfaceContainerHigh

            RowLayout {
                id: toolbar
                anchors.centerIn: parent
                spacing: 12

                SegmentedButtons {
                    implicitWidth: 380
                    options: [
                        { value: "region", label: i18n("Area"), icon: "kernora-select-region" },
                        { value: "screen", label: i18n("Screen"), icon: "video-display" },
                        { value: "window", label: i18n("Window"), icon: "kernora-select-window" }
                    ]
                    currentValue: app.mode
                    onSelected: value => app.mode = value
                }
                QQC2.AbstractButton {
                    id: shutter
                    implicitWidth: 56
                    implicitHeight: 56
                    enabled: app.mode !== "region" || selection.valid
                    opacity: enabled ? 1 : 0.38
                    Accessible.name: i18n("Take the screenshot")
                    QQC2.ToolTip.text: i18n("Take the screenshot (Enter)")
                    QQC2.ToolTip.visible: hovered
                    background: Rectangle {
                        radius: shutter.pressed && !M3.classic ? 16 : 28
                        color: M3.primary
                        Behavior on radius { NumberAnimation { duration: M3.durationShort4 } }
                        MStateLayer {
                            radius: parent.radius
                            color: M3.primaryContent
                            hovered: shutter.hovered
                            pressed: shutter.pressed
                        }
                        MIcon {
                            anchors.centerIn: parent
                            size: 26
                            source: "camera-photo"
                            color: M3.primaryContent
                        }
                    }
                    onClicked: app.capture()
                }
                IconButton {
                    iconName: "window-close"
                    text: i18n("Cancel (Esc)")
                    onClicked: overlay.close()
                }
            }
        }

        Shortcut { sequences: ["Escape"]; onActivated: overlay.close() }
        Shortcut { sequences: ["Return", "Enter", "Space"]; onActivated: app.capture() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        RoundedClip {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: M3.classic ? M3.cornerImage : 24
            visible: String(app.saved).length > 0
            Rectangle { anchors.fill: parent; color: M3.surfaceContainerHighest }
            Image {
                anchors.fill: parent
                anchors.margins: 8
                source: app.saved
                fillMode: Image.PreserveAspectFit
                cache: false
                asynchronous: true
            }
        }
        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: failure.text.length > 0
            icon: "dialog-error"
            title: i18n("No screenshot")
            text: failure.text
        }
        Text { id: failure; visible: false }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: String(app.saved).length > 0
            MText { role: "titleMedium"; text: i18n("Saved and copied") }
            MText {
                Layout.fillWidth: true
                role: "bodySmall"
                color: M3.surfaceVariantContent
                text: decodeURIComponent(String(app.saved).replace(/^file:\/\//, ""))
                elide: Text.ElideMiddle
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            QQC2.Button {
                text: i18n("Take another")
                icon.name: "camera-photo"
                highlighted: true
                onClicked: app.start()
            }
            Item { Layout.fillWidth: true }
            IconButton {
                visible: String(app.saved).length > 0
                iconName: "document-open"
                text: i18n("Open")
                onClicked: Process.openUrl(app.saved)
            }
            IconButton {
                visible: String(app.saved).length > 0
                iconName: "system-file-manager"
                text: i18n("Show in Files")
                onClicked: Process.launchApplication("org.kernora.files.desktop", [app.saved])
            }
            IconButton {
                visible: String(app.saved).length > 0
                iconName: "user-trash"
                text: i18n("Delete")
                onClicked: {
                    Screenshot.discard(app.saved);
                    app.saved = "";
                    Qt.quit();
                }
            }
        }
    }

    Notification {
        id: shutterSound
        componentName: "kernora-screenshot"
        eventId: "captured"
        title: i18n("Screenshot taken")
        iconName: "org.kernora.screenshot"
    }
}
