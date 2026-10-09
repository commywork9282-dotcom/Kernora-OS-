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
    readonly property bool reducedMotion: Kirigami.Units.longDuration === 0
    readonly property bool covered: root.configuration.PauseWhenCovered && coveringWindows.count > 0
    readonly property bool running: !reducedMotion && !covered && root.visible

    property real phase: (Screen.virtualX / 7919 + Screen.virtualY / 104729) % 1

    Scene {
        id: scene
        anchors.fill: parent
        phase: root.phase
        intro: 0

        NumberAnimation on intro {
            from: 0
            to: 1
            duration: root.reducedMotion ? 0 : 1600
            easing.type: Easing.OutCubic
        }
    }

    property double lastTick: 0
    Timer {
        interval: 33
        repeat: true
        running: root.running
        onRunningChanged: root.lastTick = Date.now()
        onTriggered: {
            const now = Date.now();
            const dt = Math.min(now - root.lastTick, 100) / 1000;
            root.lastTick = now;
            root.phase = (root.phase + dt * root.speed / scene.loopSeconds) % 1;
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
        filterByScreen: true
        filterMinimized: true
        filterHidden: true
        screenGeometry: Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height)
        virtualDesktop: virtualDesktopInfo.currentDesktop
        activity: activityInfo.currentActivity
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    KItemModels.KSortFilterProxyModel {
        id: coveringWindows
        sourceModel: tasks
        filterRowCallback: (row, parent) => {
            const index = sourceModel.index(row, 0, parent);
            const maximized = sourceModel.data(index, TaskManager.AbstractTasksModel.IsMaximized);
            const fullScreen = sourceModel.data(index, TaskManager.AbstractTasksModel.IsFullScreen);
            return maximized === true || fullScreen === true;
        }
    }
}
