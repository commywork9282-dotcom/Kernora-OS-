var chosen = String(ConfigFile("kernora-setup-style", "Style").readEntry("wallpaper"));
var wallpaper = /^org\.kernora\.[a-z]+$/.test(chosen) ? chosen : "org.kernora.shapes";
var desktops = desktopsForActivity(currentActivity());
for (var i = 0; i < desktops.length; i++) {
    desktops[i].wallpaperPlugin = wallpaper;
}

loadTemplate("org.kde.plasma.desktop.defaultPanel");
if (String(ConfigFile("kernora-shellrc", "Layout").readEntry("style")) !== "classic") {
    loadTemplate("org.kernora.desktop.statusBar");
}
