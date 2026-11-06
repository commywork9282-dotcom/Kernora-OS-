import QtQuick
import QtQuick.Controls as QQC2
import QtTest
import org.kde.bluezqt as BluezQt
import org.kernora.system
import "file:/usr/share/kernora/settings/pages" as Pages
import "file:/usr/share/kernora/settings/components/BluetoothNames.js" as Names

Item {
    width: 1060
    height: 780
QQC2.ApplicationWindow {
    id: scene
    width: 1060
    height: 780
    visible: true
    property bool narrow: false
    property bool canGoBack: true
    property int backs: 0
    property string message: ""
    function goBack() { ++backs; }
    function openPage(file, properties) {}
    function showMessage(text, action, callback) { message = text; }

    Component { id: pairFixture; Pages.BluetoothPairPage { width: scene.width; height: scene.height } }
    Component { id: pairedFixture; Pages.BluetoothPage { width: scene.width; height: scene.height } }
    Component { id: detailsFixture; Pages.BluetoothDevicePage { width: scene.width; height: scene.height } }
    Component { id: discoveryFixture; BluetoothDiscovery {} }
    TestCase {
        id: tests
        name: "BluetoothDevices"
        when: scene.visible
        property string address: "5A:D8:EE:B7:A7:E4"
        function control(method, args) {
            let finished = false;
            let success = false;
            let result;
            DBus.call("system", "org.bluez", "/", "org.kernora.BluetoothTest", method, args || [], (ok, value) => {
                success = ok;
                result = value;
                finished = true;
            });
            tryVerify(() => finished, 4000, "Control reply: " + method);
            verify(success, String(result));
            return result;
        }
        function counts() { return control("Counts"); }
        function ready(name) {
            control("AddAdapter", [name || "hci0"]);
            tryVerify(() => BluezQt.Manager.bluetoothOperational, 3000);
        }
        function page() {
            const result = createTemporaryObject(pairFixture, scene.contentItem);
            verify(result !== null);
            wait(50);
            return result;
        }
        function search(path) {
            const result = createTemporaryObject(discoveryFixture, scene.contentItem,
                                                 {adapterPath: path || "/org/bluez/hci0", active: true});
            verify(result !== null);
            return result;
        }
        function row(item, target) {
            const data = item.device || item.modelData;
            if (data && data.address === target && item.title !== undefined)
                return item;
            if (item.children) {
                for (const child of item.children) {
                    const found = row(child, target);
                    if (found) return found;
                }
            }
            return null;
        }
        function init() {
            control("Reset");
            tryVerify(() => BluezQt.Manager.adapters.length === 0, 3000);
            scene.backs = 0;
            scene.message = "";
            wait(50);
        }
        function test_name_data() {
            return [
                {tag:"address-colons", alias:address, remote:"", expected:""},
                {tag:"address-hyphens", alias:address.replace(/:/g,"-"), remote:"", expected:""},
                {tag:"address-compact", alias:address.replace(/:/g,""), remote:"", expected:""},
                {tag:"delayed-name", alias:address.replace(/:/g,"-"), remote:"Community Buds", expected:"Community Buds"},
                {tag:"custom-alias", alias:"My headphones", remote:"Vendor Headset", expected:"My headphones"},
                {tag:"short-advertised-name", alias:"NBEGN", remote:"NBEGN", expected:"NBEGN"},
                {tag:"led-controller", alias:"ELK-BLEDOM0B", remote:"ELK-BLEDOM0B", expected:"ELK-BLEDOM0B"},
                {tag:"hex-product-id", alias:"123456ABCDEF", remote:"", expected:"123456ABCDEF"},
                {tag:"remote-only", alias:"", remote:" Keyboard ", expected:"Keyboard"}
            ];
        }
        function test_name(data) {
            compare(Names.deviceName({name:data.alias, remoteName:data.remote, address:address}), data.expected);
        }
        function test_remote_name_arrives() {
            ready();
            control("AddDevice", [address, "", address.replace(/:/g,"-")]);
            const view = page();
            tryVerify(() => BluezQt.Manager.devices.length === 1);
            control("UpdateName", [address, "Community Buds"]);
            tryVerify(() => row(view, address) !== null, 3000);
            tryCompare(row(view, address), "title", "Community Buds", 3000);
            compare(BluezQt.Manager.devices[0].name, address.replace(/:/g,"-"));
        }
        function test_unnamed_devices_remain_accessible() {
            ready();
            control("AddDevice", [address, "", address.replace(/:/g,"-")]);
            const view = page();
            tryVerify(() => view.unnamed.length === 1);
            compare(row(view, address), null);
            view.showUnnamed = true;
            tryVerify(() => row(view, address) !== null);
            compare(row(view, address).title, "Unnamed Bluetooth device");
            compare(row(view, address).subtitle, address);
            control("UpdateName", [address, "Now named"]);
            tryCompare(view, "showUnnamed", true);
            tryVerify(() => view.unnamed.length === 0 && view.named.length === 1);
            compare(row(view, address).title, "Now named");
        }
        function test_custom_alias_survives_remote_update() {
            ready();
            control("AddDevice", [address, "Vendor model", "My headphones"]);
            const view = page();
            tryVerify(() => row(view, address) !== null);
            control("UpdateName", [address, "Vendor model revised"]);
            wait(50);
            compare(row(view, address).title, "My headphones");
        }
        function test_paired_and_details_names_update() {
            ready();
            control("AddDevice", [address, "", address.replace(/:/g,"-")]);
            tryVerify(() => BluezQt.Manager.devices.length === 1);
            const device = BluezQt.Manager.devices[0];
            device.pair();
            tryVerify(() => device.paired);
            const paired = createTemporaryObject(pairedFixture, scene.contentItem);
            const details = createTemporaryObject(detailsFixture, scene.contentItem, {device: device});
            verify(paired !== null && details !== null);
            tryVerify(() => row(paired, address) !== null);
            compare(row(paired, address).title, "Unnamed Bluetooth device");
            compare(details.title, "Unnamed Bluetooth device");
            control("UpdateName", [address, "Community Buds"]);
            tryCompare(details, "title", "Community Buds");
            tryVerify(() => row(paired, address).title === "Community Buds");
            device.name = "My renamed headphones";
            tryCompare(details, "title", "My renamed headphones");
            tryVerify(() => row(paired, address).title === "My renamed headphones");
        }
        function test_late_adapter() {
            const view = page();
            compare(counts().starts, 0);
            ready();
            tryVerify(() => counts().starts === 1, 3000);
            tryVerify(() => counts().sessions === 1, 3000);
            view.destroy();
            tryVerify(() => counts().sessions === 0, 3000);
        }
        function test_external_discovery_is_preserved() {
            ready();
            control("ExternalDiscovery", [true]);
            tryVerify(() => BluezQt.Manager.usableAdapter.discovering);
            const view = page();
            tryVerify(() => counts().starts === 1 && counts().sessions === 1, 3000);
            view.destroy();
            tryVerify(() => counts().sessions === 0, 3000);
            verify(counts().external);
            verify(BluezQt.Manager.usableAdapter.discovering);
        }
        function test_hidden_while_start_pending() {
            ready();
            control("DelayStart", [true]);
            const value = search();
            tryVerify(() => counts().pending === 1);
            value.active = false;
            control("ReleasePending");
            tryVerify(() => !value.busy && !value.scanning, 3000);
            compare(counts().sessions, 0);
            compare(counts().stops, 1);
        }
        function test_destroyed_while_start_pending() {
            ready();
            control("DelayStart", [true]);
            const value = search();
            tryVerify(() => counts().pending === 1);
            value.destroy();
            tryVerify(() => counts().pending === 0, 3000);
            control("ReleasePending");
            compare(counts().sessions, 0);
        }
        function test_rapid_reentry() {
            ready();
            control("DelayStart", [true]);
            const first = search();
            tryVerify(() => counts().pending === 1);
            first.destroy();
            const second = search();
            tryVerify(() => counts().starts === 2);
            control("ReleasePending");
            tryVerify(() => second.scanning && !second.busy, 3000);
            compare(counts().sessions, 1);
            second.destroy();
            tryVerify(() => counts().sessions === 0, 3000);
        }
        function test_adapter_switch_while_start_pending() {
            ready();
            ready("hci1");
            control("DelayStart", [true]);
            const value = search();
            tryVerify(() => counts().pending === 1);
            value.adapterPath = "/org/bluez/hci1";
            control("DelayStart", [false]);
            control("ReleasePending");
            tryVerify(() => value.scanning && !value.busy && counts().starts === 2, 3000);
            compare(counts().sessions, 1);
            compare(counts().stops, 1);
        }
        function test_retry_after_failure() {
            ready();
            control("FailNextStart");
            const value = search();
            tryVerify(() => value.errorString.length > 0 && !value.busy, 3000);
            compare(counts().starts, 1);
            compare(counts().sessions, 0);
            value.retry();
            tryVerify(() => value.scanning && !value.busy, 3000);
            compare(value.errorString, "");
            compare(counts().starts, 2);
        }
        function test_power_cycle_restarts_search() {
            ready();
            const view = page();
            tryVerify(() => counts().sessions === 1);
            control("SetPowered", [false]);
            tryVerify(() => !BluezQt.Manager.bluetoothOperational);
            tryVerify(() => counts().sessions === 0);
            control("SetPowered", [true]);
            tryVerify(() => counts().sessions === 1 && counts().starts === 2, 3000);
        }
        function test_signal_strength_does_not_reorder_devices() {
            ready();
            const second = "10:20:30:40:50:60";
            control("AddDevice", [address, "Alpha Buds", "Alpha Buds"]);
            control("AddDevice", [second, "Beta Buds", "Beta Buds"]);
            const view = page();
            tryVerify(() => view.found.length === 2);
            const before = view.found.map(device => device.address).join(",");
            control("SetRssi", [second, "-10"]);
            control("SetRssi", [address, "-90"]);
            wait(100);
            compare(view.found.map(device => device.address).join(","), before);
        }
        function test_visual_preview() {
            ready();
            control("AddDevice", [address, "Community Buds", "Community Buds"]);
            control("AddDevice", ["10:20:30:40:50:60", "Wireless Keyboard", "Wireless Keyboard"]);
            control("AddDevice", ["C4:F7:C1:05:57:CA", "", ""]);
            const view = page();
            tryVerify(() => view.named.length === 2 && view.unnamed.length === 1);
            wait(500);
            const image = grabImage(scene.contentItem);
            verify(image.width > 0 && image.height > 0);
            image.save("/tmp/kernora-bluetooth-preview.png");
        }
        function test_pair_targets_the_selected_device() {
            ready();
            const second = "10:20:30:40:50:60";
            control("AddDevice", [address, "Community Buds", "Community Buds"]);
            control("AddDevice", [second, "Community Buds", "Community Buds"]);
            const view = page();
            tryVerify(() => row(view, second) !== null);
            row(view, second).clicked();
            tryVerify(() => counts().pairs === 1 && scene.backs === 1, 3000);
            compare(counts().lastPaired, second);
            compare(scene.message, "Paired with Community Buds");
        }
    }
}
}
