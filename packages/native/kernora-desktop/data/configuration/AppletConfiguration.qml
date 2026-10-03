/*
    SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Nicolas Fella <nicolas.fella@gmx.de>
    SPDX-FileCopyrightText: 2020 Carl Schwan <carlschwan@kde.org>
    SPDX-FileCopyrightText: 2022-2023 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.configuration
import org.kde.plasma.plasmoid
import org.kernora.m3
import org.kernora.ui as UI

Rectangle {
    id: root

    implicitWidth: Kirigami.Units.gridUnit * 44
    implicitHeight: Kirigami.Units.gridUnit * 32

    Layout.minimumWidth: Kirigami.Units.gridUnit * 34
    Layout.minimumHeight: Kirigami.Units.gridUnit * 22

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    color: M3.surfaceContainer

    property bool isContainment: false

    property ConfigModel globalConfigModel: globalAppletConfigModel

    property url currentSource
    property string currentName

    function closing() {
        if (applyButton.enabled) {
            messageDialog.item = null;
            messageDialog.open();
            return false;
        }
        return true;
    }

    function saveConfig() {
        const config = Plasmoid.configuration;

        config.keys().forEach(key => {
            const cfgKey = "cfg_" + key;
            if (cfgKey in app.pageStack.currentItem) {
                config[key] = app.pageStack.currentItem[cfgKey];
            }
        })

        plasmoid.configuration.writeConfig();

        if (app.pageStack.currentItem.hasOwnProperty("saveConfig")) {
            app.pageStack.currentItem.saveConfig()
        }
    }

    Connections {
        target: configDialog
        function onClosing(event) {
            event.accepted = closing();
        }
    }

    ConfigModel {
        id: globalAppletConfigModel
        ConfigCategory {
            name: i18nd("plasma_shell_org.kde.plasma.desktop", "Keyboard Shortcuts")
            icon: "preferences-desktop-keyboard"
            source: Qt.resolvedUrl("ConfigurationShortcuts.qml")
        }
    }

    KItemModels.KSortFilterProxyModel {
        id: configDialogFilterModel
        sourceModel: configDialog.configModel
        filterRowCallback: (row, parent) => {
            return sourceModel.data(sourceModel.index(row, 0), ConfigModel.VisibleRole);
        }
    }

    function settingValueChanged() {
        applyButton.enabled = true;
    }

    function pushReplace(item, config) {
        let page;
        if (app.pageStack.depth === 0) {
            page = app.pageStack.push(item, config);
        } else {
            page = app.pageStack.replace(item, config);
        }
        app.currentConfigPage = page;
    }
    Component {
        id: configurationKcmPageComponent
        ConfigurationKcmPage {
        }
    }

    function open(item) {
        app.isAboutPage = false;
        root.currentSource = item.source
        root.currentName = item.name || ""

        if (item.source) {
            app.isAboutPage = item.source === Qt.resolvedUrl("AboutPlugin.qml");

            if (isContainment) {
                pushReplace(Qt.resolvedUrl("ConfigurationAppletPage.qml"), {configItem: item});
            } else {
                const config = Plasmoid.configuration;

                const props = {
                    "title": item.name
                };

                config.keys().forEach(key => {
                    props["cfg_" + key] = config[key];
                });

                pushReplace(item.source, props);
            }

        } else if (item.kcm) {
            pushReplace(configurationKcmPageComponent, {kcm: item.kcm, internalPage: item.kcm.mainUi});
        } else {
            app.pageStack.pop();
        }

        applyButton.enabled = false
    }

    Connections {
        target: app.currentConfigPage
        ignoreUnknownSignals: true

        function onSettingValueChanged() {
            applyButton.enabled = true;
        }
    }

    Connections {
        target: app.pageStack

        function onCurrentItemChanged() {
            if (app.pageStack.currentItem !== null && !isContainment) {
                const config = Plasmoid.configuration;

                config.keys().forEach(key => {
                    const changedSignal = app.pageStack.currentItem["cfg_" + key + "Changed"];
                    if (changedSignal) {
                        changedSignal.connect(() => root.settingValueChanged());
                    }
                });

                const configurationChangedSignal = app.pageStack.currentItem.configurationChanged;
                if (configurationChangedSignal) {
                    configurationChangedSignal.connect(() => root.settingValueChanged());
                }
            }
        }
    }

    Component.onCompleted: {
        if (isContainment || !configDialog.configModel || configDialog.configModel.count === 0) {
            open(root.globalConfigModel.get(0))
        } else {
            open(configDialog.configModel.get(0))
        }
    }

    function applicationWindow() {
        return app;
    }

    QQC2.ScrollView {
        id: categoriesScroll
        anchors {
            left: parent.left
            top: parent.top
            bottom: footer.top
            leftMargin: 12
            topMargin: 12
        }
        width: Kirigami.Units.gridUnit * 13
        contentWidth: availableWidth
        activeFocusOnTab: true
        focus: true
        Accessible.role: Accessible.PageTabList
        background: null

        ColumnLayout {
            id: categories

            spacing: 2
            width: categoriesScroll.contentWidth
            focus: true

            function openCategory(item) {
                if (applyButton.enabled) {
                    messageDialog.item = item;
                    messageDialog.open();
                    return;
                }
                open(item)
            }

            Component {
                id: categoryDelegate
                UI.NavigationItem {
                    required property var model
                    Layout.fillWidth: true
                    title: model.name
                    icon: model.icon
                    current: {
                        if (app.pageStack.currentItem) {
                            if (model.kcm && app.pageStack.currentItem.kcm) {
                                return model.kcm == app.pageStack.currentItem.kcm
                            } else {
                                return root.currentSource == model.source
                            }
                        }
                        return false
                    }
                    onClicked: categories.openCategory(model)
                }
            }

            Repeater {
                model: root.isContainment ? globalConfigModel : undefined
                delegate: categoryDelegate
            }
            Repeater {
                model: configDialogFilterModel
                delegate: categoryDelegate
            }
            Repeater {
                model: !root.isContainment ? globalConfigModel : undefined
                delegate: categoryDelegate
            }
            Repeater {
                model: ConfigModel {
                    ConfigCategory{
                        name: i18nd("plasma_shell_org.kde.plasma.desktop", "About")
                        icon: "help-about"
                        source: Qt.resolvedUrl("AboutPlugin.qml")
                    }
                }
                delegate: categoryDelegate
            }
        }
    }

    UI.RoundedClip {
        id: pane
        anchors {
            left: categoriesScroll.right
            right: parent.right
            top: parent.top
            bottom: footer.top
            leftMargin: 12
            rightMargin: 12
            topMargin: 12
        }
        radius: M3.classic ? M3.cornerCard : 28

        Rectangle {
            anchors.fill: parent
            color: M3.surface
        }

        MText {
            id: headline
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 28
                rightMargin: 28
                topMargin: 24
            }
            role: "headlineSmall"
            text: root.currentName
        }

        Kirigami.ApplicationItem {
            id: app
            anchors {
                top: headline.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: 12
                leftMargin: 12
                rightMargin: 12
            }

            pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None
            wideScreen: true
            Kirigami.Theme.inherit: false
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.backgroundColor: M3.surface

            property var currentConfigPage: null
            property bool isAboutPage: false

            UI.Dialog {
                id: messageDialog
                property var item
                title: i18nd("plasma_shell_org.kde.plasma.desktop", "Apply Settings")
                text: i18nd("plasma_shell_org.kde.plasma.desktop", "The settings of the current module have changed. Do you want to apply the changes or discard them?")
                showAccept: false
                showReject: false

                function applied() {
                    applyAction.trigger()
                    discarded();
                }
                function discarded() {
                    if (item) {
                        root.open(item);
                        messageDialog.close();
                    } else {
                        applyButton.enabled = false;
                        configDialog.close();
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    QQC2.Button {
                        flat: true
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Cancel")
                        onClicked: messageDialog.close()
                    }
                    QQC2.Button {
                        flat: true
                        text: i18nd("kernora-ui", "Discard")
                        onClicked: messageDialog.discarded()
                    }
                    QQC2.Button {
                        flat: true
                        text: i18nd("plasma_shell_org.kde.plasma.desktop", "Apply")
                        onClicked: messageDialog.applied()
                    }
                }
            }

            QQC2.Action {
                id: acceptAction
                onTriggered: {
                    applyAction.trigger();
                    configDialog.close();
                }
            }

            QQC2.Action {
                id: applyAction
                onTriggered: {
                    if (isContainment) {
                        app.pageStack.get(0).saveConfig()
                    } else {
                        root.saveConfig()
                    }

                    applyButton.enabled = false;
                }
            }

            QQC2.Action {
                id: cancelAction
                onTriggered: {
                    if (root.closing()) {
                        configDialog.close();
                    }
                }
            }

            Keys.onReturnPressed: acceptAction.trigger();
            Keys.onEscapePressed: cancelAction.trigger();
        }
    }

    RowLayout {
        id: footer
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: 12
            rightMargin: 16
        }
        height: 64
        spacing: 8

        Item {
            Layout.fillWidth: true
        }

        MButton {
            variant: "text"
            text: i18nd("plasma_shell_org.kde.plasma.desktop", "Cancel")
            visible: !app.isAboutPage
            onClicked: cancelAction.trigger()
            KeyNavigation.tab: categories
        }
        MButton {
            id: applyButton
            variant: "tonal"
            enabled: false
            text: i18nd("plasma_shell_org.kde.plasma.desktop", "Apply")
            visible: !app.isAboutPage && app.pageStack.currentItem && (!app.pageStack.currentItem.kcm || app.pageStack.currentItem.kcm.buttons & 4)
            onClicked: applyAction.trigger()
        }
        MButton {
            variant: "filled"
            text: i18nd("plasma_shell_org.kde.plasma.desktop", "OK")
            onClicked: acceptAction.trigger()
        }
    }
}
