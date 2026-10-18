/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui
import "keymaps.js" as Keymaps

Item {
    id: keyboardPage

    Rectangle {
        anchors.fill: parent
        color: M3.surface
    }

    readonly property var layoutsModel: config.keyboardLayoutsModel
    readonly property var variantsModel: config.keyboardVariantsModel
    readonly property var modelsModel: config.keyboardModelsModel
    readonly property var switchersModel: config.keyboardGroupsSwitchersModel

    property var layoutRows: []
    property var variantRows: []
    property var modelRows: []
    property var switcherRows: []

    component Rows: Instantiator {
        delegate: QtObject {
            required property string label
            required property string key
        }
        function rows(): var {
            const list = [];
            for (let i = 0; i < count; ++i) {
                const row = objectAt(i);
                list.push(row ? { label: row.label, key: row.key } : { label: "", key: "" });
            }
            return list;
        }
    }
    Rows { id: layoutItems; model: keyboardPage.layoutsModel; onObjectAdded: collect.restart(); onObjectRemoved: collect.restart() }
    Rows { id: variantItems; model: keyboardPage.variantsModel; onObjectAdded: collect.restart(); onObjectRemoved: collect.restart() }
    Rows { id: modelItems; model: keyboardPage.modelsModel; onObjectAdded: collect.restart(); onObjectRemoved: collect.restart() }
    Rows { id: switcherItems; model: keyboardPage.switchersModel; onObjectAdded: collect.restart(); onObjectRemoved: collect.restart() }
    Timer {
        id: collect
        interval: 0
        onTriggered: {
            keyboardPage.layoutRows = layoutItems.rows();
            keyboardPage.variantRows = variantItems.rows();
            keyboardPage.modelRows = modelItems.rows();
            keyboardPage.switcherRows = switcherItems.rows();
        }
    }

    function rowAt(rows: var, index: int): var {
        return index >= 0 && index < rows.length ? rows[index] : null;
    }
    readonly property var layoutRow: rowAt(layoutRows, layoutsModel.currentIndex)
    readonly property var variantRow: rowAt(variantRows, variantsModel.currentIndex)
    readonly property var modelRow: rowAt(modelRows, modelsModel.currentIndex)
    readonly property var switcherRow: rowAt(switcherRows, switchersModel.currentIndex)
        || switcherRows.find(row => row.key === "alt_shift_toggle") || null

    readonly property var labels: Keymaps.labels(layoutRow ? layoutRow.key : "us", variantRow ? variantRow.key : "")
    readonly property bool latin: /[A-Za-zÀ-ɏ]/.test(labels[30] ? labels[30][0] : "a")

    property var held: ({})
    readonly property bool shifted: held[42] === true || held[54] === true

    function press(code: int, down: bool): void {
        const next = Object.assign({}, held);
        if (down) {
            next[code] = true;
        } else {
            delete next[code];
        }
        held = next;
    }
    function codeOf(event: var): int {
        if (event.nativeScanCode > 8) {
            return event.nativeScanCode - 8;
        }
        for (const code in labels) {
            if (labels[code][0] === event.text || labels[code][1] === event.text) {
                return Number(code);
            }
        }
        return -1;
    }

    function type(text: string): void {
        if (text === "\b") {
            if (test.cursorPosition > 0) {
                test.remove(test.cursorPosition - 1, test.cursorPosition);
            }
        } else if (text.length > 0) {
            test.insert(test.cursorPosition, text);
        }
        test.forceActiveFocus();
    }

    property string language: Qt.locale().name.split("_")[0]
    function named(label: string): string {
        return Keymaps.name(label, language);
    }

    function withoutColon(text: string): string {
        return text.replace(/[:\s]+$/, "");
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        anchors.topMargin: 24
        anchors.bottomMargin: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            SelectField {
                Layout.preferredWidth: 3
                label: qsTr("Layout", "@label")
                value: keyboardPage.layoutRow ? keyboardPage.named(keyboardPage.layoutRow.label) : ""
                onClicked: layoutDialog.open()
            }
            SelectField {
                Layout.preferredWidth: 2
                label: qsTr("Variant", "@label")
                value: keyboardPage.variantRow ? keyboardPage.named(keyboardPage.variantRow.label) : ""
                enabled: keyboardPage.variantRows.length > 1
                onClicked: variantDialog.open()
            }
        }

        Rectangle {
            id: keyboard
            Layout.fillWidth: true
            implicitHeight: keyHeight * 5 + gap * 4 + padding * 2
            radius: 28
            color: M3.surfaceContainer

            readonly property real padding: 16
            readonly property real gap: 7
            readonly property real step: (width - padding * 2 + gap) / 15
            readonly property real keyHeight: Math.round(step - gap)

            readonly property var rows: {
                const character = code => ({ code: code, units: 1 });
                const special = (code, units, kind, icon, text) => ({ code: code, units: units, kind: kind, icon: icon || "", text: text || "" });
                const r = Keymaps.rows;
                return [
                    r[0].map(character).concat([special(14, 2, "action", "kernora-backspace")]),
                    [special(15, 1.5, "action", "kernora-key-tab")].concat(r[1].slice(0, 12).map(character), [{ code: 43, units: 1.5 }]),
                    [special(58, 1.75, "action", "kernora-key-capslock")].concat(r[2].map(character), [special(28, 2.25, "enter", "kernora-key-return")]),
                    [special(42, 2.25, "shift", "kernora-key-shift")].concat(r[3].map(character), [special(54, 2.75, "shift", "kernora-key-shift")]),
                    [special(29, 1.5, "action", "", "Ctrl"), special(56, 1.5, "action", "", "Alt"), special(57, 9, "space"),
                     special(100, 1.5, "action", "", "Alt"), special(97, 1.5, "action", "", "Ctrl")]
                ];
            }

            Column {
                x: keyboard.padding
                y: keyboard.padding
                spacing: keyboard.gap
                Repeater {
                    model: keyboard.rows
                    delegate: Row {
                        required property var modelData
                        spacing: keyboard.gap
                        Repeater {
                            model: parent.modelData
                            delegate: Key {
                                page: keyboardPage
                                board: keyboard
                                onTyping: text => keyboardPage.type(text)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: trial
            Layout.fillWidth: true
            implicitHeight: 56
            radius: 12
            color: M3.surfaceContainerHighest
            border.width: test.activeFocus ? 2 : 0
            border.color: M3.primary

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onPressed: test.forceActiveFocus(Qt.MouseFocusReason)
            }
            MIcon {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                size: 22
                source: "input-keyboard"
                color: M3.surfaceVariantContent
            }
            MText {
                x: 48
                anchors.verticalCenter: parent.verticalCenter
                visible: test.text.length === 0
                role: "bodyLarge"
                color: M3.surfaceVariantContent
                text: qsTranslate("Page_Keyboard", "Type here to test your keyboard")
            }
            TextInput {
                id: test
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 48
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                font: M3.bodyLarge
                renderType: Text.QtRendering
                color: M3.surfaceContent
                selectionColor: M3.primaryContainer
                selectedTextColor: M3.primaryContainerContent
                selectByMouse: true
                clip: true
                Keys.onPressed: event => {
                    const code = keyboardPage.codeOf(event);
                    if (code > 0 && !event.isAutoRepeat) {
                        keyboardPage.press(code, true);
                    }
                    event.accepted = false;
                }
                Keys.onReleased: event => {
                    const code = keyboardPage.codeOf(event);
                    if (code > 0 && !event.isAutoRepeat) {
                        keyboardPage.press(code, false);
                    }
                    event.accepted = false;
                }
                onActiveFocusChanged: if (!activeFocus) keyboardPage.held = ({})
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            SelectField {
                Layout.preferredWidth: 3
                label: keyboardPage.withoutColon(qsTranslate("Page_Keyboard", "Keyboard model:"))
                value: keyboardPage.modelRow ? keyboardPage.named(keyboardPage.modelRow.label) : ""
                onClicked: modelDialog.open()
            }
            SelectField {
                Layout.preferredWidth: 2
                visible: !keyboardPage.latin
                label: keyboardPage.withoutColon(qsTranslate("Page_Keyboard", "Switch Keyboard:"))
                value: keyboardPage.switcherRow ? keyboardPage.named(keyboardPage.switcherRow.label) : ""
                onClicked: switcherDialog.open()
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    component Key: AbstractButton {
        id: key
        required property var modelData
        property var page
        property var board
        signal typing(string text)
        readonly property int code: modelData.code
        readonly property string kind: modelData.kind || "character"
        readonly property var pair: kind === "character" ? (key.page.labels[code] || ["", ""]) : ["", ""]
        readonly property string typed: key.page.shifted && pair[1].length > 0 ? pair[1] : pair[0]
        readonly property string corner: !key.page.shifted && pair[1].length > 0 && pair[1] !== pair[0].toUpperCase() ? pair[1] : ""
        readonly property bool lit: key.page.held[code] === true || (kind === "shift" && key.page.shifted) || down

        width: modelData.units * key.board.step - key.board.gap
        height: key.board.keyHeight
        focusPolicy: Qt.NoFocus
        Accessible.name: typed

        onClicked: typing(kind === "character" ? typed.replace("◌", "") : kind === "space" ? " " : code === 14 ? "\b" : "")

        MMorph { id: litMorph; active: key.lit }
        background: Rectangle {
            readonly property real rest: key.kind === "space" ? height / 2 : 12
            radius: rest + (height / 2 - rest) * litMorph.value
            color: key.lit ? M3.primary
                : key.kind === "enter" ? M3.primaryContainer
                : key.kind === "character" || key.kind === "space" ? M3.surfaceContainerHighest
                : M3.secondaryContainer
            Behavior on color { ColorAnimation { duration: M3.durationShort3 } }
            MStateLayer {
                radius: parent.radius
                hovered: key.hovered
                pressed: false
                color: key.lit ? M3.primaryContent : M3.surfaceContent
            }
        }

        readonly property color ink: lit ? M3.primaryContent
            : kind === "enter" ? M3.primaryContainerContent
            : kind === "character" || kind === "space" ? M3.surfaceContent
            : M3.secondaryContainerContent

        contentItem: Item {
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: key.corner.length > 0 ? 3 : 0
                visible: key.kind === "character"
                text: key.typed
                color: key.ink
                font.family: M3.typeface
                font.pixelSize: Math.round(key.height * 0.42)
                renderType: Text.QtRendering
                Behavior on color { ColorAnimation { duration: M3.durationShort3 } }
            }
            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 7
                anchors.topMargin: 4
                visible: key.corner.length > 0
                text: key.corner
                color: key.lit ? key.ink : M3.surfaceVariantContent
                font.family: M3.typeface
                font.pixelSize: Math.round(key.height * 0.26)
                renderType: Text.QtRendering
            }
            MIcon {
                anchors.centerIn: parent
                visible: key.modelData.icon !== undefined && key.modelData.icon.length > 0
                size: Math.round(key.height * 0.5)
                source: key.modelData.icon || ""
                color: key.ink
            }
            Text {
                anchors.centerIn: parent
                visible: key.kind !== "character" && key.kind !== "space" && (key.modelData.text || "").length > 0
                text: key.modelData.text || ""
                color: key.ink
                font.family: M3.typeface
                font.pixelSize: Math.round(key.height * 0.3)
                font.weight: Font.Medium
                renderType: Text.QtRendering
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: key.kind === "space"
                text: key.page.layoutRow ? key.page.named(key.page.layoutRow.label) : ""
                color: key.lit ? key.ink : M3.surfaceVariantContent
                font.family: M3.typeface
                font.pixelSize: Math.round(key.height * 0.3)
                renderType: Text.QtRendering
            }
        }
    }

    component SelectField: AbstractButton {
        id: select
        property string label
        property string value
        Layout.fillWidth: true
        implicitHeight: 56
        padding: 0
        opacity: enabled ? 1 : 0.6
        Accessible.name: label + ": " + value

        background: Rectangle {
            radius: 12
            color: M3.surfaceContainerHighest
            border.width: select.visualFocus ? 2 : 0
            border.color: M3.primary
            MStateLayer {
                radius: 12
                hovered: select.hovered && select.enabled
                pressed: select.pressed
            }
        }
        contentItem: Item {
            MText {
                x: 16
                y: 8
                width: parent.width - 60
                role: "bodySmall"
                text: select.label
                elide: Text.ElideRight
                color: M3.surfaceVariantContent
            }
            MText {
                x: 16
                y: 26
                width: parent.width - 60
                role: "bodyLarge"
                text: select.value
                elide: Text.ElideRight
            }
            MIcon {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                size: 24
                source: "arrow-down"
                color: M3.surfaceVariantContent
            }
        }
    }

    function options(rows: var, keepFirst: bool): var {
        const list = rows.map((row, index) => ({ value: index, label: named(row.label) }));
        const head = keepFirst ? list.splice(0, 1) : [];
        const key = label => label.replace(/\)\s*$/, "");
        list.sort((a, b) => key(a.label).localeCompare(key(b.label)));
        return head.concat(list);
    }

    ChoiceDialog {
        id: layoutDialog
        title: qsTr("Layout", "@label")
        searchable: true
        options: keyboardPage.options(keyboardPage.layoutRows, false)
        currentValue: keyboardPage.layoutsModel.currentIndex
        onChosen: value => keyboardPage.layoutsModel.currentIndex = value
    }
    ChoiceDialog {
        id: variantDialog
        title: qsTr("Variant", "@label")
        options: keyboardPage.options(keyboardPage.variantRows, true)
        currentValue: keyboardPage.variantsModel.currentIndex
        onChosen: value => keyboardPage.variantsModel.currentIndex = value
    }
    ChoiceDialog {
        id: modelDialog
        title: keyboardPage.withoutColon(qsTranslate("Page_Keyboard", "Keyboard model:"))
        searchable: true
        options: keyboardPage.options(keyboardPage.modelRows, false)
        currentValue: keyboardPage.modelsModel.currentIndex
        onChosen: value => keyboardPage.modelsModel.currentIndex = value
    }
    ChoiceDialog {
        id: switcherDialog
        title: keyboardPage.withoutColon(qsTranslate("Page_Keyboard", "Switch Keyboard:"))
        searchable: true
        options: keyboardPage.options(keyboardPage.switcherRows, false)
        currentValue: keyboardPage.switcherRow ? keyboardPage.switcherRows.indexOf(keyboardPage.switcherRow) : -1
        onChosen: value => keyboardPage.switchersModel.currentIndex = value
    }

    function onActivate() {
        language = Qt.locale().name.split("_")[0];
        test.forceActiveFocus();
    }
    function onLeave() {
        held = ({});
    }
}
