/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.private.volume as PA
import "m3"

ColumnLayout {
    id: panel

    required property QtObject backend
    signal back()
    signal requestClose()

    spacing: 12

    PA.SinkModel {
        id: sinks
    }
    PA.SourceModel {
        id: sources
    }

    PanelHeader {
        Layout.fillWidth: true
        title: i18n("Sound devices")
        onBack: panel.back()
    }

    MText {
        Layout.leftMargin: 8
        role: "titleSmall"
        color: M3.surfaceVariantContent
        text: i18n("Output")
    }

    PanelGroup {
        Layout.fillWidth: true

        MText {
            visible: sinkRepeater.count === 0
            width: parent.width
            topPadding: 12
            bottomPadding: 12
            horizontalAlignment: Text.AlignHCenter
            role: "bodyMedium"
            color: M3.surfaceVariantContent
            text: i18n("No speakers or headphones found.")
        }

        Repeater {
            id: sinkRepeater
            model: sinks
            delegate: PanelRow {
                required property var model
                width: parent.width
                icon: "audio-speakers"
                title: model.Description || model.Name || ""
                subtitle: model.Default ? i18n("In use") : ""
                active: model.Default === true
                onClicked: model.PulseObject.default = true
            }
        }
    }

    MText {
        Layout.leftMargin: 8
        role: "titleSmall"
        color: M3.surfaceVariantContent
        text: i18n("Input")
    }

    PanelGroup {
        Layout.fillWidth: true

        MText {
            visible: sourceRepeater.count === 0
            width: parent.width
            topPadding: 12
            bottomPadding: 12
            horizontalAlignment: Text.AlignHCenter
            role: "bodyMedium"
            color: M3.surfaceVariantContent
            text: i18n("No microphones found.")
        }

        Repeater {
            id: sourceRepeater
            model: sources
            delegate: PanelRow {
                required property var model
                width: parent.width
                icon: "audio-input-microphone"
                title: model.Description || model.Name || ""
                subtitle: model.Default ? i18n("In use") : ""
                active: model.Default === true
                onClicked: model.PulseObject.default = true
            }
        }
    }

    MButton {
        Layout.alignment: Qt.AlignRight
        variant: "tonal"
        icon: "configure"
        text: i18n("Sound settings")
        onClicked: {
            panel.backend.openSettings("sound");
            panel.requestClose();
        }
    }
}
