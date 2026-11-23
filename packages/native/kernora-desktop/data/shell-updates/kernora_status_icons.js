function kernoraStatusIcons(panel) {
    if (panel.location !== "top") {
        return;
    }
    var clocks = panel.widgets("org.kernora.datetime");
    var trays = panel.widgets("org.kde.plasma.systemtray");
    if (clocks.length === 0 || trays.length === 0) {
        return;
    }
    var group = panel.currentConfigGroup;
    panel.currentConfigGroup = ["General"];
    var original = String(panel.readConfig("AppletOrder", ""));
    var order = original.split(";");
    var clockId = String(clocks[0].id);
    var tray = trays[0];
    var trayId = String(tray.id);
    if (order.indexOf(clockId) >= 0 && order.indexOf(trayId) >= 0) {
        order = order.filter(function (id) { return id !== trayId; });
        order.splice(order.indexOf(clockId) + 1, 0, trayId);
        var updated = order.join(";");
        if (updated !== original) {
            panel.writeConfig("AppletOrder", updated);
            panel.reloadConfig();
        }
    }
    panel.currentConfigGroup = group;
}

if (String(ConfigFile("kernora-shellrc", "Layout").readEntry("style")) !== "classic") {
    panels().forEach(kernoraStatusIcons);
}
