/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "components"

AppWindow {
    id: app

    title: i18n("Settings")
    width: 1180
    height: 780
    minimumWidth: 380
    minimumHeight: 520
    color: M3.surfaceContainer
    visible: true

    readonly property bool narrow: width < 880
    property string currentCategory: ""
    property bool pageShown: false

    Catalog {
        id: catalog
    }
    readonly property alias catalog: catalog

    function openCategory(id: string, subpage: string, properties: var): void {
        const category = catalog.category(id);
        if (!category) {
            return;
        }
        search.text = "";
        currentCategory = id;
        stack.clear(QQC2.StackView.Immediate);
        stack.push(Qt.resolvedUrl("pages/" + category.page), {}, QQC2.StackView.Immediate);
        if (subpage && subpage.length > 0) {
            stack.push(Qt.resolvedUrl("pages/" + subpage), properties || {}, QQC2.StackView.Immediate);
        }
        pageShown = true;
    }

    function openPage(file: string, properties: var): void {
        stack.push(Qt.resolvedUrl("pages/" + file), properties || {});
    }

    function goBack(): void {
        if (stack.depth > 1) {
            stack.pop();
        } else if (narrow) {
            pageShown = false;
        }
    }

    readonly property bool canGoBack: stack.depth > 1 || narrow

    function handleArguments(args: var): void {
        for (const argument of args || []) {
            const name = String(argument);
            if (name.startsWith("-")) {
                continue;
            }
            const target = catalog.resolve(name);
            if (target) {
                openCategory(target.category, target.page || "", {});
                return;
            }
            if (/^kcm_[A-Za-z0-9_.-]+$/.test(name) || /^[a-z0-9_.-]+$/.test(name)) {
                Process.openModule(name);
                return;
            }
        }
    }

    Component.onCompleted: {
        if (startArguments && startArguments.length > 0) {
            handleArguments(startArguments);
        }
        if (currentCategory.length === 0) {
            if (narrow) {
                currentCategory = "";
            } else {
                openCategory("network", "", {});
            }
        }
    }

    onNarrowChanged: {
        if (!narrow && currentCategory.length === 0) {
            openCategory("network", "", {});
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

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: navigation

            Layout.fillHeight: true
            Layout.preferredWidth: app.narrow ? app.width : 340
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
                    text: i18n("Settings")
                    visible: app.narrow
                }

                SearchField {
                    id: search
                    Layout.fillWidth: true
                    Layout.topMargin: app.narrow ? 0 : 8
                    placeholderText: i18n("Search settings")
                    onAccepted: results.activateFirst()
                    Keys.onDownPressed: results.forceActiveFocus()
                }

                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    visible: search.text.trim().length === 0
                    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                    Column {
                        width: parent.width
                        spacing: 2

                        AccountCard {
                            width: parent.width
                            current: app.currentCategory === "account" && (!app.narrow || app.pageShown)
                            onClicked: app.openCategory("account", "", {})
                        }

                        Item { width: 1; height: 10 }

                        Repeater {
                            model: catalog.categories
                            delegate: NavigationItem {
                                required property var modelData
                                visible: modelData.id !== "account"
                                height: visible ? implicitHeight : 0
                                title: modelData.title
                                subtitle: app.narrow ? modelData.subtitle : ""
                                icon: modelData.icon
                                accent: modelData.accent
                                current: app.currentCategory === modelData.id && !app.narrow
                                onClicked: app.openCategory(modelData.id, "", {})
                            }
                        }

                        Item { width: 1; height: 16 }
                    }
                }

                SearchResults {
                    id: results
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: search.text.trim().length > 0
                    query: search.text
                    entries: catalog.searchEntries
                    onActivated: entry => app.openCategory(entry.category, entry.page || "", {})
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
        }
    }
}
