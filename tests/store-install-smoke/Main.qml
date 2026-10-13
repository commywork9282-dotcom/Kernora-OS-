import QtQuick
import org.kernora.store

Window {
    id: root
    visible: true
    width: 680
    height: 260
    title: "Store installation responsiveness test"
    property int target: 0
    property string appId: ""
    property string phase: "catalogue"
    property int seconds: 0
    property int pulses: 0
    property real lastPulse: Date.now()
    property real maxDelay: 0
    property int lastProgress: -2
    readonly property var targets: [
        { name: "galculator", source: "debian" },
        { name: "org.gnome.Calculator", source: "flatpak" }
    ]
    AppModel { id: nativeApps; search: "galculator" }
    AppModel { id: flatpakApps; search: "calculator" }
    Rectangle {
        anchors.fill: parent
        color: "#19141b"
        Text {
            anchors.centerIn: parent
            color: "#ffbd9e"
            font.pixelSize: 22
            text: root.phase + " " + root.appId + "\nHeartbeat: " + root.pulses + "  Max delay: " + root.maxDelay + " ms"
        }
        Rectangle {
            x: 25
            y: 25
            width: 20
            height: 20
            color: "#bd9ed7"
            NumberAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
        }
    }
    Connections {
        target: Store
        function onMessage(text) { console.log("INSTALL_MESSAGE", text); }
    }
    function fail(reason) {
        console.error("STORE_INSTALL_FAILED", phase, appId, reason);
        Qt.quit();
    }
    function findApp() {
        const model = target === 0 ? nativeApps : flatpakApps;
        for (let row = 0; row < model.count; ++row) {
            const id = model.idAt(row);
            if ((target === 0 && id.toLowerCase().indexOf("galculator") >= 0)
                || (target === 1 && id === "org.gnome.Calculator")) {
                const sources = Store.details(id).sources || [];
                for (const source of sources) {
                    if (source.key === targets[target].source) return id;
                }
            }
        }
        return "";
    }
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            const now = Date.now();
            const delay = now - root.lastPulse;
            if (delay > 1500) console.log("INSTALL_LONG_TICK", root.phase, root.appId, delay);
            root.maxDelay = Math.max(root.maxDelay, delay);
            root.lastPulse = now;
            ++root.pulses;
            if (root.pulses % 20 === 0) console.log("INSTALL_HEARTBEAT", root.phase, root.appId, root.pulses, "maxDelay=" + root.maxDelay);
        }
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            ++root.seconds;
            if (root.seconds > 900) { root.fail("timed out"); return; }
            if (root.phase === "catalogue") {
                if (!Store.ready || Store.loading) return;
                root.appId = root.findApp();
                if (!root.appId) { root.fail("app missing"); return; }
                const state = Store.state(root.appId);
                root.seconds = 0;
                if (state.installed) {
                    root.phase = "removing";
                    Store.remove(root.appId);
                    console.log("INSTALL_REMOVE_EXISTING", root.appId);
                } else {
                    root.phase = "starting";
                    Store.install(root.appId, root.targets[root.target].source);
                    console.log("INSTALL_START", root.appId, root.targets[root.target].source);
                }
                return;
            }
            const state = Store.state(root.appId);
            if (root.phase === "removing") {
                if (state.busy) return;
                if (state.installed) { root.fail("removal failed"); return; }
                root.phase = "starting";
                root.seconds = 0;
                Store.install(root.appId, root.targets[root.target].source);
                console.log("INSTALL_START", root.appId, root.targets[root.target].source);
                return;
            }
            if (state.busy) {
                root.phase = "installing";
                if (state.progress !== root.lastProgress) {
                    root.lastProgress = state.progress;
                    console.log("INSTALL_PROGRESS", root.appId, state.progress, state.status);
                }
                return;
            }
            if (!state.installed || state.installedSource !== root.targets[root.target].source) {
                root.fail("installation did not complete with requested source");
                return;
            }
            console.log("INSTALL_COMPLETE", root.appId, JSON.stringify(state));
            ++root.target;
            if (root.target === root.targets.length) {
                console.log("STORE_INSTALL_OK", "maxDelay=" + root.maxDelay, "pulses=" + root.pulses);
                Qt.quit();
            } else {
                root.appId = "";
                root.phase = "catalogue";
                root.seconds = 0;
                root.lastProgress = -2;
            }
        }
    }
}
