import QtQuick
import QtTest
import "widget" as Widget

Item {
    width: 800
    height: 600
    Widget.TemperatureCard {
        id: card
        width: 280
        height: 256
        heading: "CPU temperature"
        caption: "Hottest CPU sensor"
        unavailableText: "CPU sensor unavailable"
        peakText: "Peak"
        historyText: "Last 2 minutes"
    }
    TestCase {
        name: "TemperatureCard"
        when: windowShown
        function test_units() {
            card.fahrenheit = false;
            compare(card.display(48.4), "48");
            card.fahrenheit = true;
            compare(card.display(0), "32");
            compare(card.display(50), "122");
            card.fahrenheit = false;
        }
        function test_availability() {
            card.degrees = NaN;
            verify(!card.available);
            card.degrees = Infinity;
            verify(!card.available);
            card.degrees = 48;
            verify(card.available);
        }
        function test_render_data() {
            return [
                {tag: "celsius", value: 48, fahrenheit: false, width: 280, height: 256},
                {tag: "fahrenheit-small", value: 99, fahrenheit: true, width: 240, height: 220},
                {tag: "unavailable", value: NaN, fahrenheit: false, width: 280, height: 256},
                {tag: "large", value: 85, fahrenheit: false, width: 420, height: 300},
                {tag: "russian-small", value: 99, fahrenheit: true, width: 240, height: 220, russian: true}
            ];
        }
        function test_render(data) {
            card.heading = data.russian ? "Температура CPU" : "CPU temperature";
            card.caption = data.russian ? "Самый горячий датчик CPU" : "Hottest CPU sensor";
            card.peakText = data.russian ? "Максимум" : "Peak";
            card.degrees = data.value;
            card.fahrenheit = data.fahrenheit;
            card.width = data.width;
            card.height = data.height;
            card.peak = 101;
            card.history = [40, 45, NaN, 50, 48];
            waitForRendering(card);
            const image = grabImage(card);
            verify(image.width > 0 && image.height > 0);
            verify(Math.abs(image.width / image.height - data.width / data.height) < 0.02);
            const layout = card.children[0];
            verify(layout.implicitHeight <= card.height - 36,
                   "Card contents overflow: " + layout.implicitHeight + " > " + (card.height - 36));
        }
    }
}
