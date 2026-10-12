// SPDX-License-Identifier: GPL-2.0-or-later
// Run with KERNORA_QML_STORE pointing at this directory in a test session
// that has the Flathub/Debian catalogues. Does not change installed apps.
import QtQuick
import org.kernora.store

Window {
    visible: false
    property int attempts: 0
    property int stage: 0
    AppModel { id: results; search: "video" }
    AppModel { id: installed; filter: Store.Installed }
    AppModel { id: games; category: "games" }
    function require(condition, message) {
        if (!condition) {
            console.error("STORE_SMOKE_FAILED: " + message);
            Qt.quit();
            return false;
        }
        return true;
    }
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            if (++attempts > 240) {
                require(false, "catalogue timed out: " + Store.error);
                return;
            }
            if (!Store.ready || Store.loading) return;
            if (stage === 0) {
                if (!require(results.count > 10, "search truncated to ten results")) return;
                if (!require(games.count > 10, "games catalogue missing")) return;
                if (!require(installed.count === Store.installedCount, "installed count mismatch")) return;
                console.log("STORE_SMOKE: video=" + results.count + " games=" + games.count + " installed=" + installed.count);
                results.search = "kernora-this-app-does-not-exist-791827";
                stage = 1;
            } else if (stage === 1) {
                if (!require(results.count === 0, "search did not reset")) return;
                results.search = "telegram";
                stage = 2;
            } else {
                if (!require(results.count > 0, "Telegram search missing")) return;
                const id = results.idAt(0);
                const details = Store.details(id);
                if (!require(details.name && details.sources.length > 0, "app details missing")) return;
                console.log("STORE_SMOKE_OK: " + id);
                Qt.quit();
            }
        }
    }
}
