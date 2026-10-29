/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import org.kde.ksysguard.formatter as Formatter
import org.kde.ksysguard.sensors as Sensors

Item {
    id: page

    property bool active: false

    readonly property string gpuName: String(gpuName1.value || gpuName0.value || SystemInfo.graphics || "")
    readonly property bool gpuReported: Number(gpuTotal.value) > 0

    function rate(first: var, second: var, sensor: var): string {
        const total = Number(first || 0) + Number(second || 0);
        return total > 0 ? Formatter.Formatter.formatValue(total, sensor.unit) : sensor.formattedValue;
    }

    Sensors.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: 1000 }
    Sensors.Sensor { id: cores; sensorId: "cpu/all/coreCount" }
    Sensors.Sensor { id: memoryUsed; sensorId: "memory/physical/used"; updateRateLimit: 1000 }
    Sensors.Sensor { id: memoryTotal; sensorId: "memory/physical/total" }
    Sensors.Sensor { id: memoryPercent; sensorId: "memory/physical/usedPercent"; updateRateLimit: 1000 }
    Sensors.Sensor { id: gpuUsage; sensorId: "gpu/all/usage"; updateRateLimit: 1000 }
    Sensors.Sensor { id: gpuUsed; sensorId: "gpu/all/usedVram"; updateRateLimit: 1000 }
    Sensors.Sensor { id: gpuTotal; sensorId: "gpu/all/totalVram" }
    Sensors.Sensor { id: gpuName0; sensorId: "gpu/gpu0/name" }
    Sensors.Sensor { id: gpuName1; sensorId: "gpu/gpu1/name" }
    Sensors.Sensor { id: diskRead; sensorId: "disk/all/read"; updateRateLimit: 1000 }
    Sensors.Sensor { id: diskWrite; sensorId: "disk/all/write"; updateRateLimit: 1000 }
    Sensors.Sensor { id: download; sensorId: "network/all/download"; updateRateLimit: 1000 }
    Sensors.Sensor { id: upload; sensorId: "network/all/upload"; updateRateLimit: 1000 }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: content.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            x: 24
            y: 24
            width: flick.width - 48
            spacing: 16

            MText {
                Layout.fillWidth: true
                role: "headlineSmall"
                text: i18n("Performance")
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 720 ? 2 : 1
                columnSpacing: 16
                rowSpacing: 16

                UsageCard {
                    title: i18n("CPU")
                    icon: "cpu"
                    amount: cpu.formattedValue
                    detail: {
                        const parts = [];
                        if (SystemInfo.cpu.length > 0) {
                            parts.push(SystemInfo.cpu);
                        }
                        if (Number(cores.value) > 0) {
                            parts.push(i18np("%1 core", "%1 cores", Number(cores.value)));
                        }
                        return parts.join(" · ");
                    }
                    first: Number(cpu.value || 0)
                }
                UsageCard {
                    title: i18n("Memory")
                    icon: "memory"
                    amount: memoryPercent.formattedValue
                    detail: i18n("%1 of %2 in use", memoryUsed.formattedValue, memoryTotal.formattedValue)
                    first: Number(memoryPercent.value || 0)
                }
                UsageCard {
                    title: i18n("Graphics")
                    icon: "video-display"
                    available: page.gpuReported
                    amount: page.gpuReported ? gpuUsage.formattedValue : "—"
                    detail: {
                        const parts = [];
                        if (page.gpuName.length > 0) {
                            parts.push(page.gpuName);
                        }
                        if (page.gpuReported) {
                            parts.push(i18n("%1 of %2 video memory", gpuUsed.formattedValue, gpuTotal.formattedValue));
                        }
                        return parts.join(" · ");
                    }
                    note: i18n("This graphics card doesn't report how busy it is.")
                    first: Number(gpuUsage.value || 0)
                }
                UsageCard {
                    title: i18n("Disk")
                    icon: "drive-harddisk"
                    percent: false
                    amount: page.rate(diskRead.value, diskWrite.value, diskRead)
                    detail: i18n("Read %1 · Write %2", diskRead.formattedValue, diskWrite.formattedValue)
                    first: Number(diskRead.value || 0)
                    second: Number(diskWrite.value || 0)
                    firstLabel: i18n("Read")
                    secondLabel: i18n("Write")
                }
                UsageCard {
                    title: i18n("Network")
                    icon: "network-wired"
                    percent: false
                    amount: page.rate(download.value, upload.value, download)
                    detail: i18n("Down %1 · Up %2", download.formattedValue, upload.formattedValue)
                    first: Number(download.value || 0)
                    second: Number(upload.value || 0)
                    firstLabel: i18n("Download")
                    secondLabel: i18n("Upload")
                }
            }
        }
    }

    MScrollIndicator {
        flickable: flick
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
}
