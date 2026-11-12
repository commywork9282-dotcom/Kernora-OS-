/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmaCore.Dialog {
    id: window

    required property QtObject launcher
    property var appsModel: null

    readonly property string screenName: launcher ? launcher.Screen.name : ""
    function computeArea(): rect {
        const containment = Plasmoid.containment;
        if (!containment) {
            return Qt.rect(0, 0, 1280, 800);
        }
        return Qt.rect(containment.screenGeometry.x + containment.availableScreenRect.x,
                       containment.screenGeometry.y + containment.availableScreenRect.y,
                       containment.availableScreenRect.width,
                       containment.availableScreenRect.height);
    }
    readonly property rect availableRect: computeArea()
    property rect area: availableRect
    onAvailableRectChanged: area = availableRect
    readonly property bool shown: visible && !closing

    property bool closing: false
    property bool dragging: false
    property real hiddenAt: 0
    property bool shownAtPress: false

    type: PlasmaCore.Dialog.AppletPopup
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: true
    flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
    visible: false

    x: area.x
    y: area.y

    function open(byKey: bool): void {
        area = computeArea();
        closing = false;
        dragging = false;
        visible = true;
        requestActivate();
        scene.enter(byKey);
    }

    function dismiss(): void {
        if (!visible || closing) {
            return;
        }
        closing = true;
        scene.leave();
    }

    function toggle(byKey: bool): void {
        if (shown) {
            dismiss();
        } else {
            open(byKey);
        }
    }

    function notePress(): void {
        shownAtPress = shown || Date.now() - hiddenAt < 400;
    }

    function clickToggle(): void {
        if (shownAtPress) {
            dismiss();
        } else {
            open(false);
        }
        shownAtPress = false;
    }

    onVisibleChanged: {
        if (!visible) {
            if (!closing && !dragging) {
                hiddenAt = Date.now();
            }
            closing = false;
            dragging = false;
            scene.finish();
        }
    }

    mainItem: DrawerScene {
        id: scene

        width: window.dragging ? 1 : window.area.width
        height: window.dragging ? 1 : window.area.height
        areaWidth: window.area.width
        areaHeight: window.area.height
        launcher: window.launcher
        appsModel: window.appsModel
        screenName: window.screenName
        windowShown: window.visible

        onRequestClose: window.dismiss()
        onLeftScreen: window.visible = false
        onDragStarted: window.dragging = true
        onDragFinished: window.visible = false
    }
}
