/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import org.kernora.store
import "components"

AppWindow {
    id: app

    title: i18n("Store")
    width: 1240
    height: 820
    minimumWidth: 420
    minimumHeight: 560
    color: M3.surface
    visible: true

    readonly property bool narrow: width < 860
    property string section: "apps"
    property string lastTab: "apps"
    property bool hiding: false
    property string pendingUrl: ""

    readonly property var tabs: [
        {value: "apps", label: i18n("Apps")},
        {value: "games", label: i18n("Games")},
        {value: "categories", label: i18n("Categories")}
    ]

    readonly property bool canGoBack: stack.depth > 1
    readonly property alias searchText: search.text

    function showSection(name: string): void {
        if (name !== "search") {
            lastTab = name;
            if (search.text.length > 0) {
                search.text = "";
            }
        }
        section = name;
        stack.clear(QQC2.StackView.Immediate);
        if (name === "apps") {
            stack.push(Qt.resolvedUrl("HomePage.qml"), {}, QQC2.StackView.Immediate);
        } else if (name === "games") {
            stack.push(Qt.resolvedUrl("ListPage.qml"), {
                title: i18n("All games"),
                category: "games",
                shelfTitle: i18n("Recommended"),
                shelfCollection: "games",
                showHeader: false
            }, QQC2.StackView.Immediate);
        } else if (name === "categories") {
            stack.push(Qt.resolvedUrl("CategoriesPage.qml"), {}, QQC2.StackView.Immediate);
        } else if (name === "search") {
            stack.push(Qt.resolvedUrl("ListPage.qml"), {title: i18n("Search"), searching: true}, QQC2.StackView.Immediate);
        }
    }

    function openApp(id: string): void {
        if (id.length > 0) {
            stack.push(Qt.resolvedUrl("AppPage.qml"), {appId: id});
        }
    }

    function openCategory(category: string): void {
        stack.push(Qt.resolvedUrl("ListPage.qml"), {title: Store.categoryName(category), category: category});
    }

    function openMyApps(): void {
        if (stack.currentItem && stack.currentItem.objectName === "myApps") {
            return;
        }
        stack.push(Qt.resolvedUrl("MyAppsPage.qml"), {objectName: "myApps"});
    }

    function goBack(): void {
        if (stack.depth > 1) {
            stack.pop();
        }
    }

    function handleArguments(args: var): void {
        for (const argument of args || []) {
            const text = String(argument);
            if (text.startsWith("-")) {
                continue;
            }
            const id = Store.openUrl(text);
            if (id.length > 0) {
                openApp(id);
                return;
            }
            if (text.startsWith("appstream:")) {
                pendingUrl = text;
            }
        }
    }

    Component.onCompleted: {
        showSection("apps");
        if (startArguments && startArguments.length > 0) {
            handleArguments(startArguments);
        }
    }

    onVisibleChanged: {
        if (visible) {
            hiding = false;
        }
    }

    onClosing: close => {
        if (Store.busyCount > 0) {
            close.accepted = false;
            hiding = true;
            app.visible = false;
        }
    }

    Connections {
        target: Store
        function onMessage(text: string): void {
            app.showMessage(text, "", null);
        }
        function onJobsChanged(): void {
            if (app.hiding && Store.busyCount === 0) {
                Qt.quit();
            }
        }
        function onCatalogChanged(): void {
            if (app.pendingUrl.length > 0 && Store.ready) {
                const id = Store.openUrl(app.pendingUrl);
                if (id.length > 0) {
                    app.pendingUrl = "";
                    app.openApp(id);
                }
            }
        }
    }

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: search.forceActiveFocus()
    }
    Shortcut {
        sequences: [StandardKey.Back, "Alt+Left"]
        onActivated: app.goBack()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: 64
            Layout.leftMargin: 20
            Layout.rightMargin: 12
            spacing: 12

            AppIcon {
                size: 32
                name: "org.kernora.store"
            }
            MText {
                visible: app.width > 560
                role: "titleLarge"
                text: i18n("Store")
            }
            StoreTabs {
                visible: !app.narrow
                Layout.fillHeight: true
                Layout.leftMargin: 24
                tabs: app.tabs
                current: app.section
                onSelected: value => app.showSection(value)
            }
            Item {
                Layout.fillWidth: true
            }
            SearchField {
                id: search
                Layout.preferredWidth: app.narrow ? Math.max(160, app.width - (app.width > 560 ? 380 : 260)) : Math.min(420, app.width * 0.3)
                implicitHeight: 44
                placeholderText: i18n("Search apps and games")
                onTextChanged: {
                    if (text.trim().length > 0 && (app.section !== "search" || stack.depth > 1)) {
                        app.showSection("search");
                    } else if (text.trim().length === 0 && app.section === "search") {
                        app.showSection(app.lastTab);
                    }
                }
                onAccepted: {
                    if (text.trim().length > 0) {
                        app.showSection("search");
                    }
                }
            }
            MIconButton {
                icon: "view-refresh"
                text: Store.loading ? i18n("Refreshing…") : i18n("Refresh")
                enabled: !Store.loading && !Store.checkingUpdates
                onClicked: Store.refresh()
            }
            Item {
                implicitWidth: myApps.implicitWidth
                implicitHeight: myApps.implicitHeight

                MButton {
                    id: myApps
                    visible: app.width > 560
                    variant: "tonal"
                    icon: "view-app-grid"
                    text: i18n("My apps")
                    onClicked: app.openMyApps()
                }
                MIconButton {
                    anchors.centerIn: parent
                    visible: !myApps.visible
                    icon: "view-app-grid"
                    text: i18n("My apps")
                    onClicked: app.openMyApps()
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: -4
                    anchors.topMargin: -4
                    visible: Store.updateCount > 0
                    width: Math.max(height, count.implicitWidth + 10)
                    height: 20
                    radius: height / 2
                    color: M3.error

                    MText {
                        id: count
                        anchors.centerIn: parent
                        role: "labelSmall"
                        text: Store.updateCount
                        color: M3.errorContent
                    }
                }
            }
        }

        StoreTabs {
            visible: app.narrow
            Layout.leftMargin: 8
            tabs: app.tabs
            current: app.section
            onSelected: value => app.showSection(value)
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: M3.outlineVariant
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            QQC2.StackView {
                id: stack
                anchors.fill: parent

                pushEnter: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
                        NumberAnimation { property: "x"; from: 32; to: 0; duration: M3.durationMedium4; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
                    }
                }
                pushExit: Transition {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: M3.durationShort4 }
                }
                popEnter: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
                }
                popExit: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: M3.durationShort4 }
                        NumberAnimation { property: "x"; from: 0; to: 32; duration: M3.durationShort4 }
                    }
                }
                replaceEnter: pushEnter
                replaceExit: pushExit
            }

            Item {
                anchors.fill: parent
                visible: opacity > 0
                enabled: !Store.ready
                opacity: Store.ready ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: M3.durationMedium4 } }
                z: 10

                Rectangle {
                    anchors.fill: parent
                    color: M3.surface
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 420)
                    spacing: 16

                    EmptyState {
                        Layout.fillWidth: true
                        icon: Store.error.length > 0 ? "network-offline" : "org.kernora.store"
                        title: Store.error.length > 0 ? i18n("The catalogue is not available") : i18n("Getting the catalogue ready")
                        text: Store.error.length > 0 ? Store.error : (Store.loadingText.length > 0 ? Store.loadingText : i18n("This takes a moment the first time."))
                        actionText: Store.error.length > 0 ? i18n("Try again") : ""
                        onActionTriggered: Store.refresh()
                    }

                    LinearProgress {
                        Layout.fillWidth: true
                        Layout.leftMargin: 48
                        Layout.rightMargin: 48
                        visible: Store.error.length === 0
                        indeterminate: true
                    }
                }
            }
        }
    }
}
