/*
    SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kernora.m3
import org.kernora.ui as UI

Item {
    id: root

    signal configurationChanged
    implicitWidth: mainColumn.implicitWidth
    implicitHeight: mainColumn.implicitHeight + 24

    property var prettyStrings: {
        "LeftButton": i18nd("plasma_shell_org.kde.plasma.desktop", "Left-Button"),
        "RightButton": i18nd("plasma_shell_org.kde.plasma.desktop", "Right-Button"),
        "MiddleButton": i18nd("plasma_shell_org.kde.plasma.desktop", "Middle-Button"),
        "BackButton": i18nd("plasma_shell_org.kde.plasma.desktop", "Back-Button"),
        "ForwardButton": i18nd("plasma_shell_org.kde.plasma.desktop", "Forward-Button"),

        "wheel:Vertical": i18nd("plasma_shell_org.kde.plasma.desktop", "Vertical-Scroll"),
        "wheel:Horizontal": i18nd("plasma_shell_org.kde.plasma.desktop", "Horizontal-Scroll"),

        "ShiftModifier": i18nd("plasma_shell_org.kde.plasma.desktop", "Shift"),
        "ControlModifier": i18nd("plasma_shell_org.kde.plasma.desktop", "Ctrl"),
        "AltModifier": i18nd("plasma_shell_org.kde.plasma.desktop", "Alt"),
        "MetaModifier": i18nd("plasma_shell_org.kde.plasma.desktop", "Meta")
    }

    readonly property var pluginOptions: {
        const model = configDialog.containmentActionConfigModel;
        const options = [];
        for (let i = 0; i < model.count; ++i) {
            const plugin = model.get(i);
            options.push({ value: plugin.pluginName, label: plugin.name });
        }
        return options;
    }

    function tr(text: string): string {
        return i18nd("kernora-ui", text);
    }

    function triggerText(action: string): string {
        const splitAction = action.split(';');

        const button = splitAction[0];
        const parts = (splitAction[1] || "").split('|').filter(item => item !== "NoModifier" && item !== "");
        parts.push(button);

        return parts.map(item => prettyStrings[item] || item)
            .join(i18ndc("plasma_shell_org.kde.plasma.desktop", "Concatenation sign for shortcuts, e.g. Ctrl+Shift", "+"));
    }

    function pluginLabel(pluginName: string): string {
        const option = pluginOptions.find(o => o.value === pluginName);
        return option ? option.label : pluginName;
    }

    function saveConfig() {
        configDialog.currentContainmentActionsModel.save();
    }

    Connections {
        target: configDialog.currentContainmentActionsModel
        function onConfigurationChanged() {
            root.configurationChanged()
        }
    }

    Component {
        id: aboutComponent

        Kirigami.OverlaySheet {
            id: internalAboutDialog

            property alias metaData: aboutPluginPage.metaData

            width: Math.round(root.width * 0.8)
            onClosed: destroy()

            AboutPlugin {
                id: aboutPluginPage
                metaData: internalAboutDialog.metaData
            }

            Component.onCompleted: open();
        }
    }

    UI.Dialog {
        id: inputDialog

        property int row: -1
        property string current: ""
        property string plugin: ""
        property bool taken: false

        icon: "input-mouse"
        title: row === -1 ? i18nd("plasma_shell_org.kde.plasma.desktop", "Add Action") : root.tr("Change trigger")
        text: root.tr("Click in the area with the mouse button you want, holding Ctrl, Shift, Alt or Meta if you like, or turn the wheel there.")
        showAccept: false

        function start(row: int, current: string, plugin: string): void {
            inputDialog.row = row;
            inputDialog.current = current;
            inputDialog.plugin = plugin;
            inputDialog.taken = false;
            open();
        }

        function take(eventString: string): void {
            const actions = configDialog.currentContainmentActionsModel;
            if (eventString === current) {
                close();
                return;
            }
            if (actions.isTriggerUsed(eventString)) {
                taken = true;
                return;
            }
            if (row === -1) {
                actions.append(eventString, "org.kde.contextmenu");
            } else {
                actions.update(row, eventString, plugin);
            }
            close();
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 140
            radius: M3.classic ? M3.cornerCard : 16
            color: captureArea.containsMouse ? M3.secondaryContainer : M3.surfaceContainerHighest
            border.width: 1
            border.color: inputDialog.taken ? M3.error : M3.outlineVariant
            Behavior on color { ColorAnimation { duration: M3.durationShort4 } }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                MIcon {
                    Layout.alignment: Qt.AlignHCenter
                    size: 32
                    source: "input-mouse"
                    color: captureArea.containsMouse ? M3.secondaryContainerContent : M3.surfaceVariantContent
                }
                MText {
                    Layout.alignment: Qt.AlignHCenter
                    role: "labelLarge"
                    text: inputDialog.taken
                        ? root.tr("Another action already starts this way.")
                        : i18nd("plasma_shell_org.kde.plasma.desktop", "Input Here")
                    color: inputDialog.taken ? M3.error
                        : (captureArea.containsMouse ? M3.secondaryContainerContent : M3.surfaceVariantContent)
                }
            }

            MouseArea {
                id: captureArea
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                hoverEnabled: true

                onClicked: mouse => inputDialog.take(configDialog.currentContainmentActionsModel.mouseEventString(mouse.button, mouse.modifiers))
                onWheel: wheel => inputDialog.take(configDialog.currentContainmentActionsModel.wheelEventString(wheel))
            }
        }
    }

    UI.ChoiceDialog {
        id: pluginDialog
        property int row: -1
        property string action: ""
        title: root.tr("Action")
        options: root.pluginOptions
        onChosen: value => {
            if (value !== currentValue) {
                configDialog.currentContainmentActionsModel.update(row, action, value);
            }
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 20

        UI.Group {
            Layout.fillWidth: true

            Repeater {
                id: actionsRepeater
                model: configDialog.currentContainmentActionsModel

                delegate: UI.ListItem {
                    id: actionRow
                    required property int index
                    required property var model

                    icon: model.action.startsWith("wheel:") ? "input-mouse-click-middle" : "input-mouse"
                    title: root.pluginLabel(model.pluginName)
                    subtitle: root.triggerText(model.action)
                    onClicked: {
                        pluginDialog.row = index;
                        pluginDialog.action = model.action;
                        pluginDialog.currentValue = model.pluginName;
                        pluginDialog.open();
                    }

                    trailing: Component {
                        Row {
                            spacing: 0
                            UI.IconButton {
                                iconName: "input-mouse"
                                text: root.tr("Change trigger")
                                onClicked: inputDialog.start(actionRow.index, actionRow.model.action, actionRow.model.pluginName)
                            }
                            UI.IconButton {
                                iconName: "configure"
                                text: root.tr("Settings")
                                visible: actionRow.model.hasConfigurationInterface
                                onClicked: configDialog.currentContainmentActionsModel.showConfiguration(actionRow.index, this)
                            }
                            UI.IconButton {
                                iconName: "help-about-symbolic"
                                text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@title", "About")
                                onClicked: {
                                    const metaData = configDialog.currentContainmentActionsModel.aboutMetaData(actionRow.index);
                                    if (!metaData) {
                                        return;
                                    }
                                    aboutComponent.incubateObject(root.Window.window.contentItem, {
                                        "metaData": metaData,
                                        "title": i18ndc("plasma_shell_org.kde.plasma.desktop", "@title", "About"),
                                    }, Qt.Asynchronous);
                                }
                            }
                            UI.IconButton {
                                iconName: "list-remove"
                                text: root.tr("Remove")
                                onClicked: configDialog.currentContainmentActionsModel.remove(actionRow.index)
                            }
                        }
                    }
                }
            }
        }

        MButton {
            variant: "tonal"
            icon: "list-add"
            text: i18nd("plasma_shell_org.kde.plasma.desktop", "Add Action")
            onClicked: inputDialog.start(-1, "", "")
        }
    }
}
