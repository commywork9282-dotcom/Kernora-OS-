import QtQuick
import QtQml.Models
import org.kde.private.desktopcontainment.folder as Folder
import "IconPlacement.js" as Placement

Item {
    id: control

    required property var appletsLayout
    required property var grid
    required property var positioner
    required property var directory
    required property bool sorted
    property var obstacles: []
    property bool applying: false
    readonly property bool active: appletsLayout !== null && obstacles.length > 0

    function schedule() {
        if (!applying) {
            relayout.restart();
        }
    }

    function updateObstacles() {
        const rectangles = [];
        if (appletsLayout && grid) {
            for (const item of appletsLayout.children) {
                if (!item.applet || !item.visible || item.width <= 0 || item.height <= 0) {
                    continue;
                }
                const point = item.mapToItem(grid, 0, 0);
                rectangles.push({x: point.x - 4, y: point.y - 4,
                                 width: item.width + 8, height: item.height + 8});
            }
        }
        obstacles = rectangles;
    }

    function arrange() {
        updateObstacles();
        if (!appletsLayout || !grid.model || !positioner.enabled || directory.status !== Folder.FolderModel.Ready
                || grid.cellWidth <= 0 || grid.cellHeight <= 0) {
            return;
        }
        const items = [];
        const selected = [];
        const currentSource = positioner.map(grid.currentIndex);
        for (let i = 0; i < grid.count; ++i) {
            if (positioner.isBlank(i)) {
                continue;
            }
            const source = positioner.map(i);
            if (source < 0) {
                continue;
            }
            items.push({index: i, source: source});
            if (directory.isSelected(source)) {
                selected.push(source);
            }
        }
        const positions = Placement.arrange(items, obstacles, grid.width, grid.height,
                                            grid.cellWidth, grid.cellHeight,
                                            grid.flow === GridView.FlowLeftToRight,
                                            grid.effectiveLayoutDirection === Qt.RightToLeft, sorted);
        const moves = [];
        for (const item of positions) {
            if (item.from !== item.to) {
                moves.push(item.from, item.to);
            }
        }
        if (moves.length === 0) {
            return;
        }
        applying = true;
        positioner.move(moves, !sorted);
        directory.updateSelection(selected, false);
        grid.currentIndex = -1;
        if (currentSource >= 0) {
            for (let i = 0; i < grid.count; ++i) {
                if (positioner.map(i) === currentSource) {
                    grid.currentIndex = i;
                    break;
                }
            }
        }
        grid.forceLayout();
        applying = false;
    }

    onSortedChanged: schedule()
    onAppletsLayoutChanged: schedule()
    onActiveChanged: schedule()

    Timer {
        id: relayout
        interval: 0
        onTriggered: control.arrange()
    }

    Instantiator {
        model: control.appletsLayout ? control.appletsLayout.children : []
        delegate: Connections {
            required property var modelData
            target: modelData
            ignoreUnknownSignals: true
            function onXChanged() { control.schedule(); }
            function onYChanged() { control.schedule(); }
            function onWidthChanged() { control.schedule(); }
            function onHeightChanged() { control.schedule(); }
            function onVisibleChanged() { control.schedule(); }
            function onAppletChanged() { control.schedule(); }
        }
        onObjectAdded: control.schedule()
        onObjectRemoved: control.schedule()
    }

    Connections {
        target: control.grid
        function onWidthChanged() { control.schedule(); }
        function onHeightChanged() { control.schedule(); }
        function onCellWidthChanged() { control.schedule(); }
        function onCellHeightChanged() { control.schedule(); }
        function onFlowChanged() { control.schedule(); }
        function onEffectiveLayoutDirectionChanged() { control.schedule(); }
        function onCountChanged() { control.schedule(); }
        function onModelChanged() { control.schedule(); }
    }

    Connections {
        target: control.positioner
        function onDataChanged() { control.schedule(); }
        function onModelReset() { control.schedule(); }
        function onLayoutChanged() { control.schedule(); }
        function onEnabledChanged() { control.schedule(); }
    }

    Connections {
        target: control.directory
        function onListingCompleted() { control.schedule(); }
    }

    Component.onCompleted: schedule()
}
