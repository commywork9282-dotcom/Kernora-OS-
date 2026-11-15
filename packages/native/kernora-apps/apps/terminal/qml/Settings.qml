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

Rectangle {
    id: root

    property QtObject terminal: null
    readonly property QtObject settings: terminal ? terminal.settings : null
    property string section: "appearance"
    readonly property bool lightField: settings ? settings.lightField : false

    color: M3.surface

    Item {
        id: side
        width: Math.max(220, Math.min(320, root.width * 0.32))
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left

        MText {
            x: 28
            y: 28
            role: "titleLarge"
            text: i18n("Settings")
            color: M3.surfaceContent
        }

        Column {
            x: 12
            y: 80
            width: side.width - 24
            spacing: 4

            NavigationItem {
                title: i18n("Appearance")
                current: root.section === "appearance"
                leading: Component { MIcon { size: 22; source: "preferences-desktop-color"; color: root.section === "appearance" ? M3.secondaryContainerContent : M3.surfaceVariantContent } }
                onClicked: root.section = "appearance"
            }
            NavigationItem {
                title: i18n("Keyboard shortcuts")
                current: root.section === "shortcuts"
                leading: Component { MIcon { size: 22; source: "input-keyboard"; color: root.section === "shortcuts" ? M3.secondaryContainerContent : M3.surfaceVariantContent } }
                onClicked: root.section = "shortcuts"
            }
        }
    }

    Flickable {
        id: flick
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: side.right
        anchors.right: parent.right
        contentHeight: pane.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

        ColumnLayout {
            id: pane
            x: 12
            y: 20
            width: Math.min(flick.width - 36, 760)
            spacing: 16

            MText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.topMargin: 8
                role: "titleLarge"
                text: root.section === "appearance" ? i18n("Appearance") : i18n("Keyboard shortcuts")
                color: M3.surfaceContent
            }

            Rectangle {
                id: preview
                visible: root.section === "appearance"
                Layout.fillWidth: true
                Layout.preferredHeight: previewText.implicitHeight + 32
                radius: 16
                color: root.lightField ? "#ffffff" : "#000000"
                border.width: root.lightField ? 1 : 0
                border.color: M3.outlineVariant
                Text {
                    id: previewText
                    x: 16
                    y: 16
                    width: parent.width - 32
                    textFormat: Text.StyledText
                    font.family: root.settings ? root.settings.fontFamily : "DejaVu Sans Mono"
                    font.pointSize: root.settings ? root.settings.fontSize : 10
                    color: root.lightField ? "#1f1f1f" : "#ffffff"
                    readonly property string green: root.lightField ? "#346e02" : "#8ae234"
                    readonly property string blue: root.lightField ? "#204a87" : "#729fcf"
                    readonly property string prompt: "<b><font color=\"" + green + "\">" + (root.settings ? root.settings.prompt : "user@kernora") + "</font></b>:<b><font color=\"" + blue + "\">~</font></b>$ "
                    readonly property string cursor: !root.settings || root.settings.cursorShape === "block" ? "\u2588" : root.settings.cursorShape === "bar" ? "\u258f" : "_"
                    text: prompt + "ls<br><font color=\"" + blue + "\"><b>Desktop&nbsp;&nbsp;Documents&nbsp;&nbsp;Downloads&nbsp;&nbsp;Music&nbsp;&nbsp;Pictures</b></font><br>" + prompt + cursor
                }
            }

            Group {
                visible: root.section === "appearance"
                Layout.fillWidth: true

                ChoiceItem {
                    title: i18n("Font")
                    icon: "preferences-desktop-font"
                    options: root.settings ? root.settings.fontFamilies.map(family => ({ value: family, label: family })) : []
                    currentValue: root.settings ? root.settings.fontFamily : ""
                    onSelected: value => root.settings.fontFamily = value
                }
                SliderItem {
                    title: i18n("Font size")
                    icon: "format-font-size-more"
                    from: 6
                    to: 24
                    stepSize: 1
                    value: root.settings ? root.settings.fontSize : 10
                    formatValue: v => i18nc("font size in points", "%1 pt", Math.round(v))
                    onMoved: value => root.settings.fontSize = Math.round(value)
                }
                ChoiceItem {
                    title: i18n("Background")
                    icon: "color-picker"
                    options: [
                        { value: false, label: i18n("Black") },
                        { value: true, label: i18n("White") }
                    ]
                    currentValue: root.lightField
                    onSelected: value => root.settings.lightField = value
                }
                ChoiceItem {
                    title: i18n("Cursor")
                    icon: "edit-select-text"
                    options: [
                        { value: "block", label: i18n("Block") },
                        { value: "bar", label: i18n("Bar") },
                        { value: "underline", label: i18n("Underline") }
                    ]
                    currentValue: root.settings ? root.settings.cursorShape : "block"
                    onSelected: value => root.settings.cursorShape = value
                }
            }

            Group {
                visible: root.section === "shortcuts"
                Layout.fillWidth: true

                Repeater {
                    model: root.settings ? root.settings.shortcuts : []
                    delegate: ListItem {
                        id: row
                        required property var modelData
                        title: modelData.title
                        subtitle: modelData.enabled ? modelData.keys : i18n("Off")
                        onClicked: capture.begin(modelData)
                        trailing: Component {
                            RowLayout {
                                spacing: 4
                                MSwitch {
                                    checked: row.modelData.enabled
                                    onToggled: root.settings.setShortcutEnabled(row.modelData.id, checked)
                                }
                                IconButton {
                                    iconName: "configure"
                                    text: i18n("Change shortcut")
                                    onClicked: capture.begin(row.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: capture

        property var shortcut: ({})
        property int key: 0
        property int modifiers: 0
        property string error
        readonly property string conflict: key && root.settings ? root.settings.conflictFor(shortcut.id || "", key, modifiers) : ""

        title: shortcut.title || ""
        acceptText: i18n("Save")
        acceptEnabled: key !== 0 && error.length === 0 && conflict.length === 0
        preferredWidth: 440

        function begin(item): void {
            shortcut = item;
            key = 0;
            modifiers = 0;
            error = "";
            open();
            catcher.forceActiveFocus();
        }

        onOpened: catcher.forceActiveFocus()
        onAccepted: root.settings.setShortcutKeys(shortcut.id, key, modifiers)
        onClosed: if (root.terminal) root.terminal.focusTerminal()

        ColumnLayout {
            width: parent ? parent.width : 380
            spacing: 16

            MText {
                Layout.fillWidth: true
                role: "bodyMedium"
                wrapMode: Text.Wrap
                color: M3.surfaceVariantContent
                text: i18n("Press the new key combination.")
            }

            Rectangle {
                id: catcherBox
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 16
                color: M3.surfaceContainerHigh
                border.width: catcher.activeFocus ? 2 : 0
                border.color: M3.primary

                MText {
                    anchors.centerIn: parent
                    role: "titleMedium"
                    color: capture.key ? M3.surfaceContent : M3.surfaceVariantContent
                    text: capture.key && root.settings ? root.settings.keyText(capture.key, capture.modifiers) : (capture.shortcut.keys || "")
                }

                Item {
                    id: catcher
                    anchors.fill: parent
                    focus: true
                    Keys.onShortcutOverride: event => event.accepted = true
                    Keys.onPressed: event => {
                        const modifierKeys = [Qt.Key_Control, Qt.Key_Shift, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr, Qt.Key_CapsLock];
                        event.accepted = true;
                        if (modifierKeys.indexOf(event.key) >= 0) {
                            return;
                        }
                        const mods = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier | Qt.MetaModifier);
                        if (event.key === Qt.Key_Escape && mods === 0) {
                            capture.close();
                            return;
                        }
                        const functionKey = event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35;
                        capture.key = event.key;
                        capture.modifiers = mods;
                        capture.error = functionKey || (mods & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) ? "" : i18n("Add Ctrl, Alt or Meta, otherwise the key would stop typing in the terminal.");
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: catcher.forceActiveFocus()
                    }
                }
            }

            MText {
                Layout.fillWidth: true
                visible: text.length > 0
                role: "bodySmall"
                wrapMode: Text.Wrap
                color: capture.error.length > 0 || capture.conflict.length > 0 ? M3.error : M3.surfaceVariantContent
                text: capture.error.length > 0 ? capture.error : capture.conflict.length > 0 ? i18n("Already used for “%1”.", capture.conflict) : ""
            }

            MButton {
                visible: capture.shortcut.changed === true
                text: i18n("Restore default")
                variant: "text"
                onClicked: {
                    root.settings.resetShortcut(capture.shortcut.id);
                    capture.close();
                }
            }
        }
    }
}
