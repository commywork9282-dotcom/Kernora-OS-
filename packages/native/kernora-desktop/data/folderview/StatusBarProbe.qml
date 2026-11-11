/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window
import org.kernora.bartint

Item {
    id: probe

    property bool active: false
    property Item wallpaper: null
    property Item desktop: null
    property int strip: 0

    readonly property bool running: active && wallpaper !== null && desktop !== null && strip > 0
        && wallpaper.width > 0 && wallpaper.height > 0
    readonly property int sampleWidth: 192
    property var grab: null
    property int waits: 0
    property int rows: 1
    property bool scrim: false

    function linear(channel: real): real {
        return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
    }

    function region(data, from: int, to: int): var {
        let lightness = 0;
        let darkPixels = 0;
        let count = 0;
        for (let y = 0; y < probe.rows; ++y) {
            for (let x = from; x < to; ++x) {
                const i = (y * probe.sampleWidth + x) * 4;
                const alpha = data[i + 3] / 255;
                const r = data[i] / 255;
                const g = data[i + 1] / 255;
                const b = data[i + 2] / 255;
                lightness += (Math.max(r, g, b) + Math.min(r, g, b)) / 2 * alpha;
                const luminance = 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b);
                if (alpha > 0 && (luminance + 0.05) / 0.05 <= 5.5) {
                    darkPixels++;
                }
                count++;
            }
        }
        const mean = count > 0 ? lightness / count : 0;
        return { dark: count > 0 && mean > 0.7 && darkPixels <= count * 0.05, mean: mean };
    }

    function sample(): void {
        if (!probe.running) {
            return;
        }
        if (probe.grab !== null) {
            if (++probe.waits < 3) {
                return;
            }
            frame.source = "";
        }
        probe.waits = 0;
        const height = Math.max(1, Math.round(probe.sampleWidth * probe.wallpaper.height / probe.wallpaper.width));
        probe.rows = Math.max(1, Math.min(height, Math.ceil(probe.strip * height / probe.wallpaper.height)));
        probe.grab = {};
        const started = probe.wallpaper.grabToImage(result => {
            probe.grab = result;
            frame.source = result.url;
        }, Qt.size(probe.sampleWidth, height));
        if (!started) {
            probe.grab = null;
        }
    }

    function measure(): void {
        const context = canvas.getContext("2d");
        if (context && frame.status === Image.Ready) {
            context.clearRect(0, 0, canvas.width, canvas.height);
            context.drawImage(frame, 0, 0);
            const data = context.getImageData(0, 0, probe.sampleWidth, probe.rows).data;
            const left = region(data, 0, Math.round(probe.sampleWidth * 0.25));
            const right = region(data, Math.round(probe.sampleWidth * 0.7), probe.sampleWidth);
            BarTint.report(Screen.name, left.dark, right.dark);
            probe.scrim = (!left.dark && left.mean > 0.3) || (!right.dark && right.mean > 0.3);
        }
        frame.source = "";
        probe.grab = null;
    }

    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: probe.running
        onTriggered: probe.sample()
    }

    Image {
        id: frame
        visible: false
        cache: false
        onStatusChanged: {
            if (status === Image.Ready) {
                probe.measure();
            } else if (status === Image.Error) {
                source = "";
                probe.grab = null;
            }
        }
    }

    Canvas {
        id: canvas
        width: probe.sampleWidth
        height: 32
        visible: false
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
    }

    Rectangle {
        parent: probe.desktop
        z: -1
        width: parent ? parent.width : 0
        height: probe.strip * 2
        visible: opacity > 0
        opacity: probe.running && probe.scrim ? 1 : 0
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.4) }
            GradientStop { position: 1; color: "transparent" }
        }

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }
}
