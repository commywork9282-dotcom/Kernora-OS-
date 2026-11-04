import QtQuick
import QtQuick.Layouts
import org.kernora.m3

Rectangle {
    id: card
    property real degrees: NaN
    property real peak: NaN
    property bool fahrenheit: false
    property var history: []
    property string heading
    property string caption
    property string unavailableText
    property string peakText
    property string historyText
    readonly property bool available: Number.isFinite(degrees)

    implicitWidth: 280
    implicitHeight: 256
    radius: M3.classic ? M3.cornerCard : 28
    color: M3.surfaceContainer
    clip: true
    Accessible.role: Accessible.StaticText
    Accessible.name: heading + ": " + (available ? value.text + unit.text : unavailableText)

    function display(value: real): string {
        return Math.round(fahrenheit ? value * 1.8 + 32 : value).toString();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: 12
                color: M3.secondaryContainer
                MIcon {
                    anchors.centerIn: parent
                    source: "cpu"
                    size: 20
                    color: M3.secondaryContainerContent
                }
            }
            MText {
                Layout.fillWidth: true
                text: card.heading
                role: "titleSmall"
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                id: value
                text: card.available ? card.display(card.degrees) : "—"
                color: M3.primary
                font.family: M3.typeface
                font.pixelSize: Math.min(60, card.height * 0.22)
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
                font.letterSpacing: -2
            }
            MText {
                id: unit
                visible: card.available
                text: card.fahrenheit ? "°F" : "°C"
                role: "headlineSmall"
                color: M3.primary
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 10
            }
            Item { Layout.fillWidth: true }
            MText {
                visible: card.available && Number.isFinite(card.peak)
                text: card.peakText + "\n" + card.display(card.peak) + (card.fahrenheit ? " °F" : " °C")
                role: "labelMedium"
                color: M3.surfaceVariantContent
                horizontalAlignment: Text.AlignRight
            }
        }

        MText {
            Layout.fillWidth: true
            text: card.available ? card.caption : card.unavailableText
            role: "labelMedium"
            color: M3.surfaceVariantContent
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Canvas {
            id: chart
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 26
            visible: card.available
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            property color lineColor: M3.primary
            property color baselineColor: M3.surfaceContainerHighest
            onLineColorChanged: requestPaint()
            onBaselineColorChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = baselineColor;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(0, height - 2);
                ctx.lineTo(width, height - 2);
                ctx.stroke();
                ctx.strokeStyle = lineColor;
                ctx.lineWidth = 2.5;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();
                let connected = false;
                for (let i = 0; i < card.history.length; ++i) {
                    const reading = card.history[i];
                    if (!Number.isFinite(reading)) {
                        connected = false;
                        continue;
                    }
                    const x = width * (60 - card.history.length + i) / 59;
                    const y = height - 3 - Math.max(0, Math.min(110, reading)) / 110 * (height - 6);
                    if (connected) ctx.lineTo(x, y);
                    else ctx.moveTo(x, y);
                    connected = true;
                }
                ctx.stroke();
            }
        }
        MText {
            Layout.fillWidth: true
            visible: card.available && card.height >= 244
            text: card.historyText
            role: "labelSmall"
            color: M3.surfaceVariantContent
        }
        Item { Layout.fillHeight: true; visible: !card.available }
    }
    onHistoryChanged: chart.requestPaint()
}
