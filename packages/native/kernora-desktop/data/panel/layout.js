var panel = new Panel;
panel.height = 56;
panel.floating = true;
panel.lengthMode = "fill";
panel.hiding = "none";
panel.opacity = "translucent";

var taken = [];
panels().forEach(function (other) {
    if (other.id !== panel.id) {
        other.widgets().forEach(function (widget) {
            taken.push(String(widget.globalShortcut));
        });
    }
});

var missing = false;

function addWidget(plugin, shortcut) {
    var widget = panel.addWidget(plugin);
    if (taken.indexOf(shortcut) < 0) {
        widget.globalShortcut = shortcut;
    }
    missing = missing || String(widget.globalShortcut) !== shortcut;
    return widget;
}

var launcher = addWidget("org.kernora.launcher", "Alt+Space");

panel.addWidget("org.kde.plasma.panelspacer");
panel.addWidget("org.kde.plasma.icontasks");
panel.addWidget("org.kde.plasma.panelspacer");

var tray = panel.addWidget("org.kde.plasma.systemtray");
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

panel.addWidget("org.kde.plasma.notifications");

addWidget("org.kernora.quicksettings", "Meta+A");

addWidget("org.kernora.clipboard", "Meta+V");
var emoji = addWidget("org.kernora.clipboard", "Meta+.");
emoji.currentConfigGroup = ["General"];
emoji.writeConfig("startPage", "emoji");

if (missing) {
    launcher.currentConfigGroup = ["General"];
    launcher.writeConfig("reclaimShortcuts", true);
    launcher.reloadConfig();
}
