    property int kernoraAuditCommand: -1
    property string kernoraAuditResult: ""
    Timer {
        interval: 500
        repeat: true
        running: isContainment && main.isRootView
        onTriggered: {
            const widgets = [];
            for (const child of root.appletsLayout.children) {
                if (child.applet && child.visible) {
                    const p = child.mapToItem(gridView, 0, 0);
                    widgets.push({x: p.x, y: p.y, width: child.width, height: child.height});
                }
            }
            const icons = [];
            for (let i = 0; i < gridView.count; ++i) {
                if (!positioner.isBlank(i)) {
                    const item = gridView.itemAtIndex(i);
                    icons.push({index: i, source: positioner.map(i), selected: dir.isSelected(positioner.map(i)),
                                x: item ? item.mapToItem(gridView, 0, 0).x : null, y: item ? item.mapToItem(gridView, 0, 0).y : null});
                }
            }
            const state = {result: main.kernoraAuditResult, time: Date.now(), command: main.kernoraAuditCommand, widgets: widgets, icons: icons,
                           width: gridView.width, height: gridView.height, cellWidth: gridView.cellWidth,
                           cellHeight: gridView.cellHeight, flow: gridView.flow,
                           rtl: gridView.effectiveLayoutDirection === Qt.RightToLeft, sortMode: main.sortMode,
                           perStripe: positioner.perStripe, enabled: positioner.enabled,
                           fixed: typeof iconLayout !== "undefined", current: gridView.currentIndex};
            const report = new XMLHttpRequest();
            report.open("POST", "http://10.0.2.2:8765/icon-layout-audit.json");
            report.send(JSON.stringify(state));
            const request = new XMLHttpRequest();
            request.onreadystatechange = function() {
                if (request.readyState !== XMLHttpRequest.DONE || request.status !== 200) {
                    return;
                }
                const command = JSON.parse(request.responseText);
                if (command.id === main.kernoraAuditCommand) {
                    return;
                }
                main.kernoraAuditCommand = command.id;
                const containers = [];
                for (const child of root.appletsLayout.children) {
                    if (child.applet && child.visible) {
                        containers.push(child);
                    }
                }
                const widget = containers[command.widget || 0];
                main.kernoraAuditResult = "widget=" + widget;
                try {
                if (command.action === "geometry" && widget) {
                    root.appletsLayout.releaseSpace(widget);
                    widget.x = command.x;
                    widget.y = command.y;
                    widget.width = command.width;
                    widget.height = command.height;

                } else if (command.action === "save" && widget) {
                    root.appletsLayout.positionItem(widget);
                    root.appletsLayout.save();
                } else if (command.action === "sort") {
                    main.sortMode = command.value;
                } else if (command.action === "flow") {
                    Plasmoid.configuration.arrangement = command.value;
                } else if (command.action === "rtl") {
                    Plasmoid.configuration.alignment = command.value;
                } else if (command.action === "select") {
                    dir.updateSelection(command.sources, false);
                    gridView.currentIndex = positioner.indexForUrl(command.url);
                } else if (command.action === "move") {
                    positioner.move([command.from, command.to]);
                }
                main.kernoraAuditResult += " | after=" + (widget ? widget.x + "," + widget.y : "missing");
                } catch (error) {
                    main.kernoraAuditResult += " | error=" + error;
                }
            };
            request.open("GET", "http://10.0.2.2:8765/icon-layout-command.json?t=" + Date.now());
            request.send();
        }
    }
