var layoutConfig = ConfigFile("kernora-shellrc", "Layout");
panels().forEach(function (panel) {
    if (panel.widgets("org.kernora.datetime").length > 0) {
        panel.remove();
    }
});
panels().forEach(function (dock) {
    if (dock.widgets("org.kernora.launcher").length === 0 || dock.widgets("org.kernora.quicksettings").length > 0) {
        return;
    }
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
    var tray = dock.addWidget("org.kde.plasma.systemtray");
    var trayContainmentId = tray.readConfig("SystrayContainmentId");
    if (trayContainmentId) {
        var trayContainment = desktopById(trayContainmentId);
        trayContainment.currentConfigGroup = ["General"];
        trayContainment.writeConfig("knownItems", [
            "org.kde.plasma.battery",
            "org.kde.plasma.bluetooth",
            "org.kde.plasma.brightness",
            "org.kde.plasma.cameraindicator",
            "org.kde.plasma.clipboard",
            "org.kde.plasma.devicenotifier",
            "org.kde.plasma.keyboardlayout",
            "org.kde.plasma.manage-inputmethod",
            "org.kde.plasma.mediacontroller",
            "org.kde.plasma.networkmanagement",
            "org.kde.plasma.notifications",
            "org.kde.plasma.printmanager",
            "org.kde.plasma.vault",
            "org.kde.plasma.volume",
            "org.kde.kscreen",
            "org.kde.kdeconnect"
        ]);
        trayContainment.writeConfig("extraItems", []);
        trayContainment.writeConfig("scaleIconsToFit", false);
    }
    dock.addWidget("org.kde.plasma.notifications");
    var quick = dock.addWidget("org.kernora.quicksettings");
    quick.globalShortcut = "Meta+A";
    dock.lengthMode = "fill";
});
layoutConfig.writeEntry("style", "classic");
