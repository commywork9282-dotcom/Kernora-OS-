var desktops = desktopsForActivity(currentActivity());
for (var i = 0; i < desktops.length; i++) {
    desktops[i].wallpaperPlugin = "org.kernora.shapes";
}

loadTemplate("org.kde.plasma.desktop.defaultPanel");
