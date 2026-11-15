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
    readonly property var sections: [
        { id: "appearance", title: i18n("Appearance"), icon: "color-picker" },
        { id: "shortcuts", title: i18n("Keyboard shortcuts"), icon: "input-keyboard" },
        { id: "security", title: i18n("Security"), icon: "security-medium" },
        { id: "shared", title: i18n("Shared folders"), icon: "system-file-manager" },
        { id: "advanced", title: i18n("Advanced"), icon: "preferences-desktop" },
        { id: "recovery", title: i18n("Recovery"), icon: "view-history" }
    ]

    function shortPath(path: string): string {
        const home = settings ? settings.backupPath.replace(/\/\.local\/share\/kernora-terminal\/backup$/, "") : "";
        return home.length > 0 && path.startsWith(home) ? "~" + path.slice(home.length) : path;
    }
    function schemeName(id: string): string {
        const list = settings ? settings.schemes : [];
        const scheme = list.find(item => item.id === id);
        if (!scheme) {
            return "";
        }
        return scheme.preset ? i18nc("color scheme name", "%1 (preset)", scheme.name) : scheme.name;
    }

    color: M3.surface

    Connections {
        target: root.settings
        function onMessage(text) { snackbar.show(text, "", null); }
    }

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

            Repeater {
                model: root.sections
                delegate: NavigationItem {
                    id: navItem
                    required property var modelData
                    title: modelData.title
                    current: root.section === modelData.id
                    leading: Component {
                        MIcon {
                            size: 22
                            source: navItem.modelData.icon
                            color: navItem.current ? M3.secondaryContainerContent : M3.surfaceVariantContent
                        }
                    }
                    onClicked: root.section = modelData.id
                }
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

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.leftMargin: 4
                MText {
                    Layout.fillWidth: true
                    role: "titleLarge"
                    text: (root.sections.find(item => item.id === root.section) || {}).title || ""
                    color: M3.surfaceContent
                }
                MButton {
                    visible: root.section === "shared"
                    variant: "tonal"
                    icon: "list-add"
                    text: i18n("Add")
                    onClicked: root.settings.addSharedFolder()
                }
            }

            ColumnLayout {
                visible: root.section === "appearance"
                Layout.fillWidth: true
                spacing: 16

                Group {
                    title: i18n("Color scheme")
                    Layout.fillWidth: true
                    ListItem {
                        title: i18n("Light")
                        subtitle: root.schemeName(root.settings ? root.settings.lightScheme : "")
                        onClicked: { schemeDialog.mode = "light"; schemeDialog.open(); }
                    }
                    ListItem {
                        title: i18n("Dark")
                        subtitle: root.schemeName(root.settings ? root.settings.darkScheme : "")
                        onClicked: { schemeDialog.mode = "dark"; schemeDialog.open(); }
                    }
                    ListItem {
                        title: i18n("Download more color schemes")
                        subtitle: i18n("Please download color schemes in Alacritty format.")
                        onClicked: {
                            const text = root.settings.importSchemes();
                            if (text.length > 0) {
                                snackbar.show(text, "", null);
                            }
                        }
                    }
                }

                Group {
                    title: i18n("Font")
                    Layout.fillWidth: true
                    ListItem {
                        title: i18n("Font family")
                        subtitle: root.settings && root.settings.fontFamily.length > 0 ? root.settings.fontFamily : i18n("System default")
                        onClicked: fontDialog.open()
                    }
                    ListItem {
                        title: i18n("Font size")
                        subtitle: root.settings ? String(root.settings.fontSize) : ""
                        onClicked: sizeDialog.begin()
                    }
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
                        subtitle: modelData.keys
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

            ColumnLayout {
                visible: root.section === "security"
                Layout.fillWidth: true
                spacing: 16

                MText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    role: "bodyMedium"
                    wrapMode: Text.Wrap
                    color: M3.surfaceVariantContent
                    text: i18n("Port control: allow or deny listening ports. Other devices on your network can reach a port only after you allow it.")
                }

                Banner {
                    tone: "warning"
                    visible: root.settings ? root.settings.portsFailed : false
                    Layout.fillWidth: true
                    text: i18n("The network rules could not be changed.")
                }

                Group {
                    title: i18n("Listening ports")
                    Layout.fillWidth: true
                    ListItem {
                        visible: !root.settings || root.settings.listeningPorts.length === 0
                        interactive: false
                        title: i18n("No program in the terminal is waiting for connections.")
                    }
                    Repeater {
                        model: root.settings ? root.settings.listeningPorts : []
                        delegate: ListItem {
                            id: portRow
                            required property var modelData
                            title: modelData.process.length > 0 ? i18nc("port and program", "%1 (%2)", String(modelData.port), modelData.process) : String(modelData.port)
                            interactive: false
                            trailing: Component {
                                MSwitch {
                                    checked: portRow.modelData.allowed
                                    onToggled: root.settings.setPortAllowed(portRow.modelData.port, checked)
                                }
                            }
                        }
                    }
                }

                Group {
                    title: i18n("Saved allowed ports")
                    Layout.fillWidth: true
                    Repeater {
                        model: root.settings ? root.settings.allowedPorts : []
                        delegate: ListItem {
                            id: savedRow
                            required property var modelData
                            title: String(modelData)
                            interactive: false
                            trailing: Component {
                                IconButton {
                                    iconName: "window-close"
                                    text: i18nc("@action", "Delete %1", String(savedRow.modelData))
                                    onClicked: root.settings.removeAllowedPort(savedRow.modelData)
                                }
                            }
                        }
                    }
                    ListItem {
                        title: i18n("Add")
                        icon: "list-add"
                        iconStyle: "plain"
                        onClicked: portDialog.begin()
                    }
                }
            }

            ColumnLayout {
                visible: root.section === "shared"
                Layout.fillWidth: true
                spacing: 16

                MText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    role: "bodyMedium"
                    wrapMode: Text.Wrap
                    color: M3.surfaceVariantContent
                    text: i18n("Folders added here will be visible within /mnt/shared.")
                }

                Rectangle {
                    visible: !root.settings || root.settings.sharedFolders.length === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    radius: 24
                    color: M3.surfaceContainer
                    MText {
                        anchors.centerIn: parent
                        role: "bodyLarge"
                        color: M3.surfaceVariantContent
                        text: i18n("No folders are shared.")
                    }
                }

                Group {
                    visible: root.settings ? root.settings.sharedFolders.length > 0 : false
                    Layout.fillWidth: true
                    Repeater {
                        model: root.settings ? root.settings.sharedFolders : []
                        delegate: ListItem {
                            id: folderRow
                            required property string modelData
                            icon: "system-file-manager"
                            iconStyle: "plain"
                            title: modelData.split("/").filter(part => part.length > 0).pop() || "/"
                            subtitle: root.shortPath(modelData)
                            interactive: false
                            trailing: Component {
                                IconButton {
                                    iconName: "window-close"
                                    text: i18nc("@action", "Stop sharing")
                                    onClicked: root.settings.removeSharedFolder(folderRow.modelData)
                                }
                            }
                        }
                    }
                }
            }

            Group {
                visible: root.section === "advanced"
                Layout.fillWidth: true
                ChoiceItem {
                    title: i18n("Memory size")
                    dialogTitle: i18n("Memory size")
                    icon: "cpu"
                    iconStyle: "plain"
                    options: root.settings ? root.settings.memoryChoices : []
                    currentValue: root.settings ? root.settings.memoryLimit : 0
                    onSelected: value => root.settings.memoryLimit = value
                }
                ChoiceItem {
                    title: i18n("Keep awake")
                    dialogTitle: i18n("Keep awake")
                    icon: "preferences-system-power-management"
                    iconStyle: "plain"
                    options: [
                        { value: false, label: i18n("Off") },
                        { value: true, label: i18n("On") }
                    ]
                    currentValue: root.settings ? root.settings.keepAwake : false
                    onSelected: value => root.settings.keepAwake = value
                }
            }

            Group {
                visible: root.section === "recovery"
                Layout.fillWidth: true
                ListItem {
                    title: i18n("Reset to initial version")
                    subtitle: i18n("Remove all data")
                    icon: "edit-undo-history"
                    iconStyle: "plain"
                    onClicked: resetDialog.begin()
                }
                ListItem {
                    title: i18n("Remove backup data")
                    subtitle: i18n("Remove %1", root.shortPath(root.settings ? root.settings.backupPath : ""))
                    icon: "edit-delete"
                    iconStyle: "plain"
                    enabled: root.settings ? root.settings.backupExists : false
                    opacity: enabled ? 1 : 0.38
                    onClicked: {
                        const text = root.settings.removeBackup();
                        snackbar.show(text.length > 0 ? text : i18n("Backup data removed"), "", null);
                    }
                }
            }
        }
    }

    component ChoiceList: Dialog {
        id: choice
        property var options: []
        property var currentValue
        signal chosen(var value)
        preferredWidth: 420
        showAccept: false
        margins: 16

        onOpened: {
            const index = options.findIndex(option => option.value === currentValue);
            if (index >= 0) {
                choiceView.positionViewAtIndex(index, ListView.Center);
            }
        }

        ListView {
            id: choiceView
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(choice.options.length * 52, root.height - 220)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: choice.options
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            delegate: RadioRow {
                required property var modelData
                width: ListView.view.width
                title: modelData.label
                checked: modelData.value === choice.currentValue
                onClicked: {
                    choice.chosen(modelData.value);
                    choice.close();
                }
            }
        }
    }

    ChoiceList {
        id: fontDialog
        title: i18n("Font family")
        options: [{ value: "", label: i18n("System default") }].concat(root.settings ? root.settings.fontFamilies.map(family => ({ value: family, label: family })) : [])
        currentValue: root.settings ? root.settings.fontFamily : ""
        onChosen: value => root.settings.fontFamily = value
    }

    ChoiceList {
        id: schemeDialog
        property string mode: "dark"
        title: mode === "light" ? i18n("Light") : i18n("Dark")
        options: root.settings ? root.settings.schemes.map(scheme => ({ value: scheme.id, label: scheme.preset ? i18nc("color scheme name", "%1 (preset)", scheme.name) : scheme.name })) : []
        currentValue: root.settings ? (mode === "light" ? root.settings.lightScheme : root.settings.darkScheme) : ""
        onChosen: value => {
            if (mode === "light") {
                root.settings.lightScheme = value;
            } else {
                root.settings.darkScheme = value;
            }
        }
    }

    Dialog {
        id: sizeDialog
        property int size: 13
        title: i18n("Font size")
        acceptText: i18n("OK")
        preferredWidth: 360

        function begin(): void {
            size = root.settings ? root.settings.fontSize : 13;
            open();
        }

        onAccepted: root.settings.fontSize = size

        RowLayout {
            width: parent ? parent.width : 300
            spacing: 16
            Item { Layout.fillWidth: true }
            IconButton {
                iconName: "list-remove"
                text: i18n("Decrease font size")
                enabled: sizeDialog.size > 8
                onClicked: sizeDialog.size = Math.max(8, sizeDialog.size - 1)
            }
            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 56
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: M3.outline
                TextInput {
                    anchors.fill: parent
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 18
                    color: M3.surfaceContent
                    selectByMouse: true
                    validator: IntValidator { bottom: 1; top: 99 }
                    text: String(sizeDialog.size)
                    onTextEdited: if (acceptableInput) sizeDialog.size = Math.max(8, Math.min(48, parseInt(text)))
                }
            }
            IconButton {
                iconName: "list-add"
                text: i18n("Increase font size")
                enabled: sizeDialog.size < 48
                onClicked: sizeDialog.size = Math.min(48, sizeDialog.size + 1)
            }
            Item { Layout.fillWidth: true }
        }
    }

    Dialog {
        id: portDialog
        property string error
        title: i18n("Allow a new port")
        acceptText: i18n("Save")
        preferredWidth: 400

        function begin(): void {
            error = "";
            portField.text = "";
            open();
            portField.forceActiveFocus();
        }
        function accept(): void {
            const text = root.settings.addAllowedPort(portField.text);
            if (text.length > 0) {
                error = text;
                return;
            }
            accepted();
            close();
        }

        InputField {
            id: portField
            width: parent ? parent.width : 320
            label: i18n("Enter a new port number")
            errorText: portDialog.error
            onAccepted: portDialog.accept()
        }
    }

    Dialog {
        id: resetDialog
        property bool backup: false
        title: i18n("Reset terminal")
        text: i18n("Data will be removed")
        acceptText: i18n("Reset")
        destructive: true
        preferredWidth: 440

        function begin(): void {
            backup = false;
            open();
        }

        onAccepted: {
            const text = root.settings.resetToInitial(backup);
            snackbar.show(text.length > 0 ? text : i18n("Terminal reset to the initial version"), "", null);
        }

        RowLayout {
            width: parent ? parent.width : 380
            spacing: 12
            QQC2.CheckBox {
                checked: resetDialog.backup
                onToggled: resetDialog.backup = checked
            }
            MText {
                Layout.fillWidth: true
                role: "bodyMedium"
                wrapMode: Text.Wrap
                color: M3.surfaceContent
                text: i18n("Back up data to %1", root.shortPath(root.settings ? root.settings.backupPath : ""))
                MouseArea {
                    anchors.fill: parent
                    onClicked: resetDialog.backup = !resetDialog.backup
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

    Snackbar {
        id: snackbar
    }
}
