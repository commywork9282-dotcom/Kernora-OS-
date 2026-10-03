/*
    SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQml

import org.kde.kirigami as Kirigami
import org.kde.plasma.configuration
import org.kde.plasma.plasmoid
import org.kernora.m3
import org.kernora.ui as UI

Item {
    id: appearanceRoot
    signal configurationChanged

    implicitHeight: content.implicitHeight

    property string currentWallpaper: ""
    property string containmentPlugin: ""
    property alias parentLayout: parentLayout
    property int formAlignment: 0

    function tr(text: string): string {
        return i18nd("kernora-ui", text);
    }

    function saveConfig() {
        if (main.currentItem.saveConfig) {
            main.currentItem.saveConfig()
        }
        configDialog.currentWallpaper = appearanceRoot.currentWallpaper;
        for (var key in configDialog.wallpaperConfiguration) {
            if (main.currentItem["cfg_"+key] !== undefined) {
                configDialog.wallpaperConfiguration[key] = main.currentItem["cfg_"+key]
            }
        }
        configDialog.applyWallpaper()
        configDialog.containmentPlugin = appearanceRoot.containmentPlugin
    }

    function chooseWallpaper(row: int): void {
        const index = configDialog.wallpaperConfigModel.index(row, 0)
        const pluginName = configDialog.wallpaperConfigModel.data(index, ConfigModel.PluginNameRole)
        if (appearanceRoot.currentWallpaper === pluginName) {
            return;
        }
        appearanceRoot.currentWallpaper = pluginName
        configDialog.currentWallpaper = pluginName
        main.sourceFile = configDialog.wallpaperConfigModel.data(index, ConfigModel.SourceRole)
        appearanceRoot.configurationChanged()
    }

    ColumnLayout {
        id: content
        width: root.availableWidth
        spacing: 20

        Component.onCompleted: {
            appearanceRoot.containmentPlugin = configDialog.containmentPlugin
            for (var i = 0; i < configDialog.wallpaperConfigModel.count; ++i) {
                var pluginName = configDialog.wallpaperConfigModel.data(configDialog.wallpaperConfigModel.index(i, 0), ConfigModel.PluginNameRole);
                if (configDialog.currentWallpaper === pluginName) {
                    appearanceRoot.currentWallpaper = pluginName
                    main.sourceFile = configDialog.wallpaperConfigModel.data(configDialog.wallpaperConfigModel.index(i, 0), ConfigModel.SourceRole)
                    break;
                }
            }
        }

        Kirigami.InlineMessage {
            visible: Plasmoid.immutable || animating
            text: i18nd("plasma_shell_org.kde.plasma.desktop", "Layout changes have been restricted by the system administrator")
            showCloseButton: true
            Layout.fillWidth: true
        }

        UI.Group {
            Layout.fillWidth: true
            enabled: main.currentItem && main.currentItem.objectName !== "switchContainmentWarningItem"

            Repeater {
                model: configDialog.wallpaperConfigModel
                delegate: UI.RadioRow {
                    required property int index
                    required property var model
                    width: parent ? parent.width : implicitWidth
                    title: model.name
                    checked: appearanceRoot.currentWallpaper === model.pluginName
                    onClicked: appearanceRoot.chooseWallpaper(index)
                }
            }
        }

        UI.Group {
            Layout.fillWidth: true
            title: appearanceRoot.tr("Settings")
            visible: main.currentItem && main.currentItem !== emptyConfig && main.implicitHeight > 0

            QQC2.StackView {
                id: main

                readonly property bool fillsPage: ["org.kde.image", "org.kde.slideshow"].includes(appearanceRoot.currentWallpaper)

                width: parent ? parent.width : implicitWidth
                height: implicitHeight
                implicitHeight: main.empty ? 0 : (fillsPage ? Math.max(currentItem.implicitHeight, 560) : currentItem.implicitHeight)

                property string sourceFile: "tbd"

                onSourceFileChanged: loadSourceFile()

                function loadSourceFile() {
                    const wallpaperConfig = configDialog.wallpaperConfiguration
                    if (wallpaperConfig && sourceFile) {
                        var props = {
                            "configDialog": configDialog
                        }

                        for (var key in wallpaperConfig) {
                            props["cfg_" + key] = wallpaperConfig[key]
                        }

                        var newItem = replace(Qt.resolvedUrl(sourceFile), props)

                        for (var key in wallpaperConfig) {
                            var changedSignal = newItem["cfg_" + key + "Changed"]
                            if (changedSignal) {
                                changedSignal.connect(appearanceRoot.configurationChanged)
                            }
                        }

                        const configurationChangedSignal = newItem.configurationChanged
                        if (configurationChangedSignal) {
                            configurationChangedSignal.connect(appearanceRoot.configurationChanged)
                        }
                    } else {
                        replace(emptyConfig)
                    }
                }
            }
        }

        UI.Group {
            Layout.fillWidth: true
            title: appearanceRoot.tr("Desktop")
            enabled: !Plasmoid.immutable

            Repeater {
                model: configDialog.containmentPluginsConfigModel
                delegate: UI.RadioRow {
                    required property var model
                    width: parent ? parent.width : implicitWidth
                    title: model.name
                    checked: appearanceRoot.containmentPlugin === model.pluginName
                    onClicked: {
                        appearanceRoot.containmentPlugin = model.pluginName
                        appearanceRoot.configurationChanged()
                    }
                }
            }
        }

        Kirigami.FormLayout {
            id: parentLayout
            twinFormLayouts: main.currentItem && main.currentItem.formLayout ? main.currentItem.formLayout : []
            visible: false
        }

        Item {
            id: emptyConfig
        }
    }

    Component {
        id: switchContainmentWarning

        Item {
            objectName: "switchContainmentWarningItem"
            implicitHeight: message.implicitHeight + 48

            UI.EmptyState {
                id: message
                width: parent.width
                icon: "dialog-information"
                title: i18nd("plasma_shell_org.kde.plasma.desktop", "Layout changes must be applied before other changes can be made")
                actionText: i18nd("plasma_shell_org.kde.plasma.desktop", "Apply Now")
                onActionTriggered: saveConfig()
            }
        }
    }

    onContainmentPluginChanged: {
        if (configDialog.containmentPlugin !== appearanceRoot.containmentPlugin) {
            main.push(switchContainmentWarning);
            categoriesScroll.enabled = false;
        } else if (main.currentItem && main.currentItem.objectName === "switchContainmentWarningItem") {
            main.pop();
            categoriesScroll.enabled = true;
        }
    }
}
