import QtQuick
import org.kernora.m3

MouseArea {
    id: root
    objectName: "selectionRectangle"
    required property var view
    required property var model
    property var rectOf: null
    property var selection: ({})
    signal chosen(var selection)
    signal cleared()
    signal menuRequested()
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    property point origin
    property point cursor
    property var initialSelection: ({})
    property bool additive: false
    property bool selecting: false
    function updateSelection(): void {
        const start = mapToItem(view.contentItem, origin.x, origin.y - view.contentY);
        const end = mapToItem(view.contentItem, cursor.x, cursor.y);
        const x1 = Math.min(start.x, end.x);
        const x2 = Math.max(start.x, end.x);
        const y1 = Math.min(start.y, end.y);
        const y2 = Math.max(start.y, end.y);
        const next = additive ? Object.assign({}, initialSelection) : {};
        for (let i = 0; i < model.count; ++i) {
            const area = rectOf ? rectOf(i) : Qt.rect((i % view.columns) * view.cellWidth, Math.floor(i / view.columns) * view.cellHeight, view.cellWidth, view.cellHeight);
            if (area.x + area.width - 4 > x1 && area.x + 4 < x2 && area.y + area.height - 4 > y1 && area.y + 4 < y2) {
                next[String(model.get(i, "fileUrl"))] = true;
            }
        }
        chosen(next);
    }
    onPressed: event => {
        view.forceActiveFocus();
        additive = !!(event.modifiers & (Qt.ControlModifier | Qt.ShiftModifier));
        initialSelection = Object.assign({}, selection);
        origin = Qt.point(event.x, event.y + view.contentY);
        cursor = Qt.point(event.x, event.y);
        selecting = false;
        if (!additive) cleared();
        if (event.button === Qt.RightButton) menuRequested();
    }
    onPositionChanged: event => {
        if (pressedButtons !== Qt.LeftButton) return;
        cursor = Qt.point(event.x, event.y);
        if (Math.hypot(event.x - origin.x, event.y + view.contentY - origin.y) > Qt.styleHints.startDragDistance) selecting = true;
        if (selecting) updateSelection();
    }
    onReleased: selecting = false
    onCanceled: selecting = false
    Timer {
        interval: 30
        repeat: true
        running: root.selecting
        onTriggered: {
            const direction = root.cursor.y < 32 ? -1 : root.cursor.y > root.view.height - 32 ? 1 : 0;
            if (!direction) return;
            root.view.contentY = Math.max(root.view.originY, Math.min(root.view.originY + Math.max(0, root.view.contentHeight - root.view.height), root.view.contentY + direction * 16));
            root.updateSelection();
        }
    }
    Rectangle {
        visible: root.selecting
        x: Math.min(root.origin.x, root.cursor.x)
        y: Math.min(root.origin.y - root.view.contentY, root.cursor.y)
        width: Math.abs(root.cursor.x - root.origin.x)
        height: Math.abs(root.cursor.y - root.origin.y + root.view.contentY)
        radius: 4
        color: M3.withAlpha(M3.primary, 0.14)
        border.color: M3.primary
        border.width: 1
    }
}
