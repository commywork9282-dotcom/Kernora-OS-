/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "components"

AppWindow {
    id: app

    required property var catalog
    required property Window owner
    property string currentCategory: ""
    property string initialPage: ""

    readonly property bool narrow: true
    readonly property bool canGoBack: true
    readonly property bool fullscreen: true

    title: stack.currentItem && stack.currentItem.title ? stack.currentItem.title : i18n("Settings")
    flags: Qt.Window | Qt.FramelessWindowHint
    color: M3.surface
    minimumWidth: 380
    minimumHeight: 520

    function openCategory(id: string, subpage: string, properties: var): void {
        const category = catalog.category(id);
        if (!category) {
            return;
        }
        currentCategory = id;
        const file = subpage && subpage.length > 0 ? subpage : category.page;
        stack.push(Qt.resolvedUrl("pages/" + file), properties || {});
    }

    function openPage(file: string, properties: var): void {
        stack.push(Qt.resolvedUrl("pages/" + file), properties || {});
    }

    function goBack(): void {
        if (stack.depth > 1) {
            stack.pop();
        } else {
            app.close();
        }
    }

    onClosing: close => {
        if (Appearance.busy && !owner.visible) {
            close.accepted = false;
            app.visible = false;
            themeFinished.enabled = true;
        }
    }

    Connections {
        id: themeFinished
        target: Appearance
        enabled: false
        function onBusyChanged(): void {
            if (!Appearance.busy && !app.owner.visible) {
                Qt.quit();
            }
        }
    }

    Component.onCompleted: {
        if (initialPage.length > 0) {
            stack.push(Qt.resolvedUrl("pages/" + initialPage), {}, QQC2.StackView.Immediate);
        }
    }

    Shortcut {
        sequences: [StandardKey.Back, "Alt+Left"]
        onActivated: app.goBack()
    }

    TapHandler {
        acceptedButtons: Qt.BackButton
        onTapped: app.goBack()
    }

    QQC2.StackView {
        id: stack
        anchors.fill: parent

        pushEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
                NumberAnimation { property: "x"; from: 48; to: 0; duration: M3.durationMedium4; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
            }
        }
        pushExit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: M3.durationShort4 }
        }
        popEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
                NumberAnimation { property: "x"; from: -48; to: 0; duration: M3.durationMedium4; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
            }
        }
        popExit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: M3.durationShort4 }
                NumberAnimation { property: "x"; from: 0; to: 48; duration: M3.durationShort4 }
            }
        }
        replaceEnter: pushEnter
        replaceExit: pushExit
    }
}
