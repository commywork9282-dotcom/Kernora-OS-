desktops().forEach(function (desktop) {
    if (desktop.wallpaperPlugin === "org.kernora.tower") {
        desktop.wallpaperPlugin = "org.kernora.shapes";
    }
});
