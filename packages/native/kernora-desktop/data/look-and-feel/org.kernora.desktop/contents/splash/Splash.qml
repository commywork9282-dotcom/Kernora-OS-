/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtCore
import QtQuick
import QtQuick.Window
import org.kernora.m3

Rectangle {
    id: root
    color: "#000000"

    property int stage

    Loader {
        id: choice
        source: "file:///var/lib/kernora/greeter/wallpaper.qml"
    }

    readonly property string chosen: choice.status === Loader.Ready ? String(choice.item.plugin) : ""
    readonly property string plugin: /^org\.kernora\.[a-z]+$/.test(chosen) ? chosen : "org.kernora.shapes"
    readonly property string image: chosen === "org.kde.image" ? String(choice.item.image) : ""
    readonly property string colour: choice.status === Loader.Ready && /^[a-z]+(-[a-z]+)*$/.test(String(choice.item.colour)) ? String(choice.item.colour) : ""
    readonly property string mode: choice.status === Loader.Ready && /^(dark|light)$/.test(String(choice.item.mode)) ? String(choice.item.mode) : ""

    Settings {
        id: setup
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/kernora-first-login"
        category: "Setup"
    }

    property bool firstLogin: false

    function applySetupStyle(): void {
        if (!root.firstLogin) {
            return;
        }
        if (root.colour.length > 0) {
            M3.colourOverride = root.colour;
        }
        if (root.mode.length > 0) {
            M3.darkOverride = root.mode === "dark";
        }
        const points = Number(Qt.application.font.pointSize);
        M3.scaleOverride = points > 10.5 ? points / 10.5 : 0;
        M3.reloadGeneration();
    }

    Component.onCompleted: {
        root.firstLogin = String(setup.value("firstLogin", "false")) === "true";
        root.applySetupStyle();
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: M3.surface
        opacity: 0

        NumberAnimation on opacity {
            from: 0
            to: 1
            duration: 450
            easing.type: Easing.OutCubic
        }

        Loader {
            id: scene
            anchors.fill: parent
            active: !root.firstLogin && (root.image.length === 0 || picture.status === Image.Error)
            source: "file:///usr/share/plasma/wallpapers/" + root.plugin + "/contents/ui/Scene.qml"

            readonly property real loop: status === Loader.Ready && item.loopSeconds > 0 ? item.loopSeconds : 180
            readonly property real offset: (Screen.virtualX / 7919 + Screen.virtualY / 104729) % 1
            property real phase: 0

            function clockPhase(): real {
                return (offset + Date.now() / 1000 / loop) % 1;
            }

            Timer {
                interval: 100
                repeat: true
                running: scene.status === Loader.Ready
                onTriggered: scene.phase = scene.clockPhase()
            }

            onLoaded: {
                if (root.colour.length > 0) {
                    item.colour = root.colour;
                }
                item.intro = 1;
                scene.phase = scene.clockPhase();
                item.phase = Qt.binding(() => scene.phase);
            }
            onStatusChanged: {
                if (status === Loader.Error && source.toString().indexOf("org.kernora.shapes") < 0) {
                    source = "file:///usr/share/plasma/wallpapers/org.kernora.shapes/contents/ui/Scene.qml";
                }
            }
        }

        Image {
            id: picture
            anchors.fill: parent
            visible: status === Image.Ready
            source: root.image.length > 0 ? "file://" + root.image : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: width
        }
    }

    Loader {
        anchors.fill: parent
        active: root.firstLogin
        source: "FirstLogin.qml"
    }
}
