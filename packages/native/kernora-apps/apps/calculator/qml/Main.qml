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
import org.kernora.system
import "engine.js" as Engine

AppWindow {
    id: app

    width: 420
    height: 680
    minimumWidth: 320
    minimumHeight: 520
    color: M3.surfaceContainer
    visible: true
    title: i18n("Calculator")

    readonly property bool wide: width >= 700
    property bool scientific: false
    property bool inverse: false
    ConfigEntry { id: degrees; file: "kernora-calculatorrc"; group: "General"; key: "Degrees"; defaultValue: true }
    readonly property bool useDegrees: degrees.value === true || degrees.value === "true"

    property string expression: ""
    property bool justEvaluated: false
    property string error: ""
    property var history: []
    readonly property string point: Qt.locale().decimalPoint

    readonly property string preview: {
        if (expression.length === 0 || error.length > 0) {
            return "";
        }
        try {
            const value = Engine.evaluate(expression, useDegrees);
            if (isNaN(value)) {
                return "";
            }
            const text = Engine.format(value, point);
            return text === display(expression) ? "" : text;
        } catch (e) {
            return "";
        }
    }

    function display(text: string): string {
        return text.replace(/\./g, point);
    }

    function press(key: string): void {
        error = "";
        const operators = ["+", "−", "×", "÷", "^"];
        if (justEvaluated) {
            if (!operators.includes(key) && key !== "%" && key !== "!") {
                expression = "";
            }
            justEvaluated = false;
        }
        if (operators.includes(key) && expression.length > 0 && operators.includes(expression.slice(-1)) && !(key === "−" && expression.slice(-1) !== "−")) {
            expression = expression.slice(0, -1);
        }
        if (key === ".") {
            const number = expression.match(/[0-9.]*$/)[0];
            if (number.includes(".")) {
                return;
            }
            if (number.length === 0) {
                key = "0.";
            }
        }
        expression += key;
    }
    function backspace(): void {
        error = "";
        justEvaluated = false;
        for (const name of ["sin⁻¹(", "cos⁻¹(", "tan⁻¹(", "sin(", "cos(", "tan(", "ln(", "log(", "√("]) {
            if (expression.endsWith(name)) {
                expression = expression.slice(0, -name.length);
                return;
            }
        }
        expression = expression.slice(0, -1);
    }
    function clearAll(): void {
        expression = "";
        error = "";
        justEvaluated = false;
    }
    function equals(): void {
        if (expression.length === 0) {
            return;
        }
        try {
            const value = Engine.evaluate(expression, useDegrees);
            if (isNaN(value)) {
                error = i18n("Not a number");
                return;
            }
            const result = Engine.format(value, ".");
            history = [{ expression: expression, result: result }].concat(history).slice(0, 50);
            expression = result;
            justEvaluated = true;
        } catch (e) {
            error = i18n("Can't calculate this");
        }
    }
    function copyResult(): void {
        clipboard.text = display(preview.length > 0 ? preview : expression);
        clipboard.selectAll();
        clipboard.copy();
        showMessage(i18n("Copied"), "", null);
    }

    TextEdit { id: clipboard; visible: false }

    Item {
        focus: true
        Keys.onPressed: event => {
            const text = event.text;
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || text === "=") {
                app.equals();
            } else if (event.key === Qt.Key_Backspace) {
                app.backspace();
            } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Delete) {
                app.clearAll();
            } else if (event.matches(StandardKey.Copy)) {
                app.copyResult();
            } else if (/^[0-9()!%^]$/.test(text)) {
                app.press(text);
            } else if (text === "." || text === ",") {
                app.press(".");
            } else if (text === "+") {
                app.press("+");
            } else if (text === "-") {
                app.press("−");
            } else if (text === "*") {
                app.press("×");
            } else if (text === "/") {
                app.press("÷");
            } else {
                return;
            }
            event.accepted = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 160
                radius: M3.classic ? M3.cornerCard : 28
                color: M3.surface

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    IconButton {
                        iconName: "view-history"
                        text: i18n("History")
                        checked: historyPanel.shown
                        onClicked: historyPanel.shown = !historyPanel.shown
                    }
                    Item { Layout.fillWidth: true }
                    QQC2.Button {
                        text: app.useDegrees ? i18n("DEG") : i18n("RAD")
                        flat: true
                        onClicked: degrees.value = !app.useDegrees
                    }
                    IconButton {
                        iconName: "edit-copy"
                        text: i18n("Copy the result")
                        enabled: app.expression.length > 0
                        onClicked: app.copyResult()
                    }
                    IconButton {
                        iconName: "kernora-backspace"
                        text: i18n("Delete")
                        enabled: app.expression.length > 0
                        onClicked: app.backspace()
                    }
                }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 24
                    spacing: 4

                    Text {
                        id: expressionText
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: app.expression.length > 0 ? app.display(app.expression) : "0"
                        color: app.justEvaluated ? M3.primary : M3.surfaceContent
                        font.family: M3.typeface
                        font.weight: Font.Normal
                        font.pixelSize: Math.round(Math.min(64, Math.max(28, 64 * 12 / Math.max(12, text.length))) * M3.scale)
                        renderType: Text.QtRendering
                        elide: Text.ElideLeft
                        Behavior on font.pixelSize { NumberAnimation { duration: M3.durationShort4 } }
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: app.error.length > 0 ? app.error : app.preview
                        color: app.error.length > 0 ? M3.error : M3.surfaceVariantContent
                        font.family: M3.typeface
                        font.pixelSize: Math.round(28 * M3.scale)
                        renderType: Text.QtRendering
                        elide: Text.ElideLeft
                    }
                }

                Rectangle {
                    id: historyPanel
                    property bool shown: false
                    anchors.fill: parent
                    radius: parent.radius
                    color: M3.surface
                    visible: shown
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        RowLayout {
                            IconButton { iconName: "go-previous"; text: i18n("Back"); onClicked: historyPanel.shown = false }
                            MText { Layout.fillWidth: true; role: "titleMedium"; text: i18n("History") }
                            QQC2.Button { text: i18n("Clear"); flat: true; visible: app.history.length > 0; onClicked: app.history = [] }
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: app.history
                            spacing: 4
                            delegate: QQC2.ItemDelegate {
                                required property var modelData
                                width: ListView.view.width
                                contentItem: ColumnLayout {
                                    spacing: 0
                                    MText { Layout.fillWidth: true; role: "bodyMedium"; color: M3.surfaceVariantContent; horizontalAlignment: Text.AlignRight; text: app.display(modelData.expression) }
                                    MText { Layout.fillWidth: true; role: "headlineSmall"; horizontalAlignment: Text.AlignRight; text: "= " + app.display(modelData.result) }
                                }
                                onClicked: {
                                    app.expression = modelData.result;
                                    app.justEvaluated = true;
                                    historyPanel.shown = false;
                                }
                            }
                            MText {
                                anchors.centerIn: parent
                                visible: app.history.length === 0
                                role: "bodyMedium"
                                color: M3.surfaceVariantContent
                                text: i18n("Results appear here")
                            }
                        }
                    }
                }
            }

            Item {
                id: scienceRow
                readonly property real keyWidth: (width - 8 * 3) / 4
                Layout.fillWidth: true
                Layout.preferredHeight: 44 * 3 + 16
                visible: !app.wide && app.scientific
                Grid {
                    anchors.fill: parent
                    columns: 4
                    spacing: 8
                    Repeater {
                        model: app.scientificKeys
                        delegate: CalcKey {
                            required property var modelData
                            width: scienceRow.keyWidth
                            height: 44
                            label: modelData.label
                            kind: "function"
                            onClicked: app.pressScientific(modelData)
                        }
                    }
                }
            }

            Item {
                id: keypad
                readonly property real keyWidth: (width - 30) / 4
                readonly property real keyHeight: Math.max(36, (height - 40) / 5)
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(250, Math.min(app.width * 1.1, app.height * 0.6))

                Grid {
                  anchors.fill: parent
                  columns: 4
                  rowSpacing: 10
                  columnSpacing: 10

                  Repeater {
                      model: [
                          { label: "AC", kind: "clear" }, { label: "( )", kind: "function" }, { label: "%", kind: "function" }, { label: "÷", kind: "operator" },
                          { label: "7" }, { label: "8" }, { label: "9" }, { label: "×", kind: "operator" },
                          { label: "4" }, { label: "5" }, { label: "6" }, { label: "−", kind: "operator" },
                          { label: "1" }, { label: "2" }, { label: "3" }, { label: "+", kind: "operator" },
                          { label: app.wide ? "0" : "⋯", kind: app.wide ? "digit" : "function" }, { label: app.wide ? "00" : "0" }, { label: app.point, value: "." }, { label: "=", kind: "equals" }
                      ]
                      delegate: CalcKey {
                          required property var modelData
                          width: keypad.keyWidth
                          height: keypad.keyHeight
                          label: modelData.label
                          kind: modelData.kind || "digit"
                          onClicked: {
                              const label = modelData.label;
                              if (label === "AC") {
                                  app.clearAll();
                              } else if (label === "=") {
                                  app.equals();
                              } else if (label === "⋯") {
                                  app.scientific = !app.scientific;
                              } else if (label === "( )") {
                                  app.bracket();
                              } else {
                                  app.press(modelData.value || label);
                              }
                          }
                          onPressAndHold: {
                              if (modelData.label === "AC") {
                                  app.clearAll();
                              }
                          }
                      }
                  }
                }
            }
        }

        Item {
            id: sciencePad
            readonly property real keyWidth: (width - 20) / 3
            readonly property real keyHeight: Math.max(36, (height - 30) / 4)
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            visible: app.wide
            Grid {
                anchors.fill: parent
                columns: 3
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    model: app.scientificKeys
                    delegate: CalcKey {
                        required property var modelData
                        width: sciencePad.keyWidth
                        height: sciencePad.keyHeight
                        label: modelData.label
                        kind: "function"
                        onClicked: app.pressScientific(modelData)
                    }
                }
            }
        }
    }

    Shortcut { sequence: "Ctrl+Backspace"; onActivated: app.clearAll() }

    readonly property var scientificKeys: [
        { label: app.inverse ? "sin⁻¹" : "sin", insert: (app.inverse ? "sin⁻¹" : "sin") + "(" },
        { label: app.inverse ? "cos⁻¹" : "cos", insert: (app.inverse ? "cos⁻¹" : "cos") + "(" },
        { label: app.inverse ? "tan⁻¹" : "tan", insert: (app.inverse ? "tan⁻¹" : "tan") + "(" },
        { label: "INV", toggle: true },
        { label: app.inverse ? "eˣ" : "ln", insert: app.inverse ? "e^(" : "ln(" },
        { label: app.inverse ? "10ˣ" : "log", insert: app.inverse ? "10^(" : "log(" },
        { label: app.inverse ? "x²" : "√", insert: app.inverse ? "^2" : "√(" },
        { label: "xʸ", insert: "^" },
        { label: "π", insert: "π" },
        { label: "e", insert: "e" },
        { label: "!", insert: "!" },
        { label: "⌫", backspace: true }
    ]

    function pressScientific(key: var): void {
        if (key.toggle) {
            inverse = !inverse;
        } else if (key.backspace) {
            backspace();
        } else {
            if (justEvaluated && !key.insert.startsWith("^") && key.insert !== "!") {
                expression = "";
            }
            justEvaluated = false;
            error = "";
            expression += key.insert;
        }
    }

    function bracket(): void {
        const open = (expression.match(/\(/g) || []).length - (expression.match(/\)/g) || []).length;
        const last = expression.slice(-1);
        if (open > 0 && /[0-9)πe!%.]/.test(last)) {
            press(")");
        } else {
            press("(");
        }
    }

    component CalcKey: QQC2.AbstractButton {
        id: key
        property string label
        property string kind: "digit"
        readonly property color fill: kind === "equals" ? M3.primary
            : kind === "operator" ? M3.secondaryContainer
            : kind === "clear" ? M3.tertiaryContainer
            : kind === "function" ? M3.surfaceContainerHigh
            : M3.surfaceContainerHighest
        readonly property color ink: kind === "equals" ? M3.primaryContent
            : kind === "operator" ? M3.secondaryContainerContent
            : kind === "clear" ? M3.tertiaryContainerContent
            : M3.surfaceContent
        focusPolicy: Qt.NoFocus
        Accessible.name: label
        contentItem: Item {}
        MMorph { id: pressMorph; active: key.pressed && !M3.classic }
        background: Rectangle {
            readonly property real round: Math.min(width, height) / 2
            radius: Math.max(0, round + (Math.min(width, height) * 0.24 - round) * pressMorph.value)
            color: key.fill
            MStateLayer {
                radius: parent.radius
                color: key.ink
                hovered: key.hovered
                pressed: key.pressed
            }
            Text {
                anchors.centerIn: parent
                text: key.label
                color: key.ink
                font.family: M3.typeface
                font.pixelSize: Math.round((key.kind === "function" ? 20 : 30) * M3.scale)
                renderType: Text.QtRendering
            }
        }
    }
}
