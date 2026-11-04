import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kernora.m3
import "widget" as Widget

ApplicationWindow {
    visible: true
    width: 940
    height: 440
    title: "Kernora · CPU temperature preview"
    color: M3.surface
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 18
        MText { text: "CPU temperature"; role: "headlineSmall" }
        MText {
            text: "Preview with sample readings · Celsius, Fahrenheit and no sensor"
            role: "bodyMedium"
            color: M3.surfaceVariantContent
        }
        RowLayout {
            spacing: 16
            Repeater {
                model: [0, 1, 2]
                Widget.TemperatureCard {
                    required property int modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 256
                    heading: "CPU temperature"
                    degrees: modelData === 2 ? NaN : 48
                    peak: 56
                    fahrenheit: modelData === 1
                    caption: "Hottest CPU sensor"
                    unavailableText: "CPU sensor unavailable"
                    peakText: "Peak"
                    historyText: "Last 2 minutes"
                    history: Array.from({length: 60}, (_, i) => 46 + 6 * Math.sin(i * 0.22) + 3 * Math.sin(i * 0.7))
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
