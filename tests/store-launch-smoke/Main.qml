import QtQuick
import org.kernora.store

Window {
    visible: true
    width: 320
    height: 120
    title: "Store launcher regression"
    Component.onCompleted: console.log("STORE_LAUNCH_READY")
    property int attempts: 0
    AppModel { id: installed; search: "telegram"; filter: Store.Installed }
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            if (++attempts > 240) {
                console.error("STORE_LAUNCH_FAILED: catalogue timed out");
                Qt.quit();
                return;
            }
            if (attempts % 20 === 0) console.log("STORE_LAUNCH_WAIT", Store.ready, Store.loading, installed.count, Store.error);
            if (!Store.ready || Store.loading) return;
            let id = "";
            for (let index = 0; index < installed.count; ++index) {
                const candidate = installed.idAt(index);
                if (Store.state(candidate).installedSource === "flatpak") {
                    id = candidate;
                    break;
                }
            }
            if (!id) return;
            if (Store.launch("org.kernora.nonexistent-launch-fixture") || !Store.launch(id)) {
                console.error("STORE_LAUNCH_FAILED: incorrect launch result");
                Qt.quit();
                return;
            }
            running = false;
            exitTimer.start();
        }
    }
    Timer {
        id: exitTimer
        interval: 3000
        onTriggered: {
            console.log("STORE_LAUNCH_STARTED");
            Qt.quit();
        }
    }
}
