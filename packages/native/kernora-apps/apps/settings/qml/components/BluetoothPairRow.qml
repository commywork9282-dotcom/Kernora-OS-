pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kernora.ui
import "BluetoothNames.js" as BluetoothNames

ListItem {
    id: row
    required property var device
    property string pairingAddress: ""
    property string failedAddress: ""
    signal pairRequested(var device)

    title: BluetoothNames.deviceName(device) || i18n("Unnamed Bluetooth device")
    subtitle: pairingAddress === device.address ? i18n("Pairing…")
        : failedAddress === device.address ? i18n("Pairing failed. Try again.") : device.address
    icon: device.icon || "preferences-system-bluetooth"
    iconStyle: "plain"
    enabled: pairingAddress.length === 0 || pairingAddress === device.address
    trailing: Component {
        QQC2.BusyIndicator {
            visible: row.pairingAddress === row.device.address
            running: visible
            implicitWidth: 24
            implicitHeight: 24
        }
    }
    onClicked: pairRequested(device)
}
