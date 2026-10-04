/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Arrange screens and more")

    Displays {
        id: displays
        onApplied: ok => {
            if (!ok) {
                page.notify(i18n("The display settings could not be applied."));
            }
        }
    }

    Instantiator {
        id: screenList
        model: displays
        delegate: QtObject {
            required property int index
            required property var model
            readonly property int row: index
            readonly property string label: displays.count > 1 ? i18n("%1. %2", index + 1, model.label) : model.label
            readonly property bool outputEnabled: model.enabled
            readonly property bool primary: model.primary
            readonly property var geometry: model.geometry
            readonly property int mirrorSource: model.mirrorSource
            readonly property var capabilities: model.capabilities
            readonly property int overscan: model.overscan
            readonly property int vrr: model.vrr
            readonly property int rgbRange: model.rgbRange
            readonly property bool hdr: model.hdr
            readonly property string colorProfile: model.colorProfile || ""
        }
    }

    readonly property var screens: {
        const list = [];
        for (let i = 0; i < screenList.count; ++i) {
            const item = screenList.objectAt(i);
            if (item && item.geometry) {
                list.push(item);
            }
        }
        return list;
    }
    readonly property var placed: screens.filter(s => s.outputEnabled && s.mirrorSource < 0)

    function snap(row: int, x: real, y: real): var {
        const self = placed.find(s => s.row === row);
        const w = self.geometry.width;
        const h = self.geometry.height;
        let best = null;
        for (const other of placed) {
            if (other.row === row) {
                continue;
            }
            const o = other.geometry;
            const clampY = Math.max(o.y - h + 1, Math.min(o.y + o.height - 1, y));
            const clampX = Math.max(o.x - w + 1, Math.min(o.x + o.width - 1, x));
            const candidates = [
                { x: o.x + o.width, y: clampY },
                { x: o.x - w, y: clampY },
                { x: clampX, y: o.y + o.height },
                { x: clampX, y: o.y - h }
            ];
            for (const c of candidates) {
                if (Math.abs(c.y - o.y) < 48) {
                    c.y = o.y;
                }
                if (Math.abs(c.x - o.x) < 48) {
                    c.x = o.x;
                }
                const distance = Math.hypot(c.x - x, c.y - y);
                if (!best || distance < best.distance) {
                    best = { x: Math.round(c.x), y: Math.round(c.y), distance: distance };
                }
            }
        }
        return best || { x: Math.round(x), y: Math.round(y) };
    }

    EmptyState {
        visible: displays.ready && page.screens.length < 2 && !page.screens.some(s => Object.values(s.capabilities || {}).some(v => v))
        icon: "preferences-desktop-display"
        title: i18n("Nothing more to set up")
        text: i18n("Connect another screen to arrange them, or use Display & brightness for this one.")
    }

    Rectangle {
        id: canvas
        width: parent.width
        height: 300
        visible: page.placed.length > 1
        radius: M3.classic ? M3.cornerCard : 28
        color: M3.surfaceContainerHigh

        readonly property var bounds: {
            let left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity;
            for (const s of page.placed) {
                const g = s.geometry;
                left = Math.min(left, g.x);
                top = Math.min(top, g.y);
                right = Math.max(right, g.x + g.width);
                bottom = Math.max(bottom, g.y + g.height);
            }
            return { x: left, y: top, width: Math.max(1, right - left), height: Math.max(1, bottom - top) };
        }
        readonly property real factor: Math.min((width - 96) / (bounds.width * 1.6), (height - 64) / (bounds.height * 1.6))
        readonly property real originX: (width - bounds.width * factor) / 2
        readonly property real originY: (height - bounds.height * factor) / 2

        Repeater {
            model: page.placed
            delegate: Rectangle {
                id: tile
                required property var modelData
                readonly property var g: modelData.geometry
                x: canvas.originX + (g.x - canvas.bounds.x) * canvas.factor
                y: canvas.originY + (g.y - canvas.bounds.y) * canvas.factor
                width: g.width * canvas.factor
                height: g.height * canvas.factor
                radius: 12
                color: mover.drag.active ? M3.primaryContainer : (modelData.primary ? M3.secondaryContainer : M3.surfaceContainerHighest)
                border.width: mover.drag.active ? 2 : 0
                border.color: M3.primary
                z: mover.drag.active ? 1 : 0

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    spacing: 2
                    MText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        role: "titleLarge"
                        text: String(tile.modelData.row + 1)
                        color: M3.surfaceContent
                    }
                    MText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        role: "labelMedium"
                        elide: Text.ElideRight
                        text: tile.modelData.label.replace(/^\d+\. /, "")
                        color: M3.surfaceVariantContent
                    }
                }

                MouseArea {
                    id: mover
                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: tile
                    drag.threshold: 4
                    onReleased: {
                        if (!drag.active && Math.abs(tile.x - (canvas.originX + (tile.g.x - canvas.bounds.x) * canvas.factor)) < 1) {
                            return;
                        }
                        const x = (tile.x - canvas.originX) / canvas.factor + canvas.bounds.x;
                        const y = (tile.y - canvas.originY) / canvas.factor + canvas.bounds.y;
                        const target = page.snap(tile.modelData.row, x, y);
                        tile.x = Qt.binding(() => canvas.originX + (tile.g.x - canvas.bounds.x) * canvas.factor);
                        tile.y = Qt.binding(() => canvas.originY + (tile.g.y - canvas.bounds.y) * canvas.factor);
                        displays.setPosition(tile.modelData.row, target.x, target.y);
                    }
                }

                Behavior on x {
                    enabled: !mover.drag.active
                    NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
                }
                Behavior on y {
                    enabled: !mover.drag.active
                    NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
                }
            }
        }
    }

    MText {
        width: parent.width
        visible: canvas.visible
        leftPadding: 16
        rightPadding: 16
        role: "bodySmall"
        color: M3.surfaceVariantContent
        wrapMode: Text.Wrap
        text: i18n("Drag a screen to where it stands on your desk. Screens snap to each other's edges.")
    }

    Group {
        title: i18n("Mirroring")
        visible: page.screens.filter(s => s.outputEnabled).length > 1

        Repeater {
            model: page.screens.filter(s => s.outputEnabled)
            delegate: ChoiceItem {
                required property var modelData
                title: modelData.label
                icon: "video-display"
                iconStyle: "plain"
                dialogTitle: i18n("What %1 shows", modelData.label)
                options: [{ value: -1, label: i18n("Its own picture") }]
                         .concat(page.screens.filter(s => s.outputEnabled && s.row !== modelData.row && s.mirrorSource < 0)
                                 .map(s => ({ value: s.row, label: i18n("The same as %1", s.label) })))
                currentValue: modelData.mirrorSource
                onSelected: value => displays.setMirror(modelData.row, value)
            }
        }
    }

    Repeater {
        model: page.screens.filter(s => s.outputEnabled)

        delegate: Group {
            id: screen
            required property var modelData
            readonly property int row: modelData.row
            readonly property var caps: modelData.capabilities || {}
            readonly property var values: modelData
            visible: caps.vrr || caps.rgbRange || caps.overscan || caps.hdr || caps.colorProfile
            title: page.screens.length > 1 ? modelData.label : i18n("Screen")

            ChoiceItem {
                title: i18n("Adaptive sync")
                visible: !!screen.caps.vrr
                icon: "view-refresh"
                iconStyle: "plain"
                options: [
                    { value: 2, label: i18n("In full-screen games and videos") },
                    { value: 1, label: i18n("Always") },
                    { value: 0, label: i18n("Never") }
                ]
                currentValue: screen.values.vrr
                onSelected: value => displays.setVrr(screen.row, value)
            }
            ChoiceItem {
                title: i18n("Colour range")
                visible: !!screen.caps.rgbRange
                icon: "color-management"
                iconStyle: "plain"
                options: [
                    { value: 0, label: i18n("Automatic") },
                    { value: 1, label: i18n("Full"), description: i18n("For computer monitors") },
                    { value: 2, label: i18n("Limited"), description: i18n("For TVs that show grey instead of black") }
                ]
                currentValue: screen.values.rgbRange
                onSelected: value => displays.setRgbRange(screen.row, value)
            }
            ListItem {
                title: i18n("HDR")
                subtitle: i18n("Brighter highlights in apps and videos that support it")
                visible: !!screen.caps.hdr
                icon: "preferences-desktop-display"
                iconStyle: "plain"
                checkable: true
                checked: !!screen.values.hdr
                onToggled: on => displays.setHdr(screen.row, on)
            }
            SliderItem {
                title: i18n("Overscan")
                visible: !!screen.caps.overscan
                icon: "zoom-fit-best"
                from: 0
                to: 100
                stepSize: 1
                value: screen.values.overscan
                formatValue: v => i18n("%1%", Math.round(v))
                onMoved: value => overscanApply.restart()
                Timer {
                    id: overscanApply
                    interval: 300
                    onTriggered: displays.setOverscan(screen.row, Math.round(parent.value))
                }
            }
            ListItem {
                title: i18n("Colour profile")
                subtitle: screen.values.colorProfile.length > 0 ? screen.values.colorProfile.split("/").pop() : i18n("None")
                visible: !!screen.caps.colorProfile
                icon: "color-management"
                iconStyle: "plain"
                chevron: true
                onClicked: profileDialog.open()

                FileDialog {
                    id: profileDialog
                    title: i18n("Choose a colour profile")
                    nameFilters: [i18n("Colour profiles (*.icc *.icm)")]
                    onAccepted: displays.setColorProfile(screen.row, decodeURIComponent(String(selectedFile).replace(/^file:\/\//, "")))
                }
            }
            ListItem {
                title: i18n("Remove the colour profile")
                visible: !!screen.caps.colorProfile && screen.values.colorProfile.length > 0
                icon: "edit-undo"
                iconStyle: "plain"
                onClicked: displays.setColorProfile(screen.row, "")
            }
        }
    }
}
