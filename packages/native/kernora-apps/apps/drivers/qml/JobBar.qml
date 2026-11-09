/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui

Item {
    id: bar

    required property var window

    readonly property var job: window.job
    readonly property bool shown: window.busy
    readonly property bool measured: job.percent >= 0 && (job.step === "download" || job.step === "install" || job.step === "remove")
    readonly property string step: {
        if (!window.jobActive) {
            return window.nvidia.status === "removing" || window.nvidiaRequest === "remove"
                ? i18n("Removing the NVIDIA driver…") : i18n("Installing the NVIDIA driver…");
        }
        switch (job.step) {
        case "waiting":
            return i18n("Waiting for another install to finish…");
        case "preparing":
            return i18n("Getting ready…");
        case "download":
            return i18n("Downloading…");
        case "install":
            return i18n("Installing…");
        case "remove":
            return i18n("Removing…");
        case "undoing":
            return i18n("Something went wrong. Undoing the changes…");
        case "flash":
            return i18n("Updating firmware. Don't turn off the computer.");
        }
        return i18n("Getting ready…");
    }

    implicitHeight: shown ? content.implicitHeight + 32 : 0
    visible: shown
    Accessible.role: Accessible.ProgressBar
    Accessible.name: step

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MText {
                Layout.fillWidth: true
                role: "titleSmall"
                text: bar.window.jobActive && bar.window.jobTitle.length > 0
                      ? i18nc("%1 driver name, %2 what is happening", "%1: %2", bar.window.jobTitle, bar.step) : bar.step
                elide: Text.ElideRight
            }
            MText {
                visible: bar.measured
                role: "labelLarge"
                color: M3.surfaceVariantContent
                text: bar.measured ? i18nc("progress in percent", "%1%", bar.job.percent) : ""
            }
        }
        LinearProgress {
            Layout.fillWidth: true
            indeterminate: !bar.measured
            value: bar.measured ? bar.job.percent / 100 : 0
        }
    }
}
