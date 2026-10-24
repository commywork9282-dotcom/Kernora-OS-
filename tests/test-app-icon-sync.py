import importlib.machinery
import importlib.util
import os
from pathlib import Path
import tempfile

os.environ["QT_QPA_PLATFORM"] = "offscreen"
from PyQt6.QtGui import QGuiApplication, QImage, QColor

root = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("icon_sync", str(root / "packages/native/kernora-apps/data/icons/kernora-app-icons"))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)
application = QGuiApplication([])


def put(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


with tempfile.TemporaryDirectory() as directory:
    temporary = Path(directory)
    home = temporary / "user"
    system = temporary / "system"
    flatpak = temporary / "flatpak"
    settings = temporary / "config"
    os.environ["XDG_CONFIG_HOME"] = str(settings)
    put(settings / "kdeglobals", "[Icons]\nTheme=hicolor\n[General]\nColorScheme=KernoraDark\n")
    put(settings / "kernorarc", "[Style]\ncolour=kernora\ngeneration=md3\n")
    palette = system / "kernora/palettes/kernora.conf"
    put(palette, "[md3-dark]\nprimaryContainer=112233\nprimaryContainerContent=ffeedd\n[md3-light]\nprimaryContainer=ccddee\nprimaryContainerContent=332211\n")
    image = QImage(32, 32, QImage.Format.Format_ARGB32)
    image.fill(QColor("red"))
    image.setPixelColor(16, 16, QColor("black"))
    absolute = temporary / "original.png"
    image.save(str(absolute))
    icon_folder = system / "icons/hicolor/32x32/apps"
    icon_folder.mkdir(parents=True)
    image.save(str(icon_folder / "downloaded.png"))
    put(system / "icons/hicolor/index.theme", "[Icon Theme]\nName=hicolor\nDirectories=32x32/apps\n[32x32/apps]\nSize=32\nType=Fixed\nContext=Applications\n")
    desktop = "[Desktop Entry]\nType=Application\nName=Downloaded\nExec=true\nIcon=downloaded\n"
    original_image = absolute.read_bytes()
    absolute_desktop = desktop.replace("Icon=downloaded", "Icon=" + str(absolute)) + "\n[Desktop Action New]\nName=New\nExec=true\nIcon=" + str(absolute) + "\n"
    put(system / "applications/downloaded.desktop", desktop)
    absolute_desktop += "Icon[ru]=" + str(absolute) + "\n"
    put(system / "applications/absolute.desktop", absolute_desktop)
    put(home / "applications/local.desktop", absolute_desktop)
    linked = temporary / "linked.desktop"
    put(linked, absolute_desktop)
    (home / "applications/symlink.desktop").symlink_to(linked)
    svg = temporary / "vector.svg"
    put(svg, '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><path d="M4 4h24v24H4z" fill="red"/></svg>')
    put(system / "applications/vector.desktop", desktop.replace("Icon=downloaded", "Icon=" + str(svg)))
    put(flatpak / "applications/org.example.Flatpak.desktop", desktop)
    put(system / "applications/missing.desktop", desktop.replace("Icon=downloaded", "Icon=missing-icon-123"))
    synchronizer = module.IconSync(home, [home, system, flatpak], notify=False)
    synchronizer.sync()
    themed = home / "icons/KernoraAutoApps/128x128/apps/downloaded.png"
    assert themed.exists()
    assert QImage(str(themed)).pixelColor(64, 5).name() == "#112233"
    assert absolute.read_bytes() == original_image
    before = themed.read_bytes()
    generated_local = (home / "applications/local.desktop").read_text()
    assert str(absolute) not in generated_local
    assert "Icon=kernora-auto-" in generated_local
    assert "[Desktop Action New]" in generated_local
    assert (home / "applications/vector.desktop").exists()
    assert (system / "applications/absolute.desktop").read_text() == absolute_desktop
    assert not (home / "applications/missing.desktop").exists()
    assert not (home / "applications/downloaded.desktop").exists()
    stamp = themed.stat().st_mtime_ns
    synchronizer.sync()
    assert themed.stat().st_mtime_ns == stamp
    synchronizer = module.IconSync(home, [home, system, flatpak], notify=False)
    synchronizer.sync()
    assert (home / "applications/local.desktop").read_text() == generated_local
    put(system / "applications/new.desktop", absolute_desktop.replace("Name=Downloaded", "Name=New"))
    synchronizer.sync()
    assert (home / "applications/new.desktop").exists()
    updated = absolute_desktop.replace("Exec=true", "Exec=/usr/bin/true --version")
    put(system / "applications/absolute.desktop", updated)
    synchronizer.sync()
    assert "--version" in (home / "applications/absolute.desktop").read_text()
    (system / "applications/new.desktop").unlink()
    synchronizer.sync()
    assert not (home / "applications/new.desktop").exists()
    put(settings / "kdeglobals", "[Icons]\nTheme=KernoraAutoApps\n[General]\nColorScheme=KernoraLight\n")
    synchronizer.sync()
    assert themed.read_bytes() != before
    assert QImage(str(themed)).pixelColor(64, 5).name() == "#ccddee"
    edited = "[Desktop Entry]\nType=Application\nName=My custom launcher\nExec=true\n"
    put(home / "applications/absolute.desktop", edited)
    put(settings / "kernorarc", "[Icons]\nthemedApps=false\n")
    synchronizer.sync()
    assert (home / "applications/local.desktop").read_text() == absolute_desktop
    assert (home / "applications/symlink.desktop").is_symlink()
    assert linked.read_text() == absolute_desktop
    assert (home / "applications/absolute.desktop").read_text() == edited
    assert not synchronizer.state["desktops"]
    print("App icon sync: system/Flatpak/user icons, actions, updates, restart, caching, uninstall, palette and restoration OK")
