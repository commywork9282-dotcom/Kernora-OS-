import QtQuick
import QtQuick.Layouts
import org.kernora.ui as UI

ColumnLayout {
    id: root
    property string title
    property bool cfg_fahrenheit
    property bool cfg_average

    function tr(text: string): string {
        return i18nd("plasma_applet_org.kernora.widget.cputemperature", text);
    }

    UI.Group {
        Layout.fillWidth: true
        title: root.tr("Units")
        UI.RadioRow {
            width: parent.width
            title: root.tr("Celsius (°C)")
            checked: !root.cfg_fahrenheit
            onClicked: root.cfg_fahrenheit = false
        }
        UI.RadioRow {
            width: parent.width
            title: root.tr("Fahrenheit (°F)")
            checked: root.cfg_fahrenheit
            onClicked: root.cfg_fahrenheit = true
        }
    }
    UI.Group {
        Layout.fillWidth: true
        title: root.tr("Reading")
        UI.RadioRow {
            width: parent.width
            title: root.tr("Hottest CPU sensor")
            checked: !root.cfg_average
            onClicked: root.cfg_average = false
        }
        UI.RadioRow {
            width: parent.width
            title: root.tr("Average CPU temperature")
            checked: root.cfg_average
            onClicked: root.cfg_average = true
        }
    }
    Item { Layout.fillHeight: true }
}
