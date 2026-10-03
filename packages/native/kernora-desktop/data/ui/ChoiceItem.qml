/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kernora.m3

ListItem {
    id: root

    property var options: []
    property var currentValue
    property string dialogTitle: title
    signal selected(var value)

    subtitle: {
        const option = options.find(o => o.value === currentValue);
        return option ? option.label : "";
    }
    chevron: false
    onClicked: dialog.open()

    ChoiceDialog {
        id: dialog
        title: root.dialogTitle
        options: root.options
        currentValue: root.currentValue
        onChosen: value => root.selected(value)
    }
}
