/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

WallpaperItem {
    id: root

    readonly property real speed: Math.max(0.1, root.configuration.Speed)
    readonly property bool reducedMotion: Kirigami.Units.longDuration <= 1
    readonly property bool covered: root.configuration.PauseWhenCovered && coveringWindows.count > 0
    readonly property bool running: !reducedMotion && !covered && root.visible

    readonly property real offset: (Screen.virtualX / 7919 + Screen.virtualY / 104729) % 1
    readonly property bool switched: Date.now() - Number(root.configuration.IntroAt || 0) < 15000
    property double anchorTime: 0
    property real anchorPhase: 0
    property real phase: 0

    readonly property bool lockScreen: typeof authenticator !== "undefined"
    property double lastFrame: 0
    property bool held: false
    property real glideFrom: 0
    property real glideBy: 0
    property real glide: 0

    function phaseAt(time: double): real {
        return (root.anchorPhase + (time - root.anchorTime) / 1000 * root.speed / scene.loopSeconds) % 1;
    }

    Component.onCompleted: {
        anchorTime = Date.now();
        anchorPhase = (offset + anchorTime / 1000 * speed / scene.loopSeconds) % 1;
        phase = anchorPhase;
        lastFrame = anchorTime;
    }

    Connections {
        target: root.Window.window
        function onFrameSwapped() {
            root.lastFrame = Date.now();
        }
    }

    NumberAnimation {
        id: settle
        target: root
        property: "glide"
        from: 0
        to: 1
        easing.type: Easing.InOutCubic
    }
    onGlideChanged: if (settle.running) root.phase = (root.glideFrom + root.glideBy * root.glide + 1) % 1
    onSpeedChanged: {
        anchorPhase = phase;
        anchorTime = Date.now();
    }

    Scene {
        id: scene
        anchors.fill: parent
        phase: root.phase
        intro: root.switched ? 0 : 1

        NumberAnimation on intro {
            running: root.switched
            from: 0
            to: 1
            duration: root.reducedMotion ? 0 : 1600
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: root.running && !root.lockScreen
        onTriggered: {
            const now = Date.now();
            if (now - root.lastFrame > 400) {
                root.held = true;
                root.Window.window?.update();
                return;
            }
            if (settle.running) {
                return;
            }
            if (root.held) {
                root.held = false;
                const distance = ((root.phaseAt(now) - root.phase) % 1 + 1.5) % 1 - 0.5;
                settle.duration = Math.min(2400, 600 + 4000 * Math.abs(distance));
                root.glideFrom = root.phase;
                root.glideBy = ((root.phaseAt(now + settle.duration) - root.phase) % 1 + 1.5) % 1 - 0.5;
                settle.restart();
                return;
            }
            root.phase = root.phaseAt(now);
        }
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.ActivityInfo {
        id: activityInfo
    }

    TaskManager.TasksModel {
        id: tasks
        filterByVirtualDesktop: true
        filterByActivity: true
        filterMinimized: true
        filterHidden: true
        virtualDesktop: virtualDesktopInfo.currentDesktop
        activity: activityInfo.currentActivity
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    KItemModels.KSortFilterProxyModel {
        id: coveringWindows
        sourceModel: tasks
        filterRowCallback: {
            const screen = Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height);
            return (row, parent) => {
                const index = sourceModel.index(row, 0, parent);
                const maximized = sourceModel.data(index, TaskManager.AbstractTasksModel.IsMaximized);
                const fullScreen = sourceModel.data(index, TaskManager.AbstractTasksModel.IsFullScreen);
                if (maximized !== true && fullScreen !== true) {
                    return false;
                }
                const geometry = sourceModel.data(index, TaskManager.AbstractTasksModel.Geometry);
                const x = geometry.x + geometry.width / 2;
                const y = geometry.y + geometry.height / 2;
                return x >= screen.x && x < screen.x + screen.width && y >= screen.y && y < screen.y + screen.height;
            };
        }
    }
}
