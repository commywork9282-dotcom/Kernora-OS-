/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window
import org.kernora.bartint
import "m3"

FocusScope {
    id: scene

    property QtObject launcher: null
    property var appsModel: null
    property string screenName
    property bool windowShown: false
    property real reveal: 0
    property real areaWidth: width
    property real areaHeight: height

    readonly property real scrimOpacity: M3.dark ? 0.55 : 0
    property QtObject blur: null
    readonly property bool frosted: blur !== null && blur.available

    signal requestClose()
    signal leftScreen()
    signal dragStarted()
    signal dragFinished()

    Component.onCompleted: {
        try {
            blur = Qt.createQmlObject("import org.kernora.shell\nWindowBlur { radius: 28 }", scene, "DrawerBlur");
        } catch (error) {
            blur = null;
        }
        if (blur) {
            blur.window = Qt.binding(() => scene.Window.window);
            blur.rect = Qt.binding(() => Qt.rect(sheet.x, sheet.y, sheet.width, sheet.height));
            blur.enabled = Qt.binding(() => scene.windowShown && scene.reveal > 0.02 && scene.width > 1);
        }
    }

    function enter(byKey: bool): void {
        leaving.stop();
        sheet.prepare(byKey);
        entering.from = reveal;
        entering.restart();
    }

    function leave(): void {
        entering.stop();
        leaving.from = reveal;
        leaving.restart();
    }

    function finish(): void {
        entering.stop();
        leaving.stop();
        reveal = 0;
        sheet.dropDrag();
    }

    Binding {
        target: LauncherState
        property: "screen"
        value: scene.screenName
        when: scene.windowShown
    }
    Binding {
        target: LauncherState
        property: "scrim"
        value: scene.scrimOpacity * scene.reveal
        when: scene.windowShown
    }

    NumberAnimation {
        id: entering
        target: scene
        property: "reveal"
        to: 1
        duration: M3.durationMedium4
        easing.type: Easing.Bezier
        easing.bezierCurve: M3.easingEmphasizedDecelerate
    }
    NumberAnimation {
        id: leaving
        target: scene
        property: "reveal"
        to: 0
        duration: M3.durationShort4
        easing.type: Easing.Bezier
        easing.bezierCurve: M3.easingEmphasizedAccelerate
        onFinished: scene.leftScreen()
    }

    Keys.onEscapePressed: scene.requestClose()

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: scene.scrimOpacity * scene.reveal
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: scene.requestClose()
        onWheel: wheel => wheel.accepted = true
    }

    DrawerSheet {
        id: sheet

        height: Math.min(760, Math.round(scene.areaHeight * 0.8))
        width: Math.min(scene.areaWidth - 32, Math.round(height / 1.19))
        x: Math.round((scene.areaWidth - width) / 2)
        y: scene.areaHeight - height - 12 + Math.round((1 - scene.reveal) * 56)
        opacity: Math.min(1, scene.reveal * 1.6)
        focus: true

        launcher: scene.launcher
        appsModel: scene.appsModel
        reveal: scene.reveal
        frosted: scene.frosted

        onRequestClose: scene.requestClose()
        onDragStarted: {
            entering.stop();
            leaving.stop();
            scene.reveal = 0;
            scene.dragStarted();
        }
        onDragFinished: scene.dragFinished()
    }
}
