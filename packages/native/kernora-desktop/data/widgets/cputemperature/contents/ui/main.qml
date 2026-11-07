import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root
    readonly property bool inPanel: Plasmoid.formFactor !== PlasmaCore.Types.Planar
    preferredRepresentation: inPanel ? null : fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    switchWidth: Plasmoid.configuration.placed ? 0 : 279
    switchHeight: Plasmoid.configuration.placed ? 0 : 255

    readonly property bool average: Plasmoid.configuration.average
    readonly property real reading: temperature.status === Sensors.Sensor.Ready
        && typeof temperature.value === "number" && Number.isFinite(temperature.value)
        && temperature.value > 0 && temperature.value < 200 ? temperature.value : NaN
    property real peak: NaN
    property var history: []

    toolTipMainText: i18n("CPU temperature")
    toolTipSubText: Number.isFinite(reading)
        ? Math.round(Plasmoid.configuration.fahrenheit ? reading * 1.8 + 32 : reading)
          + (Plasmoid.configuration.fahrenheit ? " °F" : " °C")
        : i18n("CPU sensor unavailable")

    onReadingChanged: {
        if (Number.isFinite(reading)) peak = Number.isFinite(peak) ? Math.max(peak, reading) : reading;
    }
    onAverageChanged: {
        history = [];
        peak = NaN;
    }

    Sensors.Sensor {
        id: temperature
        sensorId: root.average ? "cpu/all/averageTemperature" : "cpu/all/maximumTemperature"
        updateRateLimit: 2000
    }
    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            root.history = root.history.slice(-59).concat([root.reading]);
            if (Number.isFinite(root.reading))
                root.peak = Number.isFinite(root.peak) ? Math.max(root.peak, root.reading) : root.reading;
        }
    }
    fullRepresentation: TemperatureCard {
        Layout.preferredWidth: 280
        Layout.preferredHeight: 256
        Layout.minimumWidth: 240
        Layout.minimumHeight: 220
        Layout.maximumWidth: root.inPanel ? Layout.preferredWidth : Infinity
        Layout.maximumHeight: root.inPanel ? Layout.preferredHeight : Infinity
        degrees: root.reading
        peak: root.peak
        history: root.history
        fahrenheit: Plasmoid.configuration.fahrenheit
        heading: i18n("CPU temperature")
        caption: root.average ? i18n("Average CPU temperature") : i18n("Hottest CPU sensor")
        unavailableText: i18n("CPU sensor unavailable")
        peakText: i18n("Peak")
        historyText: i18n("Last 2 minutes")
    }
}
