import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18nd("plasma_applet_org.kernora.widget.cputemperature", "Temperature")
        icon: "cpu"
        source: "ConfigGeneral.qml"
    }
}
