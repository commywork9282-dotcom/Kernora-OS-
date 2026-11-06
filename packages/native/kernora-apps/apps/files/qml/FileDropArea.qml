import QtQuick
import org.kernora.m3
import org.kernora.system

DropArea {
    id: root
    property url destination
    property var acceptsPosition: null
    signal filesDropped(var urls, url destination, int actions, point position)
    keys: ["text/uri-list"]
    onEntered: drag => {
        drag.accepted = (!acceptsPosition || acceptsPosition(drag.x, drag.y)) && (drag.supportedActions & Qt.CopyAction) !== 0
            && Files.transferError(drag.urls, destination).length === 0;
    }
    onDropped: drop => {
        if ((acceptsPosition && !acceptsPosition(drop.x, drop.y)) || !(drop.supportedActions & Qt.CopyAction)
            || Files.transferError(drop.urls, destination).length > 0) {
            drop.accepted = false;
            return;
        }
        const urls = [];
        for (const url of drop.urls) urls.push(String(url));
        const actions = drop.supportedActions;
        drop.accept(Qt.CopyAction);
        root.filesDropped(urls, destination, actions, mapToGlobal(drop.x, drop.y));
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: 16
        visible: root.containsDrag
        color: M3.withAlpha(M3.primary, 0.12)
        border.width: 2
        border.color: M3.primary
    }
}
