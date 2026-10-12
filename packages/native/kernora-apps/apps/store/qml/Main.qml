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

AppWindow {
    id: app

    title: i18n("Store")
    width: 1240
    height: 820
    minimumWidth: 420
    minimumHeight: 560
    color: M3.surfaceContainer
    visible: true

    readonly property bool narrow: width < 920
    property string section: ""
    property bool pageShown: false
    property bool hiding: false
    property string pendingUrl: ""

    function showSection(name: string): void {
        if (name !== "search") {
            search.text = "";
        }
        section = name;
        stack.clear(QQC2.StackView.Immediate);
        if (name === "home") {
            stack.push(Qt.resolvedUrl("HomePage.qml"), {}, QQC2.StackView.Immediate);
        } else if (name === "updates") {
            stack.push(Qt.resolvedUrl("UpdatesPage.qml"), {}, QQC2.StackView.Immediate);
        } else if (name === "installed") {
            stack.push(Qt.resolvedUrl("ListPage.qml"), {title: i18n("Installed"), filter: Store.Installed}, QQC2.StackView.Immediate);
        } else if (name === "search") {
            stack.push(Qt.resolvedUrl("ListPage.qml"), {title: i18n("Search"), searching: true}, QQC2.StackView.Immediate);
        } else if (name.startsWith("category:")) {
            const category = name.slice(9);
            stack.push(Qt.resolvedUrl("ListPage.qml"), {title: Store.categoryName(category), category: category}, QQC2.StackView.Immediate);
        }
        pageShown = true;
    }

    function openApp(id: string): void {
        if (id.length === 0) {
            return;
        }
        stack.push(Qt.resolvedUrl("AppPage.qml"), {appId: id});
        pageShown = true;
    }

    function goBack(): void {
        if (stack.depth > 1) {
            stack.pop();
        } else if (narrow) {
            pageShown = false;
        }
    }

    readonly property bool canGoBack: stack.depth > 1 || narrow
    readonly property alias searchText: search.text

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
        if (!narrow) {
            showSection("home");
        }
        if (startArguments && startArguments.length > 0) {
            handleArguments(startArguments);
        }
    }

    onNarrowChanged: {
        if (!narrow && section.length === 0) {
            showSection("home");
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
        onActivated: {
            app.pageShown = false;
            search.forceActiveFocus();
        }
    }
    Shortcut {
        sequences: [StandardKey.Back, "Alt+Left"]
        onActivated: app.goBack()
    }

    component Destination: Item {
        id: destination

        property string name
        property string title
        property string icon
        property int badge: 0

        width: parent ? parent.width : 300
        height: item.implicitHeight

        NavigationItem {
            id: item
            width: parent.width
            title: destination.title
            icon: destination.icon
            accent: 0
            current: app.section === destination.name && !app.narrow
            onClicked: app.showSection(destination.name)
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            visible: destination.badge > 0
            width: Math.max(height, count.implicitWidth + 12)
            height: 22
            radius: height / 2
            color: M3.error

            MText {
                id: count
                anchors.centerIn: parent
                role: "labelMedium"
                text: destination.badge
                color: M3.errorContent
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: navigation

            Layout.fillHeight: true
            Layout.preferredWidth: app.narrow ? app.width : 320
            visible: !app.narrow || !app.pageShown

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: app.narrow ? 12 : 4
                spacing: 12

                MText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.topMargin: 12
                    role: "headlineMedium"
                    text: i18n("Store")
                    visible: app.narrow
                }

                SearchField {
                    id: search
                    Layout.fillWidth: true
                    Layout.topMargin: app.narrow ? 0 : 8
                    placeholderText: i18n("Search apps")
                    onTextChanged: {
                        if (text.trim().length > 0 && app.section !== "search") {
                            app.showSection("search");
                        } else if (text.trim().length === 0 && app.section === "search") {
                            app.showSection("home");
                        }
                    }
                    onAccepted: {
                        if (text.trim().length > 0) {
                            app.showSection("search");
                        }
                    }
                }

                MButton {
                    Layout.fillWidth: true
                    variant: "text"
                    icon: "view-refresh"
                    text: Store.loading ? i18n("Refreshing…") : i18n("Refresh")
                    enabled: !Store.loading && !Store.checkingUpdates
                    onClicked: Store.refresh()
                }

                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                    Column {
                        width: parent.width
                        spacing: 2

                        Destination {
                            name: "home"
                            title: i18n("Discover")
                            icon: "go-home"
                        }

                        Item { width: 1; height: 8 }

                        MText {
                            x: 16
                            height: 40
                            verticalAlignment: Text.AlignVCenter
                            role: "titleSmall"
                            text: i18n("Categories")
                            color: M3.surfaceVariantContent
                        }

                        Repeater {
                            model: Store.categories
                            delegate: Destination {
                                required property var modelData
                                name: "category:" + modelData.id
                                title: modelData.name
                                icon: modelData.icon
                            }
                        }

                        Item { width: 1; height: 8 }

                        Rectangle {
                            x: 16
                            width: parent.width - 32
                            height: 1
                            color: M3.outlineVariant
                        }

                        Item { width: 1; height: 8 }

                        Destination {
                            name: "installed"
                            title: i18n("Installed")
                            icon: "view-app-grid"
                        }

                        Destination {
                            name: "updates"
                            title: i18n("Updates")
                            icon: "system-software-update"
                            badge: Store.updateCount
                        }

                        Item { width: 1; height: 16 }
                    }
                }
            }
        }

        Rectangle {
            id: pane

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: app.narrow ? 0 : 8
            Layout.rightMargin: app.narrow ? 0 : 12
            Layout.bottomMargin: app.narrow ? 0 : 12
            visible: !app.narrow || app.pageShown
            radius: app.narrow ? 0 : (M3.classic ? M3.cornerCard : 28)
            color: M3.surface
            clip: true

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

            Item {
                anchors.fill: parent
                visible: !Store.ready
                z: 10

                Rectangle {
                    anchors.fill: parent
                    radius: pane.radius
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
