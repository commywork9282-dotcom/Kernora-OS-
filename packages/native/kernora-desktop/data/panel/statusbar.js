var layoutConfig = ConfigFile("kernora-shellrc", "Layout");
if (String(layoutConfig.readEntry("style")) !== "classic") {
    var docks = panels().filter(function (panel) {
        return panel.widgets("org.kernora.launcher").length > 0;
    });
    docks.forEach(function (dock) {
        ["org.kde.plasma.systemtray", "org.kde.plasma.notifications", "org.kernora.quicksettings"].forEach(function (type) {
            dock.widgets(type).forEach(function (widget) {
                widget.remove();
            });
        });
        if (dock.widgets("org.kde.plasma.panelspacer").length !== 2) {
            var saved = {};
            dock.widgets("org.kde.plasma.icontasks").forEach(function (tasks) {
                tasks.currentConfigGroup = ["General"];
                tasks.configKeys.forEach(function (key) {
                    saved[key] = tasks.readConfig(key);
                });
                tasks.remove();
            });
            dock.widgets("org.kde.plasma.panelspacer").forEach(function (spacer) {
                spacer.remove();
            });
            dock.addWidget("org.kde.plasma.panelspacer");
            var tasks = dock.addWidget("org.kde.plasma.icontasks");
            tasks.currentConfigGroup = ["General"];
            Object.keys(saved).forEach(function (key) {
                tasks.writeConfig(key, saved[key]);
            });
            tasks.reloadConfig();
            dock.addWidget("org.kde.plasma.panelspacer");
        }
        dock.lengthMode = "fill";
        var round = dock.widgets("org.kernora.launcher").some(function (launcher) {
            launcher.currentConfigGroup = ["General"];
            return String(launcher.readConfig("panelShape")) === "round";
        });
        if (!round) {
            dock.floating = false;
        }
    });
    var hasBar = panels().some(function (panel) {
        return panel.widgets("org.kernora.datetime").length > 0;
    });
    if (!hasBar && docks.length > 0) {
        loadTemplate("org.kernora.desktop.statusBar");
    }
    layoutConfig.writeEntry("style", "statusbar");
}
