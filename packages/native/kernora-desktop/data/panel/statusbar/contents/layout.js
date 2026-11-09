var bar = new Panel;
bar.location = "top";
bar.floating = false;
bar.lengthMode = "fill";
bar.hiding = "none";
bar.opacity = "adaptive";

var taken = [];
panels().forEach(function (other) {
    if (other.id !== bar.id) {
        other.widgets().forEach(function (widget) {
            taken.push(String(widget.globalShortcut));
        });
    }
});

bar.addWidget("org.kernora.datetime");
bar.addWidget("org.kde.plasma.panelspacer");

var tray = bar.addWidget("org.kde.plasma.systemtray");
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

bar.addWidget("org.kde.plasma.notifications");

var quick = bar.addWidget("org.kernora.quicksettings");
if (taken.indexOf("Meta+A") < 0) {
    quick.globalShortcut = "Meta+A";
}
