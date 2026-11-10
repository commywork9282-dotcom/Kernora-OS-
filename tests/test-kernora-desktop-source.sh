#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_root="$project_root/packages/native/kernora-desktop"

fail() {
  printf 'kernora-desktop source test: %s\n' "$*" >&2
  exit 1
}

for dependency in dpkg-parsechangelog grep python3; do
  command -v "$dependency" >/dev/null 2>&1 \
    || fail "required command not found: $dependency"
done

version=$(dpkg-parsechangelog -l"$package_root/debian/changelog" -S Version)
distribution=$(dpkg-parsechangelog \
  -l"$package_root/debian/changelog" -S Distribution)
[[ "$version" == "1.4.75" ]] || fail "unexpected source version"
[[ "$distribution" == "UNRELEASED" ]] \
  || fail "development package must remain UNRELEASED"
[[ "$(<"$package_root/debian/source/format")" == "3.0 (native)" ]] \
  || fail "wrong source format"
[[ -x "$package_root/debian/rules" ]] || fail "debian/rules is not executable"

control="$package_root/debian/control"
grep -Fxq 'Package: kernora-desktop' "$control" \
  || fail "desktop binary stanza is missing"
grep -Fxq 'Package: kernora-calamares' "$control" \
  || fail "installer binary stanza is missing"
grep -Fxq 'Standards-Version: 4.7.4' "$control" \
  || fail "wrong Standards-Version"
grep -Eq '^ calamares \(>= [^)]*kernora[0-9]+\),$' "$control" \
  || fail "installer configuration does not depend on the Kernora calamares"

data_root="$package_root/data"
for wallpaper in shapes rhythm starfall pastel ribbon; do
  for file in metadata.json contents/ui/main.qml contents/ui/Scene.qml contents/ui/config.qml contents/config/main.xml; do
    [[ -s "$data_root/wallpaper/org.kernora.$wallpaper/$file" ]] \
      || fail "the $wallpaper wallpaper lacks $file"
  done
  [[ -s "$package_root/data/shell/po/plasma_wallpaper_org.kernora.$wallpaper.ru.po" ]] \
    || fail "the $wallpaper wallpaper has no Russian translation"
done
grep -Fq 'import "morphs.js" as Morphs' "$data_root/wallpaper/org.kernora.ribbon/contents/ui/Scene.qml" \
  && grep -Fq 'readonly property int to: (5 * slot + 1) % scene.kinds' "$data_root/wallpaper/org.kernora.ribbon/contents/ui/Scene.qml" \
  && grep -Fq '"ribbon": {' "$package_root/tools/gen-wallpaper-assets" \
  || fail "Ribbon's shapes do not change into one another"
ribbon_assets=$(mktemp -d)
python3 "$package_root/tools/gen-wallpaper-assets" "$ribbon_assets" ribbon >/dev/null \
  && python3 - "$ribbon_assets/morphs.js" <<'PY' || fail "gen-wallpaper-assets does not write Ribbon's morphs"
import json, re, sys
text = open(sys.argv[1]).read()
samples = int(re.search(r"var samples = (\d+);", text).group(1))
names = json.loads(re.search(r"var names = (\[.*?\]);", text).group(1))
shapes = json.loads(re.search(r"var shapes = (\[.*\]);", text, re.S).group(1))
assert len(names) == len(shapes) == 16 and "puffy" not in names
assert all(len(radii) == samples and 0.2 < min(radii) and max(radii) < 0.75 for radii in shapes)
PY
rm -rf "$ribbon_assets"
[[ ! -e "$data_root/wallpaper/org.kernora.tower" ]] || fail "Tower is back"
[[ ! -e "$package_root/data/shell/po/plasma_wallpaper_org.kernora.tower.ru.po" ]] || fail "Tower still has a translation"
grep -q '"tower"' "$package_root/tools/gen-wallpaper-assets" && fail "gen-wallpaper-assets still has a Tower palette"
[[ ! -e "$data_root/wallpaper/org.kernora.marbles" ]] || fail "Marble Run is back"
sh -n "$package_root/data/kconf_update/kernora-marbles-to-pastel.sh" || fail "the Marble Run migration does not parse"
marbles_home=$(mktemp -d)
printf '[Greeter]\nWallpaperPlugin=org.kernora.marbles\n' > "$marbles_home/kscreenlockerrc"
XDG_CONFIG_HOME="$marbles_home" sh "$package_root/data/kconf_update/kernora-marbles-to-pastel.sh"
grep -Fxq 'WallpaperPlugin=org.kernora.pastel' "$marbles_home/kscreenlockerrc" \
  || fail "a lock screen with Marble Run does not move to Pastel"
grep -Fq '"org.kernora.pastel"' "$package_root/data/shell-updates/kernora_marbles_to_pastel.js" \
  || fail "desktops with Marble Run do not move to Pastel"
rm -rf "$marbles_home"
sh -n "$package_root/data/kconf_update/kernora-tower-to-shapes.sh" || fail "the Tower migration does not parse"
tower_home=$(mktemp -d)
printf '[Greeter]\nWallpaperPlugin=org.kernora.tower\n' > "$tower_home/kscreenlockerrc"
XDG_CONFIG_HOME="$tower_home" sh "$package_root/data/kconf_update/kernora-tower-to-shapes.sh"
grep -Fxq 'WallpaperPlugin=org.kernora.shapes' "$tower_home/kscreenlockerrc" \
  || fail "a lock screen with Tower does not move to Shapes"
grep -Fq '"org.kernora.shapes"' "$package_root/data/shell-updates/kernora_tower_to_shapes.js" \
  || fail "desktops with Tower do not move to Shapes"
grep -Fq 'wallpaper=org.kernora.shapes' "$package_root/debian/kernora-desktop.postinst" \
  || fail "a login screen with Tower does not move to Shapes"
rm -rf "$tower_home"
sh -n "$package_root/data/plasma-env/kernora-video-decoding.sh" || fail "the VLC decoding script does not parse"
video_home=$(mktemp -d)
mkdir -p "$video_home/sys/module/nvidia" "$video_home/.var/app/org.videolan.VLC/config/vlc"
printf '[avcodec]\navcodec-hw=vaapi_drm\n' > "$video_home/.var/app/org.videolan.VLC/config/vlc/vlcrc"
for run in 1 2; do
  HOME="$video_home" XDG_CONFIG_HOME="$video_home/.config" XDG_STATE_HOME="$video_home/.local/state" KERNORA_SYSFS="$video_home/sys" \
    sh -c ". '$package_root/data/plasma-env/kernora-video-decoding.sh'"
done
[[ "$(grep -c '^avcodec-hw=none$' "$video_home/.config/vlc/vlcrc")" == 1 ]] || fail "VLC keeps hardware decoding on NVIDIA"
grep -Fxq 'avcodec-hw=vaapi_drm' "$video_home/.var/app/org.videolan.VLC/config/vlc/vlcrc" \
  && ! grep -q 'avcodec-hw=none' "$video_home/.var/app/org.videolan.VLC/config/vlc/vlcrc" \
  || fail "a VLC decoder chosen by the user is overridden"
rm -rf "$video_home/.config" "$video_home/.local"
rm -rf "$video_home/sys/module/nvidia"
HOME="$video_home" XDG_CONFIG_HOME="$video_home/.config" XDG_STATE_HOME="$video_home/.local/state" KERNORA_SYSFS="$video_home/sys" \
  sh -c ". '$package_root/data/plasma-env/kernora-video-decoding.sh'"
[[ ! -e "$video_home/.config/vlc/vlcrc" ]] || fail "VLC decoding changes without an NVIDIA driver"
rm -rf "$video_home"
assets=$(mktemp -d)
python3 "$package_root/tools/gen-wallpaper-assets" "$assets" pastel >/dev/null \
  || fail "gen-wallpaper-assets cannot write Pastel's assets"
grep -q '"hull":\[\[' "$assets/materialshapes.js" || fail "the shapes have no hulls"
grep -q '"base"' "$assets/palettes/kernora.qml" || fail "Pastel's palette has no base"
KERNORA_COLOUR=blue python3 "$package_root/tools/gen-wallpaper-assets" "$assets" pastel >/dev/null \
  || fail "gen-wallpaper-assets cannot write Pastel's blue palette"
cmp -s "$assets/palettes/kernora.qml" "$assets/palettes/blue.qml" && fail "the wallpaper does not change with the colour"
rm -rf "$assets"
palettes=$(mktemp -d)
for colour in kernora blue grey; do
  KERNORA_COLOUR=$colour python3 "$package_root/tools/gen-qml-tokens" --palette "$palettes/$colour.conf" >/dev/null \
    || fail "no $colour palette"
done
grep -Fxq 'id=blue' "$palettes/blue.conf" || fail "the blue palette does not name itself"
grep -Fxq '[md1-light]' "$palettes/blue.conf" || fail "the blue palette lacks Material Design 1"
python3 - "$palettes/grey.conf" <<'PYTHON_TEST' || fail "the grey theme is not grey"
import configparser, sys
c = configparser.ConfigParser(interpolation=None)
c.optionxform = str
c.read(sys.argv[1])
rgb = bytes.fromhex(c["md3-dark"]["primary"])
assert max(rgb) - min(rgb) <= 6, rgb.hex()
PYTHON_TEST
KERNORA_COLOUR=violet python3 "$package_root/tools/gen-qml-tokens" --palette "$palettes/x.conf" >/dev/null 2>&1 \
  && fail "an unknown colour was accepted"
rm -rf "$palettes"
[[ ! -e "$data_root/wallpapers" ]] || fail "picture wallpapers are back in the package"
grep -Fxq 'path-exclude=/usr/share/wallpapers/Next/*' "$data_root/dpkg/kernora-wallpapers" \
  || fail "Breeze's picture wallpaper is not kept out"

defaults="$data_root/look-and-feel/org.kernora.desktop/contents/defaults"
[[ -s "$defaults" ]] || fail "look-and-feel defaults are missing"
grep -Fq 'wallpaperPlugin = "org.kernora.shapes"' "$data_root/look-and-feel/org.kernora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" \
  || fail "the default layout does not use Kernora Shapes"
grep -Fxq 'cursorTheme=kernora_cursors' "$defaults" \
  || fail "look-and-feel does not select the Kernora cursors"
[[ -x "$package_root/tools/gen-cursor-theme" ]] || fail "the cursor theme generator is missing"
grep -Fxq 'Theme=Kernora' "$defaults" \
  || fail "look-and-feel does not select the Kernora icon theme"
grep -Fxq 'Theme=org.kernora.desktop' "$defaults" \
  || fail "look-and-feel does not select the Kernora session splash"
grep -Fq 'loglevel=3' "$package_root/data/grub/kernora.cfg" \
  && grep -Fq 'update-grub' "$package_root/debian/kernora-desktop.postinst" \
  || fail "installed systems print kernel errors over the boot splash"
grep -Fq 'dpkg-trigger --no-await update-initramfs' "$package_root/debian/kernora-desktop.postinst" \
  && grep -Fq '/var/lib/kernora/plymouth-theme' "$package_root/debian/kernora-desktop.postrm" \
  || fail "a changed boot splash does not reach the initramfs on upgrade"
grep -Fq 'Keys.onReturnPressed: event => event.accepted = true' "$package_root/data/widgets/common/CityPicker.qml" \
  || fail "Enter in the city search closes the widget settings"
grep -Fq 'property Timer watch' "$package_root/data/widgets/common/WeatherModel.qml" \
  && grep -Fq 'text: weather.city' "$package_root/data/widgets/weather/contents/ui/main.qml" \
  || fail "the weather widget does not show the chosen city"
grep -Fq 'function commit()' "$package_root/data/widgets/common/CityPicker.qml" \
  && grep -Fq 'picker.commit()' "$package_root/data/widgets/weather/contents/ui/ConfigLocation.qml" \
  && grep -Fq 'picker.commit()' "$package_root/data/widgets/glance/contents/ui/ConfigWeather.qml" \
  && grep -Fq 'onTextChanged: typing.restart()' "$package_root/data/widgets/common/CityPicker.qml" \
  || fail "the weather city does not follow Apply or does not search while typing"
grep -Fq 'readonly property bool shown: Plasmoid.configuration.interactiveMute' "$package_root/data/taskmanager/AudioStream.qml" \
  && grep -Fq '"$tasks/AudioStream.qml"' "$package_root/debian/kernora-desktop.preinst" \
  && grep -Fq '"$tasks/AudioStream.qml"' "$package_root/debian/kernora-desktop.postrm" \
  || fail "the task audio indicator ignores its setting"
grep -Fq 'RightButton;NoModifier=org.kde.contextmenu' "$package_root/data/kconf_update/kernora-add-widgets-menu.sh" \
  || fail "a new user's desktop can lose its right-click menu"
drivers="$package_root/data/drivers"
bash -n "$drivers/kernora-drivers" || fail "kernora-drivers is not valid bash"
[[ -x "$drivers/kernora-drivers" ]] || fail "kernora-drivers is not executable"
[[ "$(gpg --show-keys --with-colons "$drivers/nvidia-archive-keyring.gpg" 2>/dev/null | awk -F: '$1 == "fpr" {print $10; exit}')" == 02182E60104FCDC26EAE1B8597A5D4CB8793F200 ]] \
  || fail "the NVIDIA archive key is not NVIDIA's Debian 13 key"
grep -Fq 'OnActiveSec=90s' "$drivers/kernora-drivers.timer" \
  && grep -Fq 'ExecStart=/usr/libexec/kernora-drivers auto' "$drivers/kernora-drivers.service" \
  && grep -Fq 'ExecStart=/usr/libexec/kernora-drivers %i' "$drivers/kernora-drivers@.service" \
  || fail "the driver check is not scheduled"
grep -Fq '<annotate key="org.freedesktop.policykit.exec.path">/usr/libexec/kernora-drivers</annotate>' "$drivers/org.kernora.drivers.policy" \
  || fail "Settings cannot run kernora-drivers"
[[ -x "$drivers/kernora-hardware" && -x "$drivers/kernora-driver-job" ]] \
  || fail "the hardware scanner or driver job is not executable"
grep -Fq 'ExecStart=/usr/libexec/kernora-driver-job run' "$drivers/kernora-driver-job.service" \
  && grep -Fq 'data/drivers/kernora-driver-job.service' "$package_root/debian/kernora-desktop.install" \
  && grep -Fq 'data/drivers/catalog.json usr/share/kernora/hardware' "$package_root/debian/kernora-desktop.install" \
  || fail "the driver job is not installed"
grep -Fq '"$job_tool" needs-non-free || rm -f "$debian_sources"' "$drivers/kernora-drivers" \
  && grep -Fq 'add | drop | flash) exec "$job_tool" request' "$drivers/kernora-drivers" \
  || fail "kernora-drivers does not hand jobs over"
leftovers=$(printf '%s\n' 'ii nvidia-settings' 'ii libnvidia-glcore:amd64' 'ii libnvidia-glcore:i386' 'ii libglx-nvidia0:amd64' \
    'ii libcuda1:amd64' 'ii xserver-xorg-video-nvidia' 'ii firmware-nvidia-graphics' 'ii mesa-vulkan-drivers:amd64' \
    'rc nvidia-driver' 'iF nvidia-kernel-dkms' \
  | awk -v names="$(sed -n "s/^leftover_names='\(.*\)'$/\1/p" "$drivers/kernora-drivers")" '$1 ~ /^i/ && $2 ~ names { print $2 }' | wc -l)
[[ "$leftovers" == 7 ]] || fail "removing the NVIDIA driver leaves the wrong packages: $leftovers"
python3 - "$drivers" <<'PY' || fail "the hardware scanner or driver job is wrong"
import importlib.machinery
import importlib.util
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

drivers = Path(sys.argv[1])
catalog = json.loads((drivers / "catalog.json").read_text())

ids = [item["id"] for item in catalog["items"]]
assert len(ids) == len(set(ids)), "duplicate catalog id"
for item in catalog["items"]:
    assert item["marker"] in item["packages"], item["id"]
    for text in (item["name"], item["text"]):
        assert text["en"] and text["ru"], item["id"]
    assert not {"source", "module"} & item.keys() or item.get("source") or item["module"]
for prefix, package in catalog["firmware"]:
    assert package.startswith("firmware-"), prefix
for group in catalog["updates"]:
    re.compile(group["pattern"])
    assert group["name"]["en"] and group["name"]["ru"], group["id"]
wl = next(item for item in catalog["items"] if item["id"] == "broadcom-wl")
assert "14e4:43b1" in wl["match"]["pci"] and wl["module"] == "wl" and wl["source"] == "non-free"


def load(name):
    loader = importlib.machinery.SourceFileLoader(name.replace("-", "_"), str(drivers / name))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def write(path, text=""):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def executable(path, text):
    write(path, text)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)


def pci(root, address, vendor, device, code, driver="", module=""):
    path = root / "sys/bus/pci/devices" / address
    write(path / "vendor", f"0x{vendor}\n")
    write(path / "device", f"0x{device}\n")
    write(path / "class", f"0x{code}\n")
    if driver:
        target = root / "sys/bus/pci/drivers" / driver
        target.mkdir(parents=True, exist_ok=True)
        (path / "driver").symlink_to(target)
        if module:
            modules = root / "sys/module" / module
            modules.mkdir(parents=True, exist_ok=True)
            (target / "module").symlink_to(modules)
    return path


def usb(root, name, vendor, product, interface_class, device_class="00", driver=""):
    path = root / "sys/bus/usb/devices" / name
    write(path / "idVendor", f"{vendor}\n")
    write(path / "idProduct", f"{product}\n")
    write(path / "bDeviceClass", f"{device_class}\n")
    interface = path / f"{name}:1.0"
    write(interface / "bInterfaceClass", f"{interface_class}\n")
    write(interface / "bInterfaceSubClass", "00\n")
    write(interface / "bInterfaceProtocol", "00\n")
    if driver:
        target = root / "sys/bus/usb/drivers" / driver
        target.mkdir(parents=True, exist_ok=True)
        (interface / "driver").symlink_to(target)


work = Path(tempfile.mkdtemp())
try:
    root = work / "root"
    bin_dir = work / "bin"
    executable(bin_dir / "systemd-detect-virt", "#!/bin/sh\ncat \"$VIRT\"\n")
    executable(bin_dir / "dpkg-query", "#!/bin/sh\ncat \"$PACKAGES\"\n")
    write(work / "virt", "kvm\n")
    write(work / "packages", "")
    environment = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}", VIRT=str(work / "virt"),
                       PACKAGES=str(work / "packages"))
    shutil.copy(drivers / "catalog.json", work / "catalog.json")
    write(root / "usr/share/kernora/hardware/catalog.json", (drivers / "catalog.json").read_text())
    write(root / "proc/sys/kernel/osrelease", "6.12.0-test\n")
    write(root / "proc/cpuinfo", "model name : Intel(R) Core(TM) i5-1 CPU @ 2.90GHz\n")
    write(root / "etc/os-release", 'PRETTY_NAME="Kernora test"\n')
    write(root / "usr/share/misc/pci.ids",
          "8086  Intel Corporation\n\t46a6  Alder Lake-P GT2 [Iris Xe Graphics]\n"
          "\t51f0  Alder Lake-P PCH CNVi WiFi\n"
          "14e4  Broadcom Inc. and subsidiaries\n\t43b1  BCM4352 802.11ac Wireless\n"
          "C 00  Unclassified device\n\t00  Non-VGA\n")
    write(root / "usr/share/misc/usb.ids",
          "03f0  HP, Inc\n\t0c17  LaserJet 1010\n1d6b  Linux Foundation\n\t0002  2.0 root hub\n")
    pci(root, "0000:00:02.0", "8086", "46a6", "030000", "i915", "i915")
    pci(root, "0000:00:14.3", "8086", "51f0", "028000", "iwlwifi", "iwlwifi")
    write(root / "sys/bus/pci/devices/0000:00:14.3/net/wlan0/phy80211/name", "phy0\n")
    broadcom = pci(root, "0000:03:00.0", "14e4", "43b1", "028000")
    pci(root, "0000:00:1f.3", "8086", "51c8", "040300")
    pci(root, "0000:00:00.0", "8086", "4601", "060000")
    usb(root, "1-1", "03f0", "0c17", "07", driver="usblp")
    usb(root, "1-2", "05e3", "0608", "09", device_class="09")
    usb(root, "usb1", "1d6b", "0002", "09", device_class="09")

    def scan():
        done = subprocess.run([str(drivers / "kernora-hardware"), "--root", str(root), "scan"],
                              capture_output=True, text=True, env=environment, check=True)
        return json.loads(done.stdout)

    def items(data):
        return {item["id"]: item for item in data["items"]}

    data = scan()
    found = {device["id"]: device for device in data["devices"]}
    assert found["pci:0000:00:02.0"]["name"] == "Intel Iris Xe Graphics", found["pci:0000:00:02.0"]
    assert found["pci:0000:00:02.0"]["category"] == "graphics"
    assert found["pci:0000:00:02.0"]["version"] == "6.12.0-test"
    assert found["pci:0000:00:14.3"]["wifi"] and found["pci:0000:00:14.3"]["status"] == "ok"
    assert found["pci:0000:03:00.0"]["status"] == "none"
    assert found["pci:0000:00:1f.3"]["status"] == "none" and found["pci:0000:00:1f.3"]["category"] == "audio"
    assert found["pci:0000:00:00.0"]["status"] == "idle" and found["pci:0000:00:00.0"]["category"] == "system"
    assert found["usb:1-1"]["category"] == "printer" and found["usb:1-1"]["driver"] == "usblp"
    assert found["usb:1-1"]["name"] == "HP LaserJet 1010", found["usb:1-1"]
    assert "usb:1-2" not in found and "usb:usb1" not in found, "hubs are not devices"
    assert found["cpu:0"]["name"] == "Intel Core i5-1", found["cpu:0"]

    offered = items(data)
    assert found["pci:0000:03:00.0"]["offer"] == "broadcom-wl", "the card has a driver on offer"
    assert found["pci:0000:00:1f.3"]["offer"] == "", "this one really has nothing"
    assert offered["broadcom-wl"]["recommended"] and offered["broadcom-wl"]["nonFree"]
    assert offered["broadcom-wl"]["restart"] and not offered["broadcom-wl"]["blocked"]
    assert offered["printing"]["recommended"], "a USB printer recommends printing"
    assert offered["vm-qemu"]["recommended"] and "vm-vmware" not in offered
    assert "firmware-updates" not in offered, "virtual machines have no firmware to update"
    assert not offered["intel-video"]["recommended"] and not offered["opencl"]["recommended"]

    write(work / "virt", "none\n")
    offered = items(scan())
    assert "firmware-updates" in offered and "vm-qemu" not in offered

    shutil.rmtree(root / "sys/bus/usb/devices/1-1")
    assert not items(scan())["printing"]["recommended"]

    secure = root / "sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"
    secure.parent.mkdir(parents=True)
    secure.write_bytes(b"\x06\x00\x00\x00\x01")
    offered = items(scan())
    assert offered["broadcom-wl"]["blocked"] == "secureboot" and not offered["printing"]["blocked"]
    secure.write_bytes(b"\x06\x00\x00\x00\x00")
    assert not items(scan())["broadcom-wl"]["blocked"]

    write(broadcom / "bcma0:1/net/wlan1/phy80211/name", "phy1\n")
    assert "broadcom-wl" not in items(scan()), "a working card needs nothing"
    shutil.rmtree(broadcom / "bcma0:1")

    write(work / "packages", "broadcom-sta-dkms ii \n")
    offered = items(scan())
    assert offered["broadcom-wl"]["state"] == "installed" and not offered["broadcom-wl"]["removable"]
    write(root / "var/lib/kernora/drivers/items/broadcom-wl.json", "{}")
    assert items(scan())["broadcom-wl"]["removable"]
    write(work / "packages", "broadcom-sta-dkms rc \n")
    assert items(scan())["broadcom-wl"]["state"] == "available", "removed packages are not installed"

    write(root / "var/lib/kernora/drivers/firmware-missing.json", json.dumps([
        {"driver": "iwlwifi", "device": "0000:00:14.3", "file": "iwlwifi-so-a0-gf-a0-89.ucode"},
        {"driver": "bluetooth", "device": "hci0", "file": "unknown/none.bin"}]))
    data = scan()
    offered = items(data)
    assert "firmware:firmware-iwlwifi" in offered and offered["firmware:firmware-iwlwifi"]["recommended"]
    assert "Intel" in offered["firmware:firmware-iwlwifi"]["text"]["en"]
    assert next(d for d in data["devices"] if d["id"] == "pci:0000:00:14.3")["status"] == "firmware"
    assert len([key for key in offered if key.startswith("firmware:")]) == 1
    write(work / "packages", "firmware-iwlwifi ii \n")
    data = scan()
    assert "firmware:firmware-iwlwifi" not in items(data), "the package is already installed"
    assert next(d for d in data["devices"] if d["id"] == "pci:0000:00:14.3")["status"] == "ok"

    done = subprocess.run([str(drivers / "kernora-hardware"), "--root", str(root), "report"],
                          capture_output=True, text=True, env=environment, check=True)
    assert "Intel Iris Xe Graphics [8086:46a6]: i915" in done.stdout and "no driver" in done.stdout

    hardware = load("kernora-hardware")
    assert hardware.short_vendor("Advanced Micro Devices, Inc. [AMD/ATI]") == "AMD"
    assert hardware.short_vendor("Realtek Semiconductor Co., Ltd.") == "Realtek"
    assert hardware.short_vendor("Samsung Electronics Co Ltd") == "Samsung"
    assert hardware.device_label("input", "Razer USA", "Razer DeathAdder") == "Razer DeathAdder"
    assert hardware.device_label("graphics", "AMD", "Navi 31 [Radeon RX 7900 XT]") == "AMD Radeon RX 7900 XT"
    assert hardware.firmware_package(catalog, "intel/ibt-0040-0041.sfi") == "firmware-iwlwifi"
    assert hardware.firmware_package(catalog, "intel/sof-ipc4/x.ri") == "firmware-sof-signed"
    assert hardware.firmware_package(catalog, "regulatory.db") == ""

    job = load("kernora-driver-job")
    job.CATALOG = drivers / "catalog.json"
    assert job.resolve("add", "printing")["marker"] == "cups"
    assert job.resolve("add", "firmware:firmware-realtek")["packages"] == ["firmware-realtek"]
    assert job.resolve("add", "firmware:evil-package") is None
    assert job.resolve("add", "cups") is None
    assert job.resolve("add", "../../etc/passwd") is None
    assert job.resolve("drop", "firmware:firmware-realtek") is None
    assert job.resolve("purge", "printing") is None
    assert job.resolve("flash", "a" * 40) and job.resolve("flash", "a" * 39) is None
    assert job.resolve("flash", "-" + "a" * 39) is None

    plan = job.parse_plan("Inst cups (2.4)\nRemv intel-media [1]\nPurg hplip [2]\nConf cups (2.4)\n")
    assert plan == {"install": {"cups"}, "remove": {"intel-media", "hplip"}}

    job.JOB = work / "run/job.json"
    state = job.Job("add", "printing")
    job.read_status("dlstatus:1:12.5:Retrieving\n", state)
    assert state.values["step"] == "download" and state.values["percent"] == 12
    job.read_status("pmstatus:cups:50.0:Installing: cups\n", state)
    assert state.values["step"] == "install" and state.values["percent"] == 50
    assert json.loads(job.JOB.read_text())["percent"] == 50
    assert job.JOB.stat().st_mode & 0o777 == 0o644, "the app has to read the job"
    job.read_status("garbage\n", state)
    assert state.values["percent"] == 50
    state.finish(True)
    following = job.Job("add", "opencl")
    assert following.values["restart"], "the next job must not forget a pending restart"
    following.finish(False)
    assert json.loads(job.JOB.read_text())["restart"]

    job.FIRMWARE = work / "firmware"
    write(job.FIRMWARE / "iwlwifi-so-a0-gf-a0-83.ucode.xz")
    write(job.FIRMWARE / "rtl_nic/rtl8125a-3.fw")
    log = "\n".join([
        "iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2",
        "r8169 0000:03:00.0: Direct firmware load for rtl_nic/rtl8168h-2.fw failed with error -2",
        "r8169 0000:03:00.0: Direct firmware load for rtl_nic/rtl8125a-3.fw failed with error -2",
        "bluetooth hci0: Direct firmware load for rtl_bt/rtl8761bu_fw.bin failed with error -2",
        "bluetooth hci0: Direct firmware load for rtl_bt/rtl8761bu_fw.bin failed with error -2",
        "ath10k_pci 0000:02:00.0: Direct firmware load for ath10k/x/board.bin failed with error -13",
        "usb 1-1: new high-speed USB device"])
    assert [entry["file"] for entry in job.parse_missing(log)] == [
        "rtl_bt/rtl8761bu_fw.bin", "rtl_nic/rtl8168h-2.fw"], job.parse_missing(log)
    assert job.parse_missing(log)[0]["device"] == "hci0"

    answer = "broadcom-sta-dkms iF \nlinux-headers-amd64 ic \ndkms ii \nnever-here un \ngone pn \n"
    job.subprocess = type("Query", (), {"run": staticmethod(
        lambda command, **options: type("Done", (), {"stdout": answer})())})
    assert job.on_disk(["broadcom-sta-dkms", "linux-headers-amd64", "dkms", "never-here", "gone"]) == {
        "broadcom-sta-dkms", "linux-headers-amd64", "dkms"}, "a failed package has to be undone too"
    assert job.installed(["broadcom-sta-dkms", "dkms"]) == {"dkms"}
    job.subprocess = subprocess

    calls = []
    job.subprocess = type("Calls", (), {"run": staticmethod(lambda command, **options: calls.append(command))})
    job.administrators = lambda: ["ann", "bob"]
    printing = job.resolve("add", "printing")
    assert printing["groups"] == ["lpadmin"], "without lpadmin nobody can add a printer"
    job.group_members = lambda group: ["ann"]
    job.join_groups(printing)
    assert calls == [["usermod", "-aG", "lpadmin", "bob"]], calls
    calls.clear()
    job.leave_groups(printing)
    assert calls == [["gpasswd", "-d", "ann", "lpadmin"], ["gpasswd", "-d", "bob", "lpadmin"]], calls
    calls.clear()
    job.join_groups(job.resolve("add", "vm-qemu"))
    assert not calls
    job.subprocess = subprocess

    job.ITEMS = work / "items"
    write(job.ITEMS / "printing.json", json.dumps({"packages": ["cups"], "source": ""}))
    write(job.ITEMS / "broadcom-wl.json", json.dumps({"packages": ["linux-headers-amd64"], "source": "non-free"}))
    job.installed = lambda names: set()
    assert job.shared_packages("printing") == {"linux-headers-amd64"}
    assert job.source_needed()
    (job.ITEMS / "broadcom-wl.json").unlink()
    assert not job.source_needed()
    job.installed = lambda names: set(names) if "nvidia-driver" in names else set()
    assert job.source_needed(), "the legacy NVIDIA driver still needs non-free"
    job.installed = lambda names: {"nvidia-open"} & set(names)
    assert job.shared_packages("broadcom-wl") == {"linux-headers-amd64", "cups"}
finally:
    shutil.rmtree(work)
PY
android="$package_root/data/android"
bash -n "$android/kernora-android" && bash -n "$android/waydroid" \
  && python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$android/kernora-android-session" \
  || fail "the Android tools are not valid"
[[ -x "$android/kernora-android" && -x "$android/kernora-android-session" && -x "$android/waydroid" ]] \
  || fail "the Android tools are not executable"
grep -Fq 'Suites: trixie-backports' "$android/kernora-android.sources" \
  && grep -Fq 'install --no-install-recommends waydroid' "$android/kernora-android" \
  && grep -Fq 'persist.waydroid.multi_windows' "$android/kernora-android-device" \
  || fail "kernora-android does not set Waydroid up from backports with separate windows"
grep -Fq 'ExecStart=/usr/libexec/kernora-android %i' "$android/kernora-android@.service" \
  && grep -Fq 'BusName=id.waydro.Session' "$android/kernora-android.service" \
  && grep -Fq 'ExecStart=/usr/bin/env KERNORA_HOST_WAYLAND_DISPLAY=${WAYLAND_DISPLAY} WAYLAND_DISPLAY=kernora-android-0 PYTHONPATH=/usr/share/kernora/android/python /usr/bin/waydroid.waydroid session start' "$android/kernora-android.service" \
  && grep -Fq '<annotate key="org.freedesktop.policykit.exec.path">/usr/libexec/kernora-android</annotate>' "$android/org.kernora.android.policy" \
  || fail "Settings cannot run kernora-android"
grep -Fq 'real=/usr/bin/waydroid.waydroid' "$android/waydroid" \
  && grep -Fq '/usr/libexec/kernora-android-session' "$android/waydroid" \
  && grep -Fq "stdbuf -oL tr" "$android/kernora-android" \
  || fail "Android apps do not wait for Android to boot"
bash -n "$android/kernora-android-sync" && [[ -x "$android/kernora-android-sync" ]] \
  && grep -Fq 'settings put secure theme_customization_overlay_packages' "$android/kernora-android-sync" \
  && grep -Fq 'cmd uimode night' "$android/kernora-android-sync" \
  && grep -Fq 'pm list packages -s' "$android/kernora-android-sync" \
  && grep -Fq '<annotate key="org.freedesktop.policykit.exec.path">/usr/libexec/kernora-android-sync</annotate>' "$android/org.kernora.android.policy" \
  && grep -Fq 'PathChanged=%h/.config/kdeglobals' "$android/kernora-android-sync.path" \
  && grep -Fq 'PathChanged=%h/.config/kdedefaults/kdeglobals' "$android/kernora-android-sync.path" \
  && grep -Fq '"kdedefaults"' "$android/kernora-android-session" \
  && grep -Fq -- '--sync-after-boot' "$android/kernora-android.service" \
  || fail "Android apps do not follow the Kernora colour and theme"
grep -Fq 'ExecStart=/usr/libexec/kernora-android update' "$android/kernora-android-update.service" \
  && grep -Fq 'OnUnitActiveSec=1d' "$android/kernora-android-update.timer" \
  && grep -Fq 'kernora-android-update.timer' "$package_root/debian/rules" \
  || fail "the image behind Android apps does not update itself"
[[ -x "$android/kernora-android-fetch" ]] \
  && grep -Fq '"$fetch" setup' "$android/kernora-android" \
  && grep -Fq '"$fetch" install && "$real" upgrade -o' "$android/kernora-android" \
  && grep -Fq 'remaining=%s' "$android/kernora-android" \
  && grep -Fxq 'data/android/kernora-android-fetch usr/libexec' "$package_root/debian/kernora-desktop.install" \
  && timeout 120 python3 -I - "$android/kernora-android-fetch" <<'EOF' \
  || fail "Android apps do not download their image from several mirrors at once"
import hashlib
import http.server
import importlib.machinery
import importlib.util
import os
import re
import socketserver
import sys
import tempfile
import threading
import time

loader = importlib.machinery.SourceFileLoader("fetch", sys.argv[1])
fetch = importlib.util.module_from_spec(importlib.util.spec_from_loader("fetch", loader))
loader.exec_module(fetch)
fetch.TIMEOUT = 3
size = 9 * 1024 * 1024 + 4321
data = os.urandom(size)


def mirror(mode):
    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *args):
            pass

        def do_GET(self):
            first, last = map(int, re.match(r"bytes=(\d+)-(\d+)", self.headers["Range"]).groups())
            last = min(last, size - 1)
            self.send_response(206)
            self.send_header("Content-Length", str(last - first + 1))
            self.send_header("Content-Range", f"bytes {first}-{last}/{size}")
            self.end_headers()
            try:
                for start in range(first, last + 1, 65536):
                    self.wfile.write(data[start:min(start + 65536, last + 1)])
                    if mode == "slow":
                        time.sleep(0.5)
                    elif mode == "stuck":
                        time.sleep(60)
                    elif mode == "flaky" and start - first >= 524288:
                        self.connection.shutdown(2)
                        return
            except OSError:
                pass

    class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
        daemon_threads = True

    server = Server(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return f"http://127.0.0.1:{server.server_address[1]}/image.zip"


fetch.mirrors = lambda url, total: [mirror(mode) for mode in ("slow", "stuck", "flaky", "fast")]
fetch.say = lambda message: None
sys.stdout = open(os.devnull, "w")
with tempfile.TemporaryDirectory() as folder:
    path = os.path.join(folder, "image.zip")
    progress = fetch.Progress(size)
    started = time.monotonic()
    fetch.download("http://unused/image.zip", path, size, progress)
    progress.stopped.set()
    took = time.monotonic() - started
    with open(path, "rb") as handle:
        same = hashlib.sha256(handle.read()).digest() == hashlib.sha256(data).digest()
sys.exit(0 if same and took < 10 else 1)
EOF
grep -Fq 'setting global force_resizable_activities 1' "$android/kernora-android-sync" \
  && grep -Fq 'windows-reset-2' "$android/kernora-android" \
  && grep -Fq "section 'App exits'" "$android/kernora-android" \
  && grep -Fq "section 'Android restarts'" "$android/kernora-android" \
  && timeout 60 python3 -I - "$android/kernora-android-display" "$android/wayland-protocols.json" <<'EOF' \
  || fail "Android can freeze on a new window, windows can reach the panel before their entry, or lose their state when an app restarts"
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import socket
import struct
import sys
import tempfile
import time

loader = importlib.machinery.SourceFileLoader("display", sys.argv[1])
display = importlib.util.module_from_spec(importlib.util.spec_from_loader("display", loader))
loader.exec_module(display)
ok = display.PULSE <= 1 and display.PULSE_SERIAL > 0xE0000000
with tempfile.TemporaryDirectory() as folder:
    root = pathlib.Path(folder)
    (root / "data/applications").mkdir(parents=True)
    (root / "cache").mkdir()
    (root / "config").mkdir()
    os.environ.update(XDG_DATA_HOME=str(root / "data"), XDG_CACHE_HOME=str(root / "cache"), XDG_CONFIG_HOME=str(root / "config"))
    display.SYSTEM_ENTRIES = str(root / "system")
    ok = ok and not display.entry("com.example") and not display.listed("com.example")
    item = root / "data/applications/waydroid.com.example.desktop"
    item.write_text("[Desktop Entry]\n", encoding="utf-8")
    now = time.time()
    database = root / "cache/ksycoca6_en_x"
    database.write_text("x", encoding="utf-8")
    os.utime(item, (now - 60, now - 60))
    os.utime(database, (now - 1, now - 1))
    ok = ok and display.entry("com.example") == str(item) and not display.listed("com.example")
    os.utime(database, (now - 30, now - 30))
    ok = ok and display.listed("com.example")
    os.utime(item, (now - 10, now - 10))
    ok = ok and not display.listed("com.example")
    display.refresh_panel()
    ok = ok and (root / "config/taskmanagerrulesrc").exists()
    table = {"xdg_wm_base": {"requests": [{"name": "destroy", "args": []}, {"name": "create_positioner", "args": [["new_id", "xdg_positioner"]]},
                                          {"name": "get_xdg_surface", "args": [["new_id", "xdg_surface"], ["object", "wl_surface"]]},
                                          {"name": "pong", "args": [["uint", ""]]}], "events": []}}
    first, second = socket.socketpair()
    third, fourth = socket.socketpair()
    session = display.Session(table, folder, {}, set(), first, third)
    session.to_server[5] = 9
    session.to_client[9] = 5
    session.interfaces[9] = "xdg_wm_base"
    session.wm_base = 5
    session.pulse()
    ok = ok and bytes(session.client_out) == struct.pack("<III", 5, 12 << 16, display.PULSE_SERIAL)
    session.request(5, 3, struct.pack("<I", display.PULSE_SERIAL))
    ok = ok and not session.server_out
    session.request(5, 3, struct.pack("<I", 77))
    ok = ok and bytes(session.server_out) == struct.pack("<III", 9, (12 << 16) | 3, 77)
    surface = display.Surface()
    surface.backing, surface.backing_sub, surface.backing_view = 40, 41, 42
    session.server_out.clear()
    session.drop_backing(surface)
    ok = ok and bytes(session.server_out) == struct.pack("<II", 42, 8 << 16) + struct.pack("<II", 41, 8 << 16) + struct.pack("<II", 40, 8 << 16)
    ok = ok and surface.backing is None
    for item in (first, second, third, fourth):
        item.close()
    with open(sys.argv[2], encoding="utf-8") as handle:
        protocols = json.load(handle)
    first, second = socket.socketpair()
    third, fourth = socket.socketpair()
    session = display.Session(protocols, folder, {}, set(), first, third)
    session.tell_helper = lambda line: None
    for client, interface in ((2, "wl_compositor"), (3, "wp_viewporter"), (4, "xdg_wm_base"), (5, "wl_subcompositor")):
        session.client_object(client, interface)

    def number(*values: int) -> bytes:
        return struct.pack(f"<{len(values)}I", *values)

    def name(text: str) -> bytes:
        return display.wayland_string(text)

    def window(base: int) -> None:
        session.request(2, 0, number(base))
        session.request(3, 1, number(base + 1, base))
        session.request(4, 2, number(base + 2, base))
        session.request(base + 2, 1, number(base + 3))
        session.request(base + 3, 3, name("waydroid.com.example"))

    window(10)
    root = session.surfaces[10]
    root.mapped = True
    root.geometry = (0, 0, 100, 100)
    root.want = (200, 200)
    root.layout = {2}
    servers = root.server_id, root.xdg_server, root.toplevel, root.viewport
    session.request(2, 0, number(30))
    session.request(3, 1, number(31, 30))
    session.request(5, 1, number(32, 30, 10))
    child = session.surfaces[30]
    child.has_buffer = True
    child.size = (100, 100)
    session.client_out.clear()
    session.server_out.clear()
    session.request(13, 0, b"")
    session.request(12, 0, b"")
    session.request(32, 0, b"")
    session.request(31, 0, b"")
    session.request(30, 0, b"")
    session.request(11, 0, b"")
    session.request(10, 0, b"")
    ok = ok and session.kept.get("com.example") is root and len(root.frozen) == 3 and not session.server_out
    ok = ok and all(client not in session.to_server for client in (10, 11, 12, 13, 30, 31, 32))
    ok = ok and len(session.client_out) == 7 * 12
    window(20)
    ok = ok and not session.kept and session.surfaces[20] is root and session.toplevels[23] is root
    ok = ok and (session.to_server[20], session.to_server[22], session.to_server[23], session.to_server[21]) == servers
    ok = ok and struct.pack("<III", 22, 12 << 16, display.FAKE_SERIAL) in bytes(session.client_out)
    session.server_out.clear()
    session.request(22, 4, number(display.FAKE_SERIAL))
    ok = ok and not session.server_out
    session.request(22, 4, number(77))
    ok = ok and bytes(session.server_out).startswith(struct.pack("<III", servers[1], (12 << 16) | 4, 77))
    ok = ok and root.want == (200, 200) and root.layout == {2}
    session.toplevels[23].closing = False
    session.request(23, 0, b"")
    session.request(22, 0, b"")
    session.request(21, 0, b"")
    session.request(20, 0, b"")
    ok = ok and "com.example" in session.kept
    session.task_gone("com.example")
    ok = ok and not session.kept and all(server in session.injected for server in servers)
    window(40)
    fresh = session.surfaces[40]
    fresh.mapped = True
    session.task_gone("com.example")
    session.request(43, 0, b"")
    ok = ok and not session.kept
    fresh.closing = True
    session.gone.clear()
    ok = ok and not session.may_keep(fresh)
    parent = display.Surface()
    fitted = display.Surface()
    fitted.viewport, fitted.subsurface, fitted.server_id, fitted.has_buffer = 50, 51, 52, True
    fitted.size, fitted.position = (100, 50), (10, 10)
    parent.children.add(fitted)
    parent.want = (200, 100)
    parent.resizing = True
    session.server_out.clear()
    session.fit(parent, (10, 10, 100, 50))
    ok = ok and fitted.fitted == ((200, 100), (10, 10)) and struct.pack("<IIii", 50, (16 << 16) | 2, 200, 100) in bytes(session.server_out)
    parent.resizing = False
    parent.fit_until = 0
    session.server_out.clear()
    session.fit(parent, (10, 10, 100, 50))
    ok = ok and fitted.fitted is None and struct.pack("<IIii", 50, (16 << 16) | 2, 100, 50) in bytes(session.server_out)
    for item in (first, second, third, fourth):
        item.close()
sys.exit(0 if ok else 1)
EOF
[[ -x "$android/kernora-android-windows" ]] \
  && grep -Fq '<annotate key="org.freedesktop.policykit.exec.path">/usr/libexec/kernora-android-windows</annotate>' "$android/org.kernora.android.policy" \
  && grep -Fq 'WINDOWS = "/usr/libexec/kernora-android-windows"' "$android/kernora-android-session" \
  && ! grep -Fq 'def widen' "$android/kernora-android-windows" \
  && grep -Fq 'for task_id in running:' "$android/kernora-android-windows" \
  && grep -Fxq 'data/android/kernora-android-windows usr/libexec' "$package_root/debian/kernora-desktop.install" \
  && timeout 60 python3 -I - "$android/kernora-android-windows" <<'EOF' \
  || fail "Android windows don't follow the desktop, or cover each other inside Android"
import importlib.machinery
import importlib.util
import sys

loader = importlib.machinery.SourceFileLoader("windows", sys.argv[1])
windows = importlib.util.module_from_spec(importlib.util.spec_from_loader("windows", loader))
loader.exec_module(windows)
dump = """  * Task{8589fef #230 type=standard A=10127:org.fossify.math U=0 visible=true visibleRequested=true mode=freeform translucent=false sz=1}
    mBounds=Rect(495, 32 - 944, 809)
    * Hist  #0: ActivityRecord{873deea u0 org.fossify.math/.activities.MainActivity} t230}
      requestedOrientation=SCREEN_ORIENTATION_UNSPECIFIED
  * Task{8175f4 #1 type=home U=0 visible=true visibleRequested=true mode=fullscreen translucent=false sz=1}
  * Task{aa11 #231 type=standard A=10130:com.example.game U=0 visible=true visibleRequested=true mode=freeform translucent=false sz=1}
    mBounds=Rect(500, 40 - 940, 800)
      requestedOrientation=SCREEN_ORIENTATION_SENSOR_PORTRAIT
      * Task{8589fef #230 type=standard A=10127:org.fossify.math U=0 visible=true visibleRequested=true mode=freeform translucent=false sz=1}
        bounds=[200,90][1240,750]
"""
windows.android = lambda *args, **kwargs: dump
found = windows.tasks()
ok = sorted(found) == [230, 231] and found[230]["bounds"] == (495, 32, 944, 809) and found[230]["freeform"]
windows.android = lambda *args, **kwargs: """  * Task{1 #40 type=standard A=1000:com.android.settings.root U=0 visible=true mode=freeform translucent=false sz=1}
    mBounds=Rect(1, 1 - 900, 700)
    * Hist  #0: ActivityRecord{2 u0 com.android.settings/.Settings} t40}
"""
ok = ok and windows.tasks()[40]["package"] == "com.android.settings" and "com.android.settings" in windows.tasks()[40]["packages"]
windows.android = lambda *args, **kwargs: dump
sent = []


def fake(*args, **kwargs):
    if args[:2] == ("dumpsys", "activity"):
        return dump
    if args[:2] == ("wm", "size"):
        return "Physical size: 1984x1144\n"
    if args[:2] == ("wm", "density"):
        return "Physical density: 160\n"
    sent.append(args)
    return ""


windows.android = fake
windows.arrange()
ok = ok and ("am", "task", "resize", "231", "1", "1", "441", "761") in sent
ok = ok and ("am", "task", "resize", "230", "3", "3", "452", "780") in sent
sent.clear()
windows.resize("org.fossify.math", 449, 800, 600)
ok = ok and sent[0] == ("am", "task", "resize", "230", "495", "32", "1295", "632")
sent.clear()
known = set()
told = []
windows.tell_display = lambda pipe, package: told.append(package)
windows.open_large(231, known, "pipe")
ok = ok and not sent and known == {"com.example.game"} and told == ["com.example.game"]
windows.open_large(230, known, "pipe")
ok = ok and not sent
known.clear()
dump = dump.replace("requestedOrientation=SCREEN_ORIENTATION_UNSPECIFIED", "resizeMode=RESIZE_MODE_RESIZEABLE\n      requestedOrientation=SCREEN_ORIENTATION_UNSPECIFIED")
windows.open_large(230, known, "pipe")
ok = ok and sent == [("am", "task", "resize", "230", "495", "32", "1559", "632")]
sent.clear()
windows.open_large(230, known, "pipe")
ok = ok and not sent and told[-1] == "org.fossify.math"
windows.reshape(0, "org.fossify.math/.activities.MainActivity")
ok = ok and sent[0] == ("am", "task", "resize", "230", "495", "32", "1272", "481")
ok = ok and ("am", "task", "resize", "231", "1", "1", "441", "761") in sent
sent.clear()
windows.reshape(1, "org.fossify.math/.activities.MainActivity")
ok = ok and all(item[5:] != ("1272", "481") for item in sent) and ("am", "task", "resize", "230", "3", "3", "452", "780") in sent
ui = """<?xml version='1.0' encoding='UTF-8' standalone='yes' ?><hierarchy rotation="0">
<node text="Allow Maps to use this?" resource-id="com.android.permissioncontroller:id/permission_message" class="android.widget.TextView" enabled="true" bounds="[10,10][90,20]" />
<node text="Allow" resource-id="com.android.permissioncontroller:id/permission_allow_button" class="android.widget.Button" enabled="true" bounds="[10,30][90,50]" />
<node text="Don't allow" resource-id="com.android.permissioncontroller:id/permission_deny_button" class="android.widget.Button" enabled="true" bounds="[10,60][90,80]" />
</hierarchy>"""
windows.android = lambda *args, **kwargs: "UI hierchary dumped\n" + ui
question = windows.read_dialog()
ok = ok and question == {"title": "Allow Maps to use this?", "message": "", "buttons": [("Allow", 50, 40), ("Don't allow", 50, 70)]}
windows.android = lambda *args, **kwargs: "broken"
ok = ok and windows.read_dialog() is None
windows.android = lambda *args, **kwargs: ui.replace("<node ", '<node package="org.schabi.newpipe" ')
ok = ok and windows.read_dialog() is None
windows.android = lambda *args, **kwargs: ui.replace("<node ", '<node package="com.android.permissioncontroller" ')
ok = ok and windows.read_dialog() is not None
told.clear()
taps = []
windows.android = lambda *args, **kwargs: taps.append(args) or ""
windows.time.sleep = lambda seconds: None
asked = windows.Questions("pipe")
asked.package = "com.example.maps"
asked.buttons = question["buttons"]
asked.asking = True
asked.ask("com.example.maps")
ok = ok and not taps and not told
asked.answer("none")
ok = ok and not taps and told == ["release com.example.maps"] and not asked.asking
told.clear()
asked.answer("2")
ok = ok and ("input", "tap", "50", "70") in taps and told == ["release com.example.maps"]
taps.clear()
asked.answer("0")
ok = ok and ("input", "keyevent", "4") in taps
ok = ok and windows.ANSWER.match("answer none") and windows.ANSWER.match("answer 3") and not windows.ANSWER.match("answer x")
windows.android = fake
calls = []
windows.android = lambda *args, **kwargs: calls.append(args) or ""
state = []
windows.keep_awake(True, state)
windows.keep_awake(True, state)
windows.keep_awake(False, state)
ok = ok and calls == [("settings", "put", "system", "screen_off_timeout", "2147483647"),
                      ("settings", "put", "system", "screen_off_timeout", "1800000")]
created = windows.EVENT.match("I/wm_create_task: [0,31]")
removed = windows.EVENT.match("I/wm_task_removed( 280): [27,removeTask]")
moved = windows.EVENT.match("I/wm_task_moved( 280): [27,0,0]")
ok = ok and moved.group(1) == "wm_task_moved" and moved.group(2) == "27" and moved.group(3) == "0"
ok = ok and created.group(1) == "wm_create_task" and created.group(3) == "31"
ok = ok and removed.group(1) == "wm_task_removed" and removed.group(2) == "27"
sys.exit(0 if ok else 1)
EOF
grep -Fq 'android wm density "$density"' "$android/kernora-android-sync" \
  && grep -Fq 'settings put global device_name' "$android/kernora-android-sync" \
  && grep -Fq '"$state_dir/google"' "$android/kernora-android-sync" \
  && grep -Fq 'def kernora_density()' "$android/kernora-android-session" \
  && grep -Fq 'PathChanged=%h/.config/kwinoutputconfig.json' "$android/kernora-android-sync.path" \
  || fail "Android apps do not use Kernora's scale and device name"
grep -Fq 'setting secure show_ime_with_hard_keyboard 0' "$android/kernora-android-sync" \
  && grep -Fq 'android ime list -s -a' "$android/kernora-android-sync" \
  && grep -Fq 'android pm disable-user --user 0 "$package"' "$android/kernora-android-sync" \
  && grep -Fq 'setting global hide_error_dialogs 0' "$android/kernora-android-sync" \
  && grep -Fq '"ro.hw_timeout_multiplier": "3"' "$android/kernora-android-device" \
  && grep -Fq 'setting secure user_setup_complete 1' "$android/kernora-android-sync" \
  && grep -Fq 'com.google.android.setupwizard' "$android/kernora-android-sync" \
  && [[ -s "$android/applications/waydroid.com.android.inputmethod.latin.desktop" ]] \
  || fail "Android still shows its keyboard, error dialogs or setup"
[[ -x "$android/kernora-android-keyboard" ]] \
  && grep -Fq '<annotate key="org.freedesktop.policykit.exec.path">/usr/libexec/kernora-android-keyboard</annotate>' "$android/org.kernora.android.policy" \
  && ! grep -Fq -- '--keyboard-prepare' "$android/kernora-android.service" \
  && grep -Fq '"--keyboard-follow"' "$android/kernora-android-session" \
  && grep -Fxq 'data/android/kernora-android-keyboard usr/libexec' "$package_root/debian/kernora-desktop.install" \
  && timeout 60 python3 -I - "$android/kernora-android-session" "$android/kernora-android-keyboard" <<'EOF' \
  || fail "Android apps do not type in Kernora's keyboard layout"
import importlib.machinery
import importlib.util
import sys


def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, path)
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(name, loader))
    loader.exec_module(module)
    return module


session = load("session", sys.argv[1])
keyboard = load("keyboard", sys.argv[2])
names, positions = session.android_layouts([("us", ""), ("ru", ""), ("us", "dvorak"), ("xx", "")])
ok = names == ["english_us", "russian", "english_us_dvorak"] and positions == [0, 1, 2, 0]
script = keyboard.commands(1, ["english_us", "russian"])
ok = ok and script.startswith('[ "$(getprop ro.build.version.sdk)" = 33 ] || exit 0\n')
ok = ok and "service call input 18 i32 1 s16 vendor:1,product:1 i32 1 i32 1 s16 com.android.inputdevices/com.android.inputdevices.InputDeviceReceiver/keyboard_layout_russian\n" in script
ok = ok and "service call input 21 i32 1 s16 vendor:1,product:1 i32 1 i32 1 s16 com.android.inputdevices/com.android.inputdevices.InputDeviceReceiver/keyboard_layout_english_us\n" in script
ok = ok and "keyboard_layout_russian" not in script.split("service call input 21", 1)[1]
sent = []
keyboard.subprocess.run = lambda command, **kwargs: sent.append(command)
keyboard.apply(0, ["english_us"])
ok = ok and sent and sent[0][:4] == ["/usr/bin/waydroid.waydroid", "shell", "--", "sh"] and "input 21" not in sent[0][-1]
sys.exit(0 if ok else 1)
EOF
[[ -x "$android/kernora-android-device" && -x "$android/kernora-android-refresh" ]] \
  && grep -Fq 'ExecStartPre=-/usr/bin/pkexec /usr/libexec/kernora-android-refresh' "$android/kernora-android.service" \
  && grep -Fq '<annotate key="org.freedesktop.policykit.exec.path">/usr/libexec/kernora-android-refresh</annotate>' "$android/org.kernora.android.policy" \
  && grep -Fxq 'exec /usr/libexec/kernora-android refresh' "$android/kernora-android-refresh" \
  && grep -Fxq 'data/android/kernora-android-device usr/libexec' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq 'data/android/kernora-android-refresh usr/libexec' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq '  arm_translation' "$android/kernora-android" \
  && grep -Fq 'try_lock refresh_android' "$android/kernora-android" \
  && grep -Fq '"$device" arm-remove' "$android/kernora-android" \
  && grep -Fq "printf 'arm=%s\ndisplay=%s\n'" "$android/kernora-android" \
  && grep -Fq 'use-wayland)' "$android/kernora-android" \
  && grep -Fq 'Session=/usr/share/wayland-sessions/plasma.desktop' "$android/kernora-android" \
  && grep -Fq 'exec /usr/libexec/kernora-android use-wayland' "$android/kernora-android-refresh" \
  && grep -Fq 'def needs_wayland() -> bool:' "$android/kernora-android-session" \
  && grep -Fq 'service call alarm 3 s16' "$android/kernora-android-sync" \
  && grep -Fq "section 'Android service'" "$android/kernora-android" \
  && grep -Fxq 'data/android/kernora-android-display usr/libexec' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq 'data/android/kernora-android-display.service usr/lib/systemd/user' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq 'data/android/wayland-protocols.json usr/share/kernora/android' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq 'generated/android/KernoraShell.apk usr/share/kernora/android' "$package_root/debian/kernora-desktop.install" \
  && grep -Fq 'BindsTo=kernora-android-display.service' "$android/kernora-android.service" \
  && python3 -c 'import json,sys; t=json.load(open(sys.argv[1])); assert t["xdg_toplevel"]["events"][0]["name"] == "configure" and "zxdg_decoration_manager_v1" in t' "$android/wayland-protocols.json" \
  && timeout 60 python3 -I - "$android/kernora-android-device" <<'EOF' \
  || fail "Android apps do not run ARM apps or pick the right graphics"
import hashlib
import importlib.machinery
import importlib.util
import json
import os
import shutil
import sys
import tempfile
import zipfile


def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, path)
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(name, loader))
    loader.exec_module(module)
    return module


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as handle:
        handle.write(text)


device = load("device", sys.argv[1])
os.chown = lambda *args: None
ok = True
with tempfile.TemporaryDirectory() as root:
    def graphics(cards):
        for name in ("drm", "devices", "drivers"):
            shutil.rmtree(os.path.join(root, name), ignore_errors=True)
        drm = os.path.join(root, "drm")
        os.makedirs(drm)
        for card, driver, boot, connected, render in cards:
            pci = os.path.join(root, "devices", card)
            os.makedirs(os.path.join(root, "drivers", driver), exist_ok=True)
            os.makedirs(pci)
            os.symlink(os.path.join(root, "drivers", driver), os.path.join(pci, "driver"))
            if boot is not None:
                write(os.path.join(pci, "boot_vga"), boot + "\n")
            os.makedirs(os.path.join(drm, card))
            os.symlink(pci, os.path.join(drm, card, "device"))
            write(os.path.join(drm, card + "-HDMI-A-1", "status"), "connected\n" if connected else "disconnected\n")
            if render:
                os.makedirs(os.path.join(drm, render))
                os.symlink(pci, os.path.join(drm, render, "device"))
        device.DRM = drm
        return device.software_graphics()

    ok = ok and graphics([("card0", "i915", "0", False, "renderD128"), ("card1", "nvidia", "1", True, "renderD129")])
    ok = ok and not graphics([("card0", "i915", "1", True, "renderD128"), ("card1", "nvidia", "0", False, "renderD129")])
    ok = ok and graphics([("card0", "bochs-drm", "1", True, None)])
    ok = ok and not graphics([("card0", "amdgpu", "1", True, "renderD128")])
    ok = ok and graphics([("card0", "simple-framebuffer", None, False, None), ("card1", "nouveau", None, True, "renderD128")])

    cpuinfo = os.path.join(root, "cpuinfo")
    device.CPUINFO = cpuinfo
    device.platform.machine = lambda: "x86_64"
    for vendor, name in (("AuthenticAMD", "ndk"), ("GenuineIntel", "houdini"), ("HygonGenuine", "ndk"), ("CentaurHauls", "")):
        write(cpuinfo, f"processor\t: 0\nvendor_id\t: {vendor}\nflags\t\t: sse4_2\n")
        ok = ok and device.translator() == name

    work = os.path.join(root, "waydroid")
    state = os.path.join(root, "state")
    device.CONFIG = os.path.join(work, "waydroid.cfg")
    device.BASE = os.path.join(work, "waydroid_base.prop")
    device.OVERLAY = os.path.join(work, "overlay", "system")
    device.STATE = state
    device.MANAGED = os.path.join(state, "properties")
    device.CACHE = os.path.join(state, "arm")
    device.INSTALLED = os.path.join(state, "arm-installed")
    write(device.CONFIG, "[waydroid]\nimages_path = /var/lib/waydroid/images\n\n[properties]\nro.custom.user = 1\n")
    write(device.BASE, "ro.hardware.gralloc=gbm\n")

    folder = os.path.join(root, "archive")
    prefix = "vendor_intel_proprietary_houdini-0123/"
    package = os.path.join(root, "houdini.zip")
    with zipfile.ZipFile(package, "w") as handle:
        for name in ("prebuilts/lib64/libhoudini.so", "prebuilts/lib/libhoudini.so", "prebuilts/lib/arm/libc.so",
                     "prebuilts/bin/houdini", "prebuilts/etc/init/houdini.rc", "prebuilts/etc/binfmt_misc/arm_exe",
                     "README.md"):
            handle.writestr(prefix + name, name)
    digest = hashlib.sha256(open(package, "rb").read()).hexdigest()
    device.TRANSLATORS["houdini"].update(url="file://" + package, sha256=digest, size=os.path.getsize(package))
    device.download("houdini")
    ok = ok and os.path.isfile(device.archive("houdini"))
    device.install("houdini")
    overlay = device.OVERLAY
    ok = ok and device.installed() == "houdini" and not os.path.exists(device.archive("houdini"))
    ok = ok and os.path.isfile(os.path.join(overlay, "lib/arm/libc.so"))
    ok = ok and os.stat(os.path.join(overlay, "bin/houdini")).st_mode & 0o777 == 0o755
    ok = ok and not os.path.exists(os.path.join(overlay, "etc/init/houdini.rc"))
    ok = ok and not os.path.exists(os.path.join(overlay, "etc/binfmt_misc"))
    write(cpuinfo, "vendor_id\t: GenuineIntel\n")
    ok = ok and device.arm_status() == "yes"

    device.software_graphics = lambda: True
    ok = ok and device.properties("Kernora PC")
    text = open(device.CONFIG).read()
    ok = ok and "ro.dalvik.vm.native.bridge = libhoudini.so" in text and "ro.hardware.egl = swiftshader" in text
    ok = ok and "ro.product.cpu.abilist64 = x86_64,arm64-v8a" in text and "ro.custom.user = 1" in text
    device.applied()
    write(device.BASE, "".join(f"{key}={value}\n" for key, value in device.wanted("Kernora PC").items()))
    ok = ok and not device.properties("Kernora PC")

    device.software_graphics = lambda: False
    device.remove()
    ok = ok and device.installed() == "" and device.arm_status() == "no"
    ok = ok and not os.path.exists(os.path.join(overlay, "lib/arm")) and os.path.isdir(os.path.join(overlay, "lib"))
    ok = ok and device.properties("Kernora PC")
    text = open(device.CONFIG).read()
    ok = ok and "native.bridge" not in text and "ro.hardware.egl" not in text and "ro.custom.user = 1" in text
    ok = ok and device.properties("Kernora PC")
    device.applied()
    ok = ok and not device.properties("Kernora PC")

    device.TRANSLATORS["houdini"]["sha256"] = "0" * 64
    try:
        device.download("houdini")
        ok = False
    except ValueError:
        ok = ok and not os.path.exists(device.archive("houdini") + ".part")
sys.exit(0 if ok else 1)
EOF
grep -Fq 'setting secure screensaver_enabled 0' "$android/kernora-android-sync" \
  && ! grep -Fq 'screen_off_timeout' "$android/kernora-android-sync" \
  && grep -Fq 'AWAKE = "2147483647"' "$android/kernora-android-windows" \
  && grep -Fq 'setting global private_dns_mode off' "$android/kernora-android-sync" \
  && grep -Fq 'save_report' "$android/kernora-android" \
  && grep -Fq 'runuser -u "$user" -- tee "$target"' "$android/kernora-android" \
  && grep -Fq 'data_app_crash' "$android/kernora-android" \
  && grep -Fq 'copy_screens' "$android/kernora-android" \
  && grep -Fq 'Full UI mode is disabled for system stability.' "$android/waydroid" \
  && grep -Fq '"app list" | "session stop"' "$android/waydroid" \
  && grep -Fq 'com.google.android.googlequicksearchbox com.google.android.apps.messaging' "$android/kernora-android-sync" \
  && grep -Fq '"$device" suspend-action stop' "$android/kernora-android" \
  && grep -Fq 'READY = pathlib.Path.home() / ".cache/kernora/android-ready"' "$android/kernora-android-session" \
  && grep -Fq 'exec /usr/libexec/kernora-android graphics-check' "$android/kernora-android-refresh" \
  && grep -Fq 'graphics_check' "$android/kernora-android" \
  && grep -Fq "pgrep -f '^python3 /usr/bin/waydroid.waydroid session start'" "$android/kernora-android" \
  && grep -Fq 'if not booted() and graphics_check():' "$android/kernora-android-session" \
  && ! grep -Fq 'setprop persist.waydroid' "$android/kernora-android-sync" \
  && [[ "$(grep -n 'ExecStartPre=' "$android/kernora-android.service" | head -n 1)" == *'kernora-android-session --prepare'* ]] \
  && timeout 60 python3 -I - "$android/kernora-android-device" "$android/kernora-android-windows" "$android/kernora-android-session" <<'EOF' \
  || fail "Android apps do not span every screen, report problems or keep downloads going"
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile


def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, path)
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(name, loader))
    loader.exec_module(module)
    return module


device = load("device", sys.argv[1])
windows = load("windows", sys.argv[2])
session = load("session", sys.argv[3])
ok = True
with tempfile.TemporaryDirectory() as root:
    drm = os.path.join(root, "drm")
    os.makedirs(os.path.join(root, "virtio0"))
    os.makedirs(os.path.join(root, "drivers", "virtio_gpu"))
    os.symlink(os.path.join(root, "drivers", "virtio_gpu"), os.path.join(root, "virtio0", "driver"))
    for node in ("card0", "renderD128"):
        os.makedirs(os.path.join(drm, node))
        os.symlink(os.path.join(root, "virtio0"), os.path.join(drm, node, "device"))
    os.makedirs(os.path.join(drm, "card0-Virtual-1"))
    with open(os.path.join(drm, "card0-Virtual-1", "status"), "w") as handle:
        handle.write("connected\n")
    device.DRM = drm
    features = os.path.join(root, "virtio0", "features")
    with open(features, "w") as handle:
        handle.write("0000000000000000000000000000000001\n")
    ok = ok and device.software_graphics()
    with open(features, "w") as handle:
        handle.write("1100000000000000000000000000000001\n")
    ok = ok and not device.software_graphics()

    pci = os.path.join(root, "pci0")
    os.makedirs(os.path.join(pci, "virtio1"))
    os.makedirs(os.path.join(root, "drivers", "virtio-pci"))
    os.symlink(os.path.join(root, "drivers", "virtio-pci"), os.path.join(pci, "driver"))
    for node in ("card0", "renderD128"):
        os.remove(os.path.join(drm, node, "device"))
        os.symlink(pci, os.path.join(drm, node, "device"))
    with open(os.path.join(pci, "virtio1", "features"), "w") as handle:
        handle.write("0100000000000000000000000000110010000000100000000000000000000000\n")
    ok = ok and device.software_graphics()
    with open(os.path.join(pci, "virtio1", "features"), "w") as handle:
        handle.write("1100000000000000000000000000110010000000100000000000000000000000\n")
    ok = ok and not device.software_graphics()
    device.FORCED = os.path.join(root, "graphics-software")
    with open(device.FORCED, "w") as handle:
        handle.write(device.signature() + "\n")
    ok = ok and device.software_graphics() and device.signature() == "card0=virtio-pci renderD128=virtio-pci"
    with open(device.FORCED, "w") as handle:
        handle.write("card0=i915\n")
    ok = ok and not device.software_graphics()

    screens = os.path.join(root, "screens")
    device.SCREENS = screens
    device.software_graphics = lambda: False
    device.installed = lambda: ""
    with open(screens, "w") as handle:
        handle.write("0,0,1280,800\n1280,0,1920,1080\n")
    props = device.wanted("Kernora PC")
    ok = ok and props.get("persist.waydroid.width") == "1984" and props.get("persist.waydroid.height") == "1144"
    ok = ok and props.get("persist.wm.debug.caption_on_shell") == "true"
    os.remove(screens)
    ok = ok and "persist.waydroid.width" not in device.wanted("Kernora PC")

layout = {"outputs": [
    {"enabled": True, "priority": 2, "pos": {"x": 1536, "y": 0}, "scale": 1, "rotation": 1, "currentModeId": "b",
     "modes": [{"id": "a", "size": {"width": 800, "height": 600}}, {"id": "b", "size": {"width": 2560, "height": 1440}}]},
    {"enabled": True, "priority": 1, "pos": {"x": 0, "y": 0}, "scale": 1.25, "rotation": 1, "currentModeId": "1",
     "modes": [{"id": "1", "size": {"width": 1920, "height": 1080}}]},
    {"enabled": False, "priority": 3, "pos": {"x": 0, "y": 0}, "scale": 1, "currentModeId": "1",
     "modes": [{"id": "1", "size": {"width": 1024, "height": 768}}]},
]}
session.quiet = lambda *args, **kwargs: subprocess.CompletedProcess(args, 0, json.dumps(layout), "")
ok = ok and session.kernora_screens() == [(0, 0, 1536, 864), (1536, 0, 2560, 1440)]
sys.exit(0 if ok else 1)
EOF
grep -Fxq 'data/android/zz-kernora-composer.rc usr/share/kernora/android' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq 'generated/android/libkernora-android-layers.so usr/share/kernora/android' "$package_root/debian/kernora-desktop.install" \
  && grep -Fq 'kernora-android-layers.c' "$package_root/debian/rules" \
  && grep -Eq '^Build-Depends:.* gcc,' "$package_root/debian/control" \
  && grep -Fq 'composer_target=$work/overlay/system/etc/init' "$android/kernora-android" \
  && grep -Fq 'layers_target=$work/overlay/vendor/lib64' "$android/kernora-android" \
  && grep -Fq 'setenv LD_PRELOAD /vendor/lib64/libkernora-android-layers.so' "$android/zz-kernora-composer.rc" \
  && grep -Fxq '    override' "$android/zz-kernora-composer.rc" \
  || fail "the Android layer library is not packaged or installed"
layers_test=$(mktemp -d)
cat > "$layers_test/harness.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "kernora-android-layers.c"

static char seen[NAME_SIZE + 1];
static const char *gralloc = "minigbm_gbm_mesa";
static unsigned short frame[4] = {0xf800, 0x07e0, 0x001f, 0xffff};
static struct wayland_buffer created;

static void *fake_split(void *result, const void *name)
{
    struct text value = read_string(name);
    memcpy(seen, value.data, value.size);
    seen[value.size] = 0;
    return result;
}

static void *fake_create(void **result, void *display, const struct buffer_metadata *metadata, const void *handle)
{
    (void)display;
    created.handle = handle;
    created.metadata = *metadata;
    *result = &created;
    return result;
}

static int fake_lock(void *mapper, const void *handle, unsigned int usage, const void *bounds, void **address, int *pixel, int *stride)
{
    (void)mapper; (void)handle; (void)usage; (void)bounds; (void)pixel; (void)stride;
    *address = frame;
    return 0;
}

int dladdr(const void *address, struct library_info *info)
{
    (void)address;
    info->file = "hwcomposer";
    return 1;
}

void *dlopen(const char *file, int flags)
{
    (void)file; (void)flags;
    return &created;
}

void *dlsym(void *library, const char *symbol)
{
    (void)library;
    return !strcmp(symbol, SPLIT_SYMBOL) ? (void *)fake_split : !strcmp(symbol, CREATE_SYMBOL) ? (void *)fake_create : (void *)fake_lock;
}

int __system_property_get(const char *name, char *value)
{
    (void)name;
    strcpy(value, gralloc);
    return 0;
}

#define SPLIT _ZN24split_layer_names_helper16split_layer_nameERKNSt3__112basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEE

static void name(const char *text)
{
    size_t size = strlen(text);
    char result[96];
    if (size <= 22) {
        unsigned char small[24] = {0};
        small[0] = (unsigned char)(size << 1);
        memcpy(small + 1, text, size);
        SPLIT(result, small);
        return;
    }
    struct long_string full = {size + 2, size, text};
    full.capacity |= 1;
    SPLIT(result, &full);
}

int main(void)
{
    name("TID:45#org.example/org.example.Main#185");
    name("org.example/org.example.Main(BLAST)#194");
    if (strcmp(seen, "TID:45#org.example/org.example.Main(BLAST)#194")) return 1;
    name("org.example/org.example.Main$Background#195");
    if (strcmp(seen, "TID:45#org.example/org.example.Main$Background#195")) return 2;
    name("org.example/org.example.Player(BLAST)#196");
    if (strcmp(seen, "TID:45#org.example/org.example.Player(BLAST)#196")) return 3;
    name("InputMethod#9");
    if (strcmp(seen, "InputMethod#9")) return 4;
    name("org.other/org.other.Main(BLAST)#7");
    if (strcmp(seen, "org.other/org.other.Main(BLAST)#7")) return 5;
    name("TID:46#org.example/org.example.Main#300");
    name("org.example/org.example.Main(BLAST)#301");
    if (strcmp(seen, "TID:46#org.example/org.example.Main(BLAST)#301")) return 6;
    name("TID:47#org.example/org.example.Second#302");
    name("org.example/org.example.Main(BLAST)#303");
    if (strcmp(seen, "TID:46#org.example/org.example.Main(BLAST)#303")) return 11;
    void *result = NULL;
    int handle = 0;
    struct buffer_metadata metadata = {2, 2, 2, HAL_RGB_565};
    _Z20create_shm_wl_bufferP7displayRK15buffer_metadataPK13native_handle(&result, NULL, &metadata, &handle);
    if (created.metadata.format != HAL_RGB_565 || video_of(&handle) == NULL) return 7;
    void *address = NULL;
    _ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPvPiS9_(NULL, &handle, 3, NULL, &address, NULL, NULL);
    unsigned int *pixel = address;
    if (pixel[0] != 0xff0000ffu || pixel[1] != 0xff00ff00u || pixel[2] != 0xffff0000u || pixel[3] != 0xffffffffu) return 8;
    int other = 0;
    _ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPvPiS9_(NULL, &other, 3, NULL, &address, NULL, NULL);
    if (address != frame) return 9;
    metadata.format = HAL_RGBX_8888;
    _Z20create_shm_wl_bufferP7displayRK15buffer_metadataPK13native_handle(&result, NULL, &metadata, &handle);
    if (video_of(&handle) != NULL) return 10;
    return 0;
}
EOF
gcc -std=c11 -Wall -Wextra -Wno-unused-function -I"$android" -o "$layers_test/harness" "$layers_test/harness.c" \
  && "$layers_test/harness" \
  && gcc -std=c11 -Wall -Wextra -Werror -O2 -fPIC -shared -nostdlib -ffreestanding -fno-builtin -fno-stack-protector \
       -o "$layers_test/layers.so" "$android/kernora-android-layers.c" \
  && [[ $(nm -D --defined-only "$layers_test/layers.so" | grep -c ' T ') -eq 3 ]] \
  || fail "the Android layer library gives video layers the wrong task"
rm -rf "$layers_test"
timeout 60 python3 -I - "$android/kernora-android-display" "$android/wayland-protocols.json" "$android/kernora-android-windows" <<'EOF' \
  || fail "Android windows do not take clicks in the right order"
import importlib.machinery
import importlib.util
import json
import socket
import struct
import sys
import time


def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, path)
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(name, loader))
    loader.exec_module(module)
    return module


display = load("display", sys.argv[1])
windows = load("windows", sys.argv[3])
with open(sys.argv[2], encoding="utf-8") as handle:
    protocols = json.load(handle)
first, second = socket.socketpair()
third, fourth = socket.socketpair()
session = display.Session(protocols, "/tmp", {}, set(), first, third)
session.tell_helper = lambda line: None


def opcode(interface, name):
    return [item["name"] for item in protocols[interface]["events"]].index(name)


def window(client):
    server = session.client_object(client, "wl_surface")
    item = display.Surface()
    item.server_id = server
    item.client_surface = client
    session.surfaces[client] = item
    return item, server


def layer(client, parent):
    item, server = window(client)
    item.parent = parent
    return item, server


keyboard = session.client_object(20, "wl_keyboard")
pointer = session.client_object(21, "wl_pointer")
session.keyboard = 20
one, one_server = window(30)
two, two_server = window(31)
one_layer, one_layer_server = layer(32, one)
two_layer, two_layer_server = layer(33, two)


def enter(server):
    session.event(keyboard, opcode("wl_keyboard", "enter"), struct.pack("<III", 7, server, 0))


def hover(server, x=256, y=512):
    session.event(pointer, opcode("wl_pointer", "enter"), struct.pack("<IIII", 8, server, x, y))


def press(state=1):
    session.event(pointer, opcode("wl_pointer", "button"), struct.pack("<IIII", 9, 1, 272, state))


def sent(interface, name, target):
    word = opcode(interface, name)
    data = bytes(session.client_out)
    found = []
    while data:
        client, header = struct.unpack_from("<II", data)
        size = header >> 16
        if client == target and header & 0xFFFF == word:
            found.append(data[8:size])
        data = data[size:]
    return found


enter(one_server)
ok = session.front is one and len(sent("wl_keyboard", "enter", 20)) == 1 and time.monotonic() < session.input_held_until
session.front_settled()
session.client_out.clear()
hover(two_layer_server)
ok = ok and session.pointed is two and session.parked_motion is not None and not sent("wl_pointer", "motion", 21)
session.event(pointer, opcode("wl_pointer", "motion"), struct.pack("<III", 1, 300, 400))
ok = ok and not sent("wl_pointer", "motion", 21)
enter(two_server)
ok = ok and session.front is two and len(sent("wl_keyboard", "enter", 20)) == 1
press()
press(0)
ok = ok and not sent("wl_pointer", "button", 21) and len(session.held_input) == 3
session.front_settled()
ok = ok and len(sent("wl_pointer", "motion", 21)) == 1 and len(sent("wl_pointer", "button", 21)) == 1
ok = ok and session.held_input and time.monotonic() < session.input_held_until
session.input_held_until = 0.0
session.release_input()
ok = ok and len(sent("wl_pointer", "button", 21)) == 2 and not session.held_input
session.client_out.clear()
session.front = one
session.pointed = two
press()
ok = ok and sent("wl_keyboard", "enter", 20)[0][4:8] == struct.pack("<I", 31)
ok = ok and not sent("wl_pointer", "button", 21) and session.front is two
session.front_settled()
session.input_held_until = 0.0
session.client_out.clear()
session.focused = 30
session.front = two
session.event(keyboard, opcode("wl_keyboard", "key"), struct.pack("<IIII", 9, 1, 30, 1))
ok = ok and sent("wl_keyboard", "enter", 20)[0][4:8] == struct.pack("<I", 30) and session.front is one
session.front_settled()
session.input_held_until = 0.0
session.client_out.clear()
hover(two_layer_server)
ok = ok and not sent("wl_pointer", "motion", 21)
session.event(pointer, opcode("wl_pointer", "axis"), struct.pack("<IIi", 1, 0, 2560))
ok = ok and session.front is two and sent("wl_keyboard", "enter", 20)[0][4:8] == struct.pack("<I", 31)
session.input_held_until = time.monotonic() + 1
session.held_input.append((99, b"gone", False))
session.input_held_until = 0.0
session.release_input()
ok = ok and b"gone" not in bytes(session.client_out)
for item in (first, second, third, fourth):
    item.close()

ok = ok and windows.FOCUS.match("I/wm_focused_root_task: [0,0,72,73,setFocusedTask]").group(1) == "72"
ok = ok and windows.FOCUS.match("I/wm_focused_root_task(  254): [0,0,88,87,moveTaskToFront findTaskToMoveToFront]").group(1) == "88"
ok = ok and not windows.EVENT.match("I/wm_focused_root_task: [0,0,72,73,setFocusedTask]")


class Shell:
    def __init__(self, top=5):
        self.commands = []
        self.top = top

    def run(self, command):
        self.commands.append(command)
        if command == "dumpsys input":
            return ("  Windows:\n      0: name='StatusBar', id=1\n"
                    f"      2: name='Embedded{{Caption of Task={self.top}}}', id=714 frame=[3,3][1120,4]\n"
                    "      7: name='Embedded{Caption of Task=7}', id=674\n")
        if command.startswith("dumpsys"):
            return ("  * Task{abc #7 type=standard A=1000:org.example U=0 visible=true mode=freeform translucent=false sz=1}\n"
                    "    mBounds=Rect(3, 3 - 1120, 633)\n")
        return ""


front = windows.Front.__new__(windows.Front)
front.shell = Shell()
front.reorder(7)
ok = ok and len(front.shell.commands) == 3
ok = ok and "activity_task 49 i32 7 i32 1 i32 3 i32 3 i32 1120 i32 633 i32 3" in front.shell.commands[2]
ok = ok and "service call window 104 i32 1" in front.shell.commands[2]
front.shell = Shell()
front.reorder(8)
ok = ok and len(front.shell.commands) == 2
front.shell = Shell(top=7)
front.reorder(7)
ok = ok and front.shell.commands == ["dumpsys input"]
sys.exit(0 if ok else 1)
EOF
grep -Fq 'loadTemplate("org.kde.plasma.desktop.defaultPanel")' \
  "$data_root/look-and-feel/org.kernora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" \
  && ! grep -Fq 'new Panel' "$data_root/look-and-feel/org.kernora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" \
  || fail "the first login does not use the default panel template"
grep -Fxq 'data/panel/layout.js usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq 'data/panel/kernora-panel-shortcuts usr/libexec' "$package_root/debian/kernora-desktop.install" \
  && grep -Fq 'org.kde.plasma.desktop.defaultPanel/contents/layout.js' "$package_root/debian/kernora-desktop.preinst" \
  && grep -Fq 'org.kde.plasma.desktop.defaultPanel/contents/layout.js' "$package_root/debian/kernora-desktop.postrm" \
  && [[ -x "$data_root/panel/kernora-panel-shortcuts" ]] \
  || fail "Add Panel does not offer the Kernora panel"
! grep -Eq 'kickoff|pager|digitalclock|showdesktop' "$data_root/panel/layout.js" \
  || fail "the default panel still has KDE's widgets"
grep -Fxq 'data/panel/kernora-panel-layout usr/libexec' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq 'data/panel/Panel.qml usr/share/plasma/shells/org.kde.plasma.desktop/contents/views' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq 'generated/plasmoids/org.kernora.datetime usr/share/plasma/plasmoids' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq 'data/panel/statusbar/contents/layout.js usr/share/plasma/layout-templates/org.kernora.desktop.statusBar/contents' "$package_root/debian/kernora-desktop.install" \
  && grep -Fq 'datetime:org.kernora.datetime' "$package_root/debian/rules" \
  && grep -Fq '"$shell/views/Panel.qml"' "$package_root/debian/kernora-desktop.preinst" \
  && grep -Fq '"$shell/views/Panel.qml"' "$package_root/debian/kernora-desktop.postrm" \
  && grep -Fq '"Id": "org.kernora.desktop.statusBar"' "$data_root/panel/statusbar/metadata.json" \
  && grep -Fq 'loadTemplate("org.kernora.desktop.statusBar")' "$data_root/look-and-feel/org.kernora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" \
  && grep -Fq 'bar.addWidget("org.kernora.datetime")' "$data_root/panel/statusbar/contents/layout.js" \
  && grep -Fq 'bar.location = "top"' "$data_root/panel/statusbar/contents/layout.js" \
  || fail "the status bar is not installed"
grep -Fq 'applet.pluginName === "org.kernora.datetime"' "$data_root/panel/Panel.qml" \
  && grep -Fq 'Kirigami.Theme.textColor: root.statusBarClear ? "#ffffff" : undefined' "$data_root/panel/Panel.qml" \
  && grep -Fq 'return root.statusBar ? PlasmaCore.Types.NoBackground' "$data_root/panel/Panel.qml" \
  && grep -Fq 'panel.thickness = 36' "$data_root/panel/Panel.qml" \
  && grep -Fq 'if (statusBar) {' "$data_root/panel/Panel.qml" \
  && grep -Fq 'squarePanel ? ["square", pre, ""] : [pre, ""]' "$data_root/panel/Panel.qml" \
  && grep -Fq 'launcherApplet.configuration?.panelShape' "$data_root/panel/Panel.qml" \
  || fail "the status bar does not draw like a status bar"
grep -Fq 'ConfigFile("kernora-shellrc", "Layout")' "$data_root/panel/layout.js" \
  && grep -Fq 'panel.floating = false;' "$data_root/panel/layout.js" \
  && [[ $(grep -c 'panel.addWidget("org.kde.plasma.panelspacer");' "$data_root/panel/layout.js") -eq 2 ]] \
  && ! grep -Fq 'lengthMode = "fit"' "$data_root/panel/layout.js" "$data_root/panel/statusbar.js" "$data_root/panel/classic.js" \
  && grep -Fq '["org.kde.plasma.systemtray", "org.kde.plasma.notifications", "org.kernora.quicksettings"]' "$data_root/panel/statusbar.js" \
  && grep -Fq 'dock.floating = false;' "$data_root/panel/statusbar.js" \
  && grep -Fq 'layoutConfig.writeEntry("style", "classic");' "$data_root/panel/classic.js" \
  && grep -Fq 'quick.globalShortcut = "Meta+A";' "$data_root/panel/classic.js" \
  && [[ -x "$data_root/panel/kernora-panel-layout" ]] \
  && python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$data_root/panel/kernora-panel-layout" \
  && grep -Fq 'usage: kernora-panel-layout status | migrate | style statusbar|classic | shape square|round | panel square|round' "$data_root/panel/kernora-panel-layout" \
  && grep -Fq 'fcntl.flock(lock, fcntl.LOCK_EX)' "$data_root/panel/kernora-panel-layout" \
  && grep -Fxq 'data/panel/org.kernora.panel-layout.desktop etc/xdg/autostart' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq 'Exec=/usr/libexec/kernora-panel-layout migrate' "$data_root/panel/org.kernora.panel-layout.desktop" \
  && grep -Fxq 'X-KDE-autostart-phase=2' "$data_root/panel/org.kernora.panel-layout.desktop" \
  && ! grep -rq 'kernora_status_bar' "$package_root/debian" \
  && grep -Fq 'panel.floating = false;' "$data_root/panel/Panel.qml" \
  || fail "the bottom panel does not keep its full width when the status bar moves up"
theme_out=$(mktemp -d)
(cd "$package_root/tools" && python3 gen-plasma-theme ../data/symbols "$theme_out/kernora") >/dev/null
grep -Fq 'id="square-center"' "$theme_out/kernora/widgets/panel-background.svg" \
  && grep -Fq 'id="mask-square-center"' "$theme_out/kernora/widgets/panel-background.svg" \
  && grep -Fq 'id="square-center"' "$theme_out/kernora/solid/widgets/panel-background.svg" \
  || fail "the theme has no square panel"
rm -rf "$theme_out"
grep -Fq '"kernora-bar-notifications"' "$package_root/tools/symbols_map.py" \
  && grep -Fq '"kernora-bar-ethernet"' "$package_root/tools/symbols_map.py" \
  && grep -Fq '"kernora-bar-wifi-4"' "$package_root/tools/symbols_map.py" \
  && grep -Fq 'BatteryPill {' "$package_root/data/shell/shade/contents/ui/StatusChip.qml" \
  && grep -Fq 'return "kernora-bar-wifi-off";' "$package_root/data/shell/shade/contents/ui/StatusChip.qml" \
  && grep -Fq 'source: root.backend.mediaIconName || "audio-x-generic"' "$package_root/data/shell/shade/contents/ui/StatusChip.qml" \
  && grep -Fq '"kernora-bar-notifications"' "$data_root/notifications/kernora/CompactRepresentation.qml" \
  && grep -Fq 'fromTop: root.fromTop' "$package_root/data/shell/shade/contents/ui/ShadeWindow.qml" \
  && grep -Fq 'Qt.locale().amText, Qt.locale().pmText' "$package_root/data/shell/datetime/contents/ui/main.qml" \
  && grep -Fq 'msgid "Time and Date"' "$package_root/data/shell/po/plasma_applet_org.kernora.datetime.ru.po" \
  && grep -Fq 'entry name="panelShape"' "$package_root/data/shell/launcher/contents/config/main.xml" \
  && grep -Fq 'square: Plasmoid.configuration.buttonShape !== "round"' "$package_root/data/shell/launcher/contents/ui/main.qml" \
  && grep -Fq 'anchors.topMargin: underStatusBar ? 20 : 0' "$data_root/folderview/FolderView.qml" \
  && grep -Fq 'root.availableScreenRect.y > 0' "$data_root/folderview/FolderView.qml" \
  || fail "the status bar does not look like Googlebook"
grep -Fq 'readonly property string itemUrl: model.blank ? "" : String(model.url)' "$data_root/folderview/FolderView.qml" \
  && grep -Fq 'launcherHelper.connectSource("/usr/bin/kernora-appgroup drop "' "$data_root/folderview/FolderView.qml" \
  && grep -Fq 'if (row !== -1 && main.groupDrop(gridView.itemAt(dropPos.x, dropPos.y), event.mimeData)) {' "$data_root/folderview/FolderView.qml" \
  || fail "dropping an app onto another app does not make a group"
grep -Fq 'taken.indexOf(shortcut) < 0' "$data_root/panel/layout.js" \
  && grep -Fq 'launcher.writeConfig("reclaimShortcuts", true)' "$data_root/panel/layout.js" \
  && grep -Fq 'launcher.reloadConfig()' "$data_root/panel/layout.js" \
  && grep -Fq 'entry name="reclaimShortcuts"' "$package_root/data/shell/launcher/contents/config/main.xml" \
  && grep -Fq '/usr/libexec/kernora-panel-shortcuts' "$package_root/data/shell/launcher/contents/ui/main.qml" \
  || fail "a new panel does not get its shortcuts back"
timeout 60 python3 -I - "$data_root/panel/kernora-panel-shortcuts" <<'EOF' \
  || fail "the panel shortcut helper removes the wrong entries"
import importlib.machinery
import importlib.util
import sys

loader = importlib.machinery.SourceFileLoader("shortcuts", sys.argv[1])
shortcuts = importlib.util.module_from_spec(importlib.util.spec_from_loader("shortcuts", loader))
loader.exec_module(shortcuts)
config = """[kwin]
activate widget 9=Alt+Space,none,Not Plasma

[plasmashell]
activate widget 3=Alt+Space,none,Activate Applications Widget
activate widget 19=Meta+A,none,Activate Quick Settings Widget
activate widget 20=,none,Activate Clipboard Widget
activate widget 21=Meta+Shift+Y,none,Activate Something Of The User
activate widget 64=Meta+V,none,Activate Clipboard Widget
show-on-mouse-pos=none,Meta+V,Show Clipboard Items at Mouse Position

[other]
activate widget 7=Meta+A,none,Not Plasma
"""
ok = shortcuts.stale(config, {"19", "20", "21"}) == ["activate widget 3", "activate widget 64"]
ok = ok and shortcuts.stale(config, {"3", "19", "64"}) == []
ok = ok and shortcuts.stale("[kwin]\n", set()) == []
sys.exit(0 if ok else 1)
EOF
grep -Fq '"ro.product.waydroid.model": model' "$android/kernora-android-device" \
  && grep -Fq '"persist.waydroid.fake_wifi": "*"' "$android/kernora-android-device" \
  && grep -Fq 'Kernora Laptop' "$android/kernora-android" \
  || fail "Android does not call this computer a Kernora laptop or PC"
grep -Fq 'APT::Status-Fd=3' "$android/kernora-android" \
  && grep -Fq 'finish ready' "$android/kernora-android" \
  && grep -Fq 'PathChanged=/var/lib/kernora/android/done' "$android/kernora-android-done.path" \
  && grep -Fq 'ExecStart=/usr/libexec/kernora-android-session --done' "$android/kernora-android-done.service" \
  && grep -Fq 'default.target.wants/kernora-android-done.path' "$package_root/debian/kernora-desktop.links" \
  && grep -Fq 'if len(sys.argv) > 1 and sys.argv[1] == "--google":' "$android/kernora-android-session" \
  && grep -Fq '"sys.user.0.ce_available"' "$android/kernora-android-session" \
  && grep -Fq '"systemd-run", "--user"' "$android/kernora-android-session" \
  && grep -Fq "s/^ *Accounts: " "$android/kernora-android-sync" \
  || fail "setting up Android apps does not show its whole progress or tell when it is done"
grep -Fq 'kernora-appsplash' "$android/waydroid" \
  && ! grep -Fq 'Starting Android' "$android/kernora-android-session" \
  || fail "opening an Android app still talks about starting Android"
for component in android com.android.permissioncontroller com.android.packageinstaller com.google.android.gms; do
  grep -Fxq 'Icon=org.kernora.android' "$android/applications/waydroid.$component.desktop" \
    || fail "Android's $component windows have no Kernora icon"
done
! grep -rh --include='*.desktop' '^Name' "$android" | grep -qi waydroid \
  || fail "a desktop entry shows the Waydroid name"
overlay=$(mktemp -d)
python3 "$package_root/tools/gen-android-overlay" "$overlay/KernoraCaption.apk" >/dev/null || fail "gen-android-overlay fails"
python3 - "$overlay/KernoraCaption.apk" <<'PY' || fail "the caption overlay is incomplete"
import sys, zipfile
names = set(zipfile.ZipFile(sys.argv[1]).namelist())
wanted = {"AndroidManifest.xml", "resources.arsc", "META-INF/CERT.RSA", "META-INF/CERT.SF", "META-INF/MANIFEST.MF",
          "res/drawable/decor_caption_title_focused.xml", "res/drawable/kernora_button_close.xml"}
sys.exit(0 if wanted <= names else 1)
PY
(cd "$overlay" && unzip -q KernoraCaption.apk 'META-INF/*' && openssl smime -verify -inform DER -in META-INF/CERT.RSA -content META-INF/CERT.SF -binary -noverify -out /dev/null 2>/dev/null) \
  || fail "the caption overlay signature does not verify"
cmp -s <(python3 "$package_root/tools/gen-android-overlay" "$overlay/again.apk" >/dev/null && cat "$overlay/again.apk") "$overlay/KernoraCaption.apk" \
  || fail "the caption overlay is not reproducible"
rm -rf "$overlay"
for script in preinst postrm; do
  grep -Fq '/usr/share/applications/waydroid.market.desktop; do' "$package_root/debian/kernora-desktop.$script" \
    && grep -Fq -- '--divert "$file.waydroid" "$file"' "$package_root/debian/kernora-desktop.$script" \
    || fail "$script does not divert Waydroid's command and entries"
done
grep -Fxq 'application/vnd.android.package-archive=org.kernora.apkinstaller.desktop;' "$package_root/data/xdg-mimeapps/mimeapps.list" \
  || fail "APK files do not open in the installer"
grep -Fxq '  - shellprocess@drivers' "$package_root/data/calamares/settings.conf" \
  && grep -Fq 'kernora-drivers install --target' "$package_root/data/calamares/modules/shellprocess-drivers.conf" \
  || fail "the installer does not install graphics drivers"
grep -Fxq 'ColorScheme=KernoraDark' "$defaults" \
  || fail "look-and-feel does not select the Kernora colour scheme"
grep -Fxq 'name=kernora' "$defaults" \
  || fail "look-and-feel does not select the Kernora Plasma theme"

tools_root="$package_root/tools"
python3 "$project_root/tests/test-panel-transparency.py" || fail "panel transparency variants are inconsistent"
for tool in gen-color-schemes gen-icon-theme gen-kdeglobals gen-plasma-theme \
  gen-qml-tokens gen-translations fetch-symbols gen-wallpaper-assets \
  gen-kvantum-theme gen-aurorae-theme gen-avatar gen-avatars gen-terminal-theme gen-greeter-palette \
  gen-keyboard-maps gen-qm gen-installer-icons gen-installer-style gen-browser-theme gen-gtk-theme gen-sound-theme gen-plymouth-theme gen-grub-theme gen-emoji-data; do
  [[ -x "$tools_root/$tool" ]] || fail "design-system tool missing: $tool"
done
grep -Fxq 'pref("extensions.activeThemeID", "theme@kernora.os");' "$package_root/data/librewolf/kernora.js" \
  || fail "LibreWolf does not default to the Kernora theme"
grep -Fxq 'pref("widget.use-xdg-desktop-portal.file-picker", 1);' "$package_root/data/librewolf/kernora.js" \
  || fail "LibreWolf does not pick files in the Kernora chooser"
mimeapps="$package_root/data/xdg-mimeapps/mimeapps.list"
for default in 'x-scheme-handler/https=librewolf.desktop;' 'text/html=librewolf.desktop;' \
  'image/png=org.kernora.photos.desktop;' 'application/json=org.kernora.editor.desktop;'; do
  grep -Fxq "$default" "$mimeapps" || fail "mimeapps.list lacks $default"
done
grep -Fxq "gtk-theme='Kernora'" "$package_root/data/gtk/90_kernora.gschema.override" \
  || fail "GTK applications do not default to the Kernora theme"
for version in 3.0 4.0; do
  grep -Fxq 'gtk-theme-name=Kernora' "$package_root/data/skel-config/gtk-$version/settings.ini" \
    || fail "new accounts do not start with the Kernora GTK $version theme"
done
sh -n "$package_root/data/kconf_update/kernora-gtk-theme.sh" || fail "the GTK theme migration does not parse"
gtk_themes=$(mktemp -d)
for generation in md1 md2 md3; do
  KERNORA_GENERATION=$generation python3 "$tools_root/gen-gtk-theme" "$gtk_themes" >/dev/null \
    || fail "gen-gtk-theme fails for $generation"
done
for theme in Kernora KernoraMD1 KernoraMD2; do
  for file in gtk-3.0/gtk.css gtk-3.0/gtk-dark.css gtk-4.0/gtk.css gtk-4.0/gtk-dark.css; do
    grep -q '@import url("../../Breeze/' "$gtk_themes/$theme/$file" || fail "$theme/$file does not build on Breeze"
  done
done
rm -rf "$gtk_themes"
grep -Fxq 'pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' "$package_root/data/librewolf/kernora.js" \
  || fail "LibreWolf does not load the Kernora dialog style"
link_script="$package_root/data/kconf_update/kernora-librewolf-chrome.sh"
sh -n "$link_script" || fail "the LibreWolf dialog style script does not parse"
browser=$(mktemp -d)
python3 "$tools_root/gen-browser-theme" "$browser/theme.xpi" "$browser/userChrome.css" >/dev/null \
  || fail "gen-browser-theme fails"
grep -Fq 'button[dlgtype][default] {' "$browser/userChrome.css" \
  || fail "the LibreWolf dialog style does not fill the default button"
sed "s|^sheet=.*|sheet=$browser/userChrome.css|" "$link_script" > "$browser/link.sh"
HOME="$browser/new" XDG_CONFIG_HOME="$browser/new/.config" sh "$browser/link.sh"
new_root="$browser/new/.config/librewolf/librewolf"
[[ "$(readlink "$new_root/kernora.default-default/chrome/userChrome.css")" == "$browser/userChrome.css" ]] \
  || fail "a new account's LibreWolf profile does not get the Kernora dialog style"
grep -Fxq '[Install6C4726F70D182CF7]' "$new_root/profiles.ini" \
  && grep -Fxq 'Default=kernora.default-default' "$new_root/installs.ini" \
  || fail "LibreWolf would not use the prepared profile"
own_root="$browser/own/.config/librewolf/librewolf"
mkdir -p "$own_root/mine.default/chrome" "$own_root/plain.default"
printf '[Profile0]\nIsRelative=1\nPath=mine.default\n\n[Profile1]\nIsRelative=1\nPath=plain.default\n' > "$own_root/profiles.ini"
printf 'own\n' > "$own_root/mine.default/chrome/userChrome.css"
HOME="$browser/own" XDG_CONFIG_HOME="$browser/own/.config" sh "$browser/link.sh"
[[ "$(<"$own_root/mine.default/chrome/userChrome.css")" == own ]] \
  || fail "the Kernora dialog style replaced a user's own userChrome.css"
[[ "$(readlink "$own_root/plain.default/chrome/userChrome.css")" == "$browser/userChrome.css" ]] \
  || fail "an existing LibreWolf profile does not get the Kernora dialog style"
[[ ! -e "$own_root/kernora.default-default" ]] || fail "a profile was added next to existing ones"
rm -rf "$browser"
grep -Fxq "theme-name='kernora'" "$package_root/data/gtk/90_kernora.gschema.override" \
  || fail "GTK applications do not default to the Kernora sounds"
grep -Fxq 'gtk-sound-theme-name=kernora' "$package_root/data/skel-config/gtk-3.0/settings.ini" \
  || fail "new accounts do not start with the Kernora sounds"
sh -n "$package_root/data/kconf_update/kernora-sound-theme.sh" || fail "the sound theme migration does not parse"
sh -n "$package_root/data/kconf_update/kernora-terminal-entry.sh" || fail "the terminal entry migration does not parse"
sh -n "$package_root/data/kconf_update/kernora-add-widgets-menu.sh" || fail "the widgets menu migration does not parse"
menu_home=$(mktemp -d)
XDG_CONFIG_HOME="$menu_home" sh "$package_root/data/kconf_update/kernora-add-widgets-menu.sh"
XDG_CONFIG_HOME="$menu_home" sh "$package_root/data/kconf_update/kernora-add-widgets-menu.sh"
[[ "$(grep -c "add widgets=true" "$menu_home/plasma-org.kde.plasma.desktop-appletsrc")" == 1 ]] \
  || fail "the desktop menu does not offer Add Widgets exactly once"
rm -rf "$menu_home"
sh -n "$package_root/data/crash/kernora-panic-report" || fail "the panic report does not parse"
for widget in clock glance weather battery cputemperature calendar media photo note; do
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$package_root/data/widgets/$widget/metadata.json" \
    || fail "the $widget widget metadata is not JSON"
  xmllint --noout "$package_root/data/widgets/$widget/contents/config/main.xml" \
    || fail "the $widget widget configuration is not XML"
  grep -q "^WIDGETS = .*\b$widget\b" "$package_root/debian/rules" || fail "the $widget widget is not built"
  widget_qml="$package_root/data/widgets/$widget/contents/ui/main.qml"
  grep -Fq 'preferredRepresentation: inPanel ? null : fullRepresentation' "$widget_qml" \
    && grep -Fq 'Layout.maximumWidth: root.inPanel ? Layout.preferredWidth : Infinity' "$widget_qml" \
    && grep -Fq 'Layout.maximumHeight: root.inPanel ? Layout.preferredHeight : Infinity' "$widget_qml" \
    || fail "the $widget widget does not become an icon on a panel"
done
grep -Fq 'shown: !otherCard.pluginName.startsWith(main.forPanel ? main.kernoraPrefix : "org.kernora.")' \
    "$package_root/data/explorer/WidgetExplorer.qml" \
  || fail "the panel widget list offers Kernora desktop widgets"
for po in "$package_root"/data/shell/po/plasma_applet_org.kernora.widget.*.ru.po; do
  msgfmt -c -o /dev/null "$po" 2>/dev/null || fail "$(basename "$po") does not compile"
done
grep -Fq 'api.open-meteo.com/v1/forecast' "$package_root/data/widgets/common/WeatherModel.qml" \
  || fail "the weather widgets do not use Open-Meteo"
grep -Fxq 'kernel.panic = 10' "$package_root/data/crash/90-kernora-panic.conf" \
  || fail "a kernel panic would not restart the computer"
python3 "$tools_root/check-contrast" >/dev/null || fail "a colour theme draws text or icons that blend into their background"
grep -Fxq '  - shellprocess@upgrade' "$package_root/data/calamares/settings.conf" \
  || fail "the installer does not bring the new system up to date"
grep -Fq 'full-upgrade' "$package_root/data/calamares/modules/shellprocess-upgrade.conf" \
  || fail "the installer's update step does not upgrade"
sounds=$(mktemp -d)
python3 "$tools_root/gen-sound-theme" "$sounds" desktop-login,bell >/dev/null || fail "gen-sound-theme fails"
grep -Fxq 'Inherits=freedesktop' "$sounds/kernora/index.theme" || fail "the sound theme does not fall back to freedesktop"
[[ "$(head -c 4 "$sounds/kernora/stereo/desktop-login.wav")" == RIFF ]] || fail "the login sound is not a WAV file"
[[ "$(readlink "$sounds/kernora/stereo/bell-window-system.wav")" == bell.wav ]] || fail "the window bell does not use the bell sound"
rm -rf "$sounds"
avatars=$(mktemp -d)
python3 "$tools_root/gen-avatars" "$avatars" >/dev/null || fail "gen-avatars fails"
[[ "$(find "$avatars" -name '*.svg' | wc -l)" -eq 14 ]] || fail "the profile pictures are not fourteen plus the Kernora mark"
grep -l '<path ' "$avatars"/*.svg | wc -l | grep -qx 14 || fail "a profile picture has no waves"
rm -rf "$avatars"
if grep -rIl 'firefox-esr' "$package_root/data" >/dev/null; then
  fail "the desktop still refers to Firefox: $(grep -rIl 'firefox-esr' "$package_root/data" | head -1)"
fi
PYTHONDONTWRITEBYTECODE=1 python3 - "$tools_root" <<'PY' || fail "the Material generations are incomplete"
import sys
sys.path.insert(0, sys.argv[1])
import kernora_design as design
roles = set(design.palette("md3", True))
for generation in design.GENERATIONS:
    for dark in (True, False):
        assert set(design.palette(generation, dark)) == roles, (generation, dark)
for kind, values in design.CORNERS.items():
    assert len(values) == len(design.GENERATIONS), kind
for kind, values in design.ELEVATION_LEVEL.items():
    assert len(values) == len(design.GENERATIONS), kind
PY
icons=$(mktemp -d)
python3 "$tools_root/gen-icon-theme" "$package_root/data/symbols" "$icons/Kernora" >/dev/null \
  || fail "gen-icon-theme fails"
grep -Fxq 'Inherits=breeze-dark,breeze,hicolor' "$icons/Kernora/index.theme" \
  || fail "icon theme does not inherit Breeze and would lose every other icon"
KERNORA_COLOUR=blue python3 "$tools_root/gen-icon-theme" "$package_root/data/symbols" "$icons/Kernora-blue" >/dev/null \
  || fail "gen-icon-theme fails for a colour"
grep -Fxq 'Inherits=Kernora,breeze-dark,breeze,hicolor' "$icons/Kernora-blue/index.theme" \
  || fail "a colour's icons do not fall back to Kernora's"
[[ "$(find "$icons/Kernora-blue/scalable" -name '*.svg' -type f | wc -l)" -eq 17 ]] \
  || fail "a colour's icon theme should hold only the seventeen app icons"
for icon in actions/kernora-quickshare status/kernora-tile-quickshare-on apps/org.kernora.quickshare; do
  [[ -e "$icons/Kernora/scalable/$icon.svg" ]] || fail "the icon theme has no $icon"
done
find "$icons/Kernora-blue" -name 'preferences-system*' | grep -q . \
  && fail "a colour's icons would shadow preferences-system-* through KDE's generic fallback"
python3 - "$package_root/data/explorer" "$icons/Kernora" <<'PY' || fail "the widget picker uses an icon or a preview Kernora does not have"
import pathlib, re, sys
explorer, theme = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
table = (explorer / "widgets.js").read_text()
preview = (explorer / "OtherPreview.qml").read_text()
names = set(re.findall(r'(?:icon|badge|glyph|trailing): "([^"]+)"', table))
for group in re.findall(r'buttons: \[([^\]]*)\]', table):
    names.update(re.findall(r'"([^"]+)"', group))
names.update(re.findall(r'(?:source|icon): "([^"]+)"', preview))
for group in re.findall(r'model: \[([^\]]*)\]', preview, re.S):
    names.update(re.findall(r'"([a-z][a-z0-9.-]*)"', group))
names -= {"primary", "secondary", "tertiary"}
have = {path.stem for path in theme.glob("scalable/*/*.svg")} | {"start-here-kde-symbolic"}
missing = sorted(names - have)
assert not missing, missing
cases = set(re.findall(r'case "([a-z]+)":', preview)) | {"glyph", "button"}
kinds = set(re.findall(r'(?:preview|content): "([a-z]+)"', table))
assert kinds <= cases, sorted(kinds - cases)
PY
rm -rf "$icons"
grep -Fq 'LookAndFeelPackage=org.kernora.desktop' "$tools_root/gen-kdeglobals" \
  || fail "Kernora look-and-feel is not the system default"
PYTHONDONTWRITEBYTECODE=1 python3 "$tools_root/fetch-symbols" --check >/dev/null \
  || fail "vendored Material Symbols do not match data/symbols.lock"
[[ -s "$data_root/symbols/LICENSE" ]] || fail "Material Symbols licence is missing"
[[ -x "$tools_root/draw-symbols" ]] || fail "draw-symbols is missing"
grep -Eq '^[0-9a-f]{64}  kernora_quick_share_(fill1_)?24px.svg$' "$data_root/symbols.lock" \
  || fail "the Quick Share symbol is not in data/symbols.lock"
grep -Fxq 'MShape MShape.qml' "$data_root/shell/m3/qmldir" || fail "m3 has no MShape"

shell_root="$data_root/shell"
for applet in launcher:org.kernora.launcher shade:org.kernora.quicksettings clipboard:org.kernora.clipboard; do
  directory=${applet%%:*}
  id=${applet#*:}
  grep -Fq "\"Id\": \"$id\"" "$shell_root/$directory/metadata.json" \
    || fail "applet $directory does not declare the id $id"
  [[ -s "$shell_root/$directory/contents/ui/main.qml" ]] \
    || fail "applet $directory has no main.qml"
  grep -Fq "\"$id\"" "$data_root/panel/layout.js" \
    || fail "default layout does not place $id"
  [[ -s "$shell_root/po/plasma_applet_$id.ru.po" ]] \
    || fail "applet $id has no Russian catalog"
done
while read -r first second third; do
  file=$second
  [[ "$first" == "singleton" ]] && file=$third
  [[ "$file" == "M3.qml" || -s "$shell_root/m3/$file" ]] \
    || fail "qmldir names a missing component: $file"
done < "$shell_root/m3/qmldir"
if grep -rEn 'M3\.on[A-Z]' "$shell_root" "$data_root/style" >/dev/null; then
  fail "QML uses an M3.on* role; use the *Content spelling"
fi

wallpaper_plugin="$data_root/wallpaper/org.kernora.shapes"
grep -Fq '"Id": "org.kernora.shapes"' "$wallpaper_plugin/metadata.json" \
  || fail "live wallpaper does not declare its id"
for file in main.qml Scene.qml choreography.js config.qml; do
  [[ -s "$wallpaper_plugin/contents/ui/$file" ]] \
    || fail "live wallpaper is missing $file"
done
grep -Fq '"org.kernora.shapes"' \
  "$data_root/look-and-feel/org.kernora.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" \
  || fail "default layout does not select the live wallpaper"

style="$data_root/style/org.kernora.desktop"
grep -Fxq 'module org.kernora.desktop' "$style/qmldir" \
  || fail "Qt Quick style module is misnamed"
grep -Fxq 'import org.kde.desktop auto' "$style/qmldir" \
  || fail "Qt Quick style has no fallback to the desktop style"
while read -r type _version file; do
  [[ "$type" == module || "$type" == import ]] && continue
  [[ -s "$style/$file" ]] || fail "Qt Quick style names a missing control: $file"
done < "$style/qmldir"
grep -Fxq 'export QT_QUICK_CONTROLS_STYLE=org.kernora.desktop' \
  "$data_root/plasma-env/kernora-qtquick-style.sh" \
  || fail "the session does not select the Kernora Qt Quick style"
grep -Fq 'org.kernora.desktop.so' "$package_root/debian/kernora-desktop.links" \
  || fail "Kirigami has no platform plugin under the Kernora style name"

grep -Fxq 'widgetStyle=kvantum-dark' "$defaults" \
  || fail "look-and-feel does not select the Kvantum widget style"
grep -Fxq 'theme=__aurorae__svg__kernora' "$defaults" \
  || fail "look-and-feel does not select the Kernora window decoration"
grep -Fxq 'theme=Kernora' "$data_root/kvantum/kvantum.kvconfig" \
  || fail "Kvantum does not default to the Kernora theme"
grep -Fq '"widgetStyle=kvantum-dark"' "$tools_root/gen-kdeglobals" \
  || fail "system defaults do not select the Kvantum widget style"
if grep -Fq '"AccentColor"' "$tools_root/kde_colors.py"; then
  fail "colour schemes carry an accent colour"
fi
splash="$data_root/look-and-feel/org.kernora.desktop/contents/splash/Splash.qml"
[[ -s "$splash" ]] || fail "session splash is missing"
if grep '^import' "$splash" | grep -Evq '^import (QtQuick|QtQuick\.Window|org\.kernora\.m3)$'; then
  fail "splash imports something unexpected"
fi
grep -Fq 'source: "file:///var/lib/kernora/greeter/wallpaper.qml"' "$splash" \
  && grep -Fq 'return (offset + Date.now() / 1000 / loop) % 1;' "$splash" \
  && ! grep -Fq 'MCircularProgress' "$splash" && ! grep -Fq 'kernora.png' "$splash" \
  || fail "the session splash is a loading screen instead of the wallpaper"
grep -Fxq 'Current=kernora' "$data_root/sddm.conf.d/kernora-theme.conf" \
  || fail "greeter does not use the Kernora login screen"
grep -Fxq 'InputMethod=' "$data_root/sddm.conf.d/kernora-theme.conf" \
  || fail "the login screen would show the virtual keyboard"
[[ -s "$data_root/sddm-theme/kernora/Main.qml" ]] || fail "the Kernora login screen is missing"

settings="$data_root/calamares/settings.conf"
[[ -s "$settings" ]] || fail "installer settings are missing"
grep -Fxq 'branding: kernora' "$settings" \
  || fail "installer does not use the Kernora branding"
for module in partition mount unpackfs users removeuser bootloader umount; do
  grep -Fq "  - $module" "$settings" \
    || fail "installer sequence is missing the $module module"
done

for page in $(awk '/^  - [a-z]+q$/ { print $2 }' "$settings" | sort -u); do
  [[ -s "$data_root/calamares/branding/kernora/$page.qml" ]] \
    || fail "installer page has no Kernora QML: $page"
done
keymaps="$data_root/calamares/branding/kernora/keymaps.js"
for layout in '"us":' '"ru":' '"ru(phonetic)":' '"de":'; do
  grep -Fq "$layout" "$keymaps" || fail "keyboard table lacks $layout"
done

scratch_qm=$(mktemp)
python3 "$tools_root/gen-qm" "$data_root/calamares/lang/calamares-kernora_ru.ts" "$scratch_qm" >/dev/null \
  || fail "the installer's Russian supplement does not compile"
rm -f "$scratch_qm"

for config in unpackfs users removeuser shellprocess bootloader packages partition; do
  [[ -s "$data_root/calamares/modules/$config.conf" ]] \
    || fail "missing module configuration: $config.conf"
done

# shellcheck disable=SC1091
source "$project_root/configs/live/live-user.env"
grep -Fxq "username: $LIVE_USER" "$data_root/calamares/modules/removeuser.conf" \
  || fail "installer does not remove the live account defined for the image"
grep -Fq 'getent group autologin | cut -d: -f4 | grep -q . || rm -f /etc/xdg/kwalletrc' \
  "$data_root/calamares/modules/shellprocess.conf" \
  || fail "an installed system with automatic login would ask to set up a wallet"

logo="$data_root/icons/kernora-logo.svg"
[[ -s "$logo" ]] || fail "logo master is missing"
grep -q 'viewBox=' "$logo" || fail "logo has no viewBox and cannot scale"
grep -q '<image' "$logo" && fail "logo embeds a raster image"
grep -Eq 'stroke="(?!none)' "$logo" 2>/dev/null && fail "logo uses strokes"

branding="$data_root/calamares/branding/kernora/branding.desc"
grep -Fq 'productName:         Kernora OS' "$branding" \
  || fail "installer branding does not name Kernora OS"
[[ -s "$data_root/calamares/branding/kernora/kernora-welcome.png" ]] \
  || fail "installer welcome image is missing"
grep -Fq 'productLogo:    "kernora-logo.png"' "$branding" \
  || fail "branding does not point at the generated logo"
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$tools_root" python3 - "$branding" <<'PYTHON_TEST' \
  || fail "installer sidebar colours drifted from the design tokens"
import sys
import kernora_design as design
text = open(sys.argv[1], encoding="utf-8").read()
for key, role in (("SidebarBackground", "surfaceContainerLow"), ("SidebarText", "onSurfaceVariant"),
                  ("SidebarTextCurrent", "onPrimaryContainer"), ("SidebarBackgroundCurrent", "primaryContainer")):
    line = f'{key}:'.ljust(26) + f'"{design.DARK[role]}"'
    if line not in text:
        raise SystemExit(f"{key} is not {role}")
PYTHON_TEST

grep -Fq 'import org.kernora.shell' "$package_root/data/editmode/ConfigOverlay.qml" \
  && grep -Fq 'overlay.appletSettings.open(applet.plasmoid, overlay)' "$package_root/data/editmode/ConfigOverlay.qml" \
  || fail "a widget's settings end edit mode"

grep -Fq 'motionScale: Kirigami.Units.longDuration > 1 ? Kirigami.Units.longDuration / 200 : 0' "$package_root/tools/gen-qml-tokens" \
  && grep -Fq '!isFinite(x) || !isFinite(v)' "$package_root/data/shell/m3/MSpring.qml" \
  && ! grep -rFq 'Kirigami.Units.longDuration === 0' "$package_root/data/wallpaper" \
  || fail "Reduce motion breaks the shell"
grep -Fq 'function dismiss()' "$package_root/data/editmode/ConfigOverlay.qml" \
  && grep -Fq 'if (!appletsLayout.editMode)' "$package_root/data/editmode/ConfigOverlay.qml" \
  || fail "widget toolbars stay open outside edit mode"
grep -Fq 'readonly property real room:' "$package_root/data/widgets/weather/contents/ui/main.qml" \
  || fail "weather text overflows narrow shapes"
! grep -rFq 'filterByScreen: true' "$package_root/data/wallpaper" \
  && grep -Fq 'x >= screen.x && x < screen.x + screen.width' "$package_root/data/wallpaper/org.kernora.starfall/contents/ui/main.qml" \
  || fail "live wallpapers pause for windows on other screens"
grep -Fq 'coverRetry.restart()' "$package_root/data/widgets/media/contents/ui/main.qml" \
  && grep -Fq 'artRetry.restart()' "$package_root/data/shell/shade/contents/ui/MediaCard.qml" \
  || fail "album art is not retried"
grep -Fq 'function kernoraRecolor()' "$package_root/data/systemmonitor/main.qml" \
  && grep -Fq 'name="kernoraColorBase"' "$package_root/data/systemmonitor/main.xml" \
  && grep -Fq 'org.kde.plasma.systemmonitor/contents/ui/main.qml' "$package_root/debian/kernora-desktop.preinst" \
  && grep -Fq 'org.kde.plasma.systemmonitor/contents/config/main.xml' "$package_root/debian/kernora-desktop.postrm" \
  || fail "system monitor colours ignore the theme"
grep -Fq 'session.requestReboot()' "$package_root/data/shell/launcher/contents/ui/main.qml" \
  && grep -Fq 'if (maysd && (reboot || halt || showAllOptions))' "$package_root/data/look-and-feel/org.kernora.desktop/contents/logout/Logout.qml" \
  || fail "the power menu has no restart"
grep -Fq 'org.freedesktop.policykit.exec.path">/usr/libexec/kernora-greeter-background' "$package_root/data/greeter/org.kernora.greeter-background.policy" \
  && grep -Fq 'config.wallpaper' "$package_root/data/sddm-theme/kernora/Main.qml" \
  && grep -Fq 'readonly property bool ownBackground' "$package_root/data/lockscreen/LockScreen.qml" \
  && grep -Fxq 'WallpaperPlugin=org.kernora.shapes' "$package_root/data/xdg-kscreenlockerrc/kscreenlockerrc" \
  && grep -Fq '/usr/share/kernora/xdg:' "$package_root/data/plasma-env/kernora-config-dirs.sh" \
  || fail "lock and login screens ignore the wallpaper"

lockscreen="$package_root/data/lockscreen/LockScreen.qml"
grep -Fq 'MShapeEcho {' "$lockscreen" && grep -Fq 'echoMode: TextInput.NoEcho' "$lockscreen" \
  || fail "the lock screen still shows plain password dots"
[[ "$(grep -c 'M3.darkScheme' "$lockscreen")" -le 4 ]] || fail "the lock screen card ignores the light theme"
greeter_qml="$package_root/data/sddm-theme/kernora/Main.qml"
grep -Fq 'import org.kernora.m3' "$greeter_qml" && grep -Fq 'MShapeEcho {' "$greeter_qml" \
  && grep -Fq 'M3.colourOverride' "$greeter_qml" && ! grep -Fq 'palette.js' "$greeter_qml" \
  || fail "the login screen does not follow the synced colour and theme"
grep -Fq 'MShapeEcho MShapeEcho.qml' "$package_root/data/shell/m3/qmldir" || fail "MShapeEcho is not registered"
grep -Fq 'MLinearProgress {' "$package_root/data/ui/LinearProgress.qml" \
  && grep -Fq 'MCircularProgress {' "$package_root/data/style/org.kernora.desktop/BusyIndicator.qml" \
  && grep -Fq 'contentItem: MLinearProgress {' "$package_root/data/style/org.kernora.desktop/ProgressBar.qml" \
  || fail "progress bars and spinners are not the wavy expressive ones"
grep -Fq 'readonly property bool waving: wavy && !M3.classic' "$package_root/data/shell/m3/MLinearProgress.qml" \
  && grep -Fq 'shown > 0.1 && shown < 0.95' "$package_root/data/shell/m3/MLinearProgress.qml" \
  || fail "the wave does not flatten for md1/md2 or at the ends of the progress"
grep -Fq 'MLoadingIndicator MLoadingIndicator.qml' "$package_root/data/shell/m3/qmldir" \
  && grep -Fq 'gen-loading-shapes generated/style/org/kernora/m3/loadingshapes.js' "$package_root/debian/rules" \
  || fail "the shape morphing loading indicator is not built"
shapes_out=$(mktemp)
python3 "$package_root/tools/gen-loading-shapes" "$shapes_out"
python3 - "$shapes_out" <<'PY' || fail "loading shapes are not sampled the same way"
import json, re, sys
text = open(sys.argv[1]).read()
samples = int(re.search(r"var samples = (\d+);", text).group(1))
shapes = json.loads(re.search(r"var shapes = (.*);", text).group(1))
assert len(shapes) == 7 and all(len(s) == samples for s in shapes)
assert all(0.2 < r < 0.75 for s in shapes for r in s)
PY
rm -f "$shapes_out"
grep -Fq 'readonly property bool expressive: !M3.classic' "$package_root/data/ui/SegmentedButtons.qml" \
  && grep -Fq '(isFirst ? full : inner + (full - inner) * chosenMorph.value)' "$package_root/data/ui/SegmentedButtons.qml" \
  || fail "segmented buttons are not the connected expressive group"
grep -Fq 'MMorph { id: checkMorph; active: root.checked }' "$package_root/data/ui/IconButton.qml" \
  || fail "icon buttons do not change shape when pressed or checked"
grep -Fq 'MMorph MMorph.qml' "$package_root/data/shell/m3/qmldir" \
  && grep -Fq '"expressiveFast": (0.6, 0.222)' "$package_root/tools/kernora_design.py" \
  && grep -Fq 'MMorph { id: pressMorph; active: surface.control.down }' "$package_root/data/style/org.kernora.desktop/private/ButtonSurface.qml" \
  && grep -Fq 'MMorph { id: checkMorph; active: root.checkable && root.checked }' "$package_root/data/shell/m3/MIconButton.qml" \
  && grep -Fq 'MMorph { id: pressMorph; active: mouse.pressed }' "$package_root/data/shell/m3/MButton.qml" \
  || fail "buttons do not morph on the expressive springs"
grep -Fq 'height + (parent.width - height) * selectMorph.value' "$package_root/data/ui/NavigationItem.qml" \
  || fail "the navigation indicator does not grow out of the icon"
tokens_out=$(mktemp)
python3 "$package_root/tools/gen-qml-tokens" "$tokens_out" >/dev/null
grep -Fq 'readonly property font bodyLargeEmphasized: Qt.font({ family: tokens.typeface, pixelSize: Math.round(16 * tokens.scale), weight: [400, 400, 500][tokens.generationIndex]' "$tokens_out" \
  && grep -Fq 'readonly property int labelLargeEmphasizedLineHeight:' "$tokens_out" \
  && grep -Fq 'menu: [2, 4, 16]' "$tokens_out" \
  && grep -Fq 'role: root.current ? "bodyLargeEmphasized" : "bodyLarge"' "$package_root/data/ui/NavigationItem.qml" \
  || fail "there is no emphasized type for selected items"
rm -f "$tokens_out"
grep -Fq 'color: control.selected ? M3.tertiaryContainer' "$package_root/data/style/org.kernora.desktop/MenuItem.qml" \
  && grep -Fq 'radius: M3.classic ? 0 : 12' "$package_root/data/shell/m3/MMenu.qml" \
  && grep -Fxq 'MENU_RADIUS = 16' "$package_root/tools/gen-kvantum-theme" \
  || fail "menus are not the expressive ones"
for script in kernora-desktop.preinst kernora-desktop.postrm; do
  grep -q '^pickers=.*\bkcm_landingpage\b' "$package_root/debian/$script" \
    && grep -Fq 'systemsettings_qwidgets/kcm_kwintabbox.so' "$package_root/debian/$script" \
    && grep -Fq '"$tasks/ContextMenu.qml" "$tasks/Task.qml"' "$package_root/debian/$script" \
    || fail "the KDE landing page, task switcher picker or task menu are not replaced ($script)"
done
grep -Fq 'color: M3.inverseOnSurface' "$package_root/data/style/org.kernora.desktop/ToolTip.qml" \
  && grep -Fq 'color: M3.inverseSurface' "$package_root/data/style/org.kernora.desktop/ToolTip.qml" \
  || fail "tooltip text does not match the tooltip background"
! grep -Fq 'sourceComponent: busyIndicator' "$package_root/data/taskmanager/Task.qml" \
  && grep -Fq 'running: model.IsStartup && Kirigami.Units.longDuration > 1' "$package_root/data/taskmanager/Task.qml" \
  && grep -Fq 'NumberAnimation { target: icon; property: "scale"; to: 0.82;' "$package_root/data/taskmanager/Task.qml" \
  && grep -Fxq 'data/taskmanager/Task.qml usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/ui' "$package_root/debian/kernora-desktop.install" \
  && grep -Fxq 'Files: data/taskmanager/Task.qml' "$package_root/debian/copyright" \
  || fail "starting apps still get KDE's spinner on their dock icon"
grep -Fq 'i18nd("kernora-ui", "Unpin from panel")' "$package_root/data/taskmanager/ContextMenu.qml" \
  && ! grep -Fq 'internalAction("configure")' "$package_root/data/taskmanager/ContextMenu.qml" \
  && ! grep -Fq 'Task Manager' "$package_root/data/taskmanager/ContextMenu.qml" \
  && grep -Fxq 'data/taskmanager/ContextMenu.qml usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/ui' "$package_root/debian/kernora-desktop.install" \
  || fail "the task icon menu still talks about the KDE task manager"
grep -Fq 'delegate: WidgetCard {' "$package_root/data/explorer/WidgetExplorer.qml" \
  && grep -Fq 'sourceComponent: card.kernora ? kernoraPreview : otherPreview' "$package_root/data/explorer/WidgetCard.qml" \
  && grep -Fq 'cp data/explorer/*.qml data/explorer/*.js' "$package_root/debian/rules" \
  || fail "widgets from KDE are not shown as cards with Material previews"
grep -Fq 'i18nd("plasmashellprivateplugin", "Download New Plasma Widgets")' "$package_root/data/explorer/WidgetExplorer.qml" \
  && grep -Fq '.filter(action => !action.separator && action.text.length > 0 && action.text !== store)' "$package_root/data/explorer/WidgetExplorer.qml" \
  && grep -Fq 'readonly property real widestRow' "$package_root/data/shell/m3/MMenu.qml" \
  || fail "the widgets menu still offers the KDE store or clips its labels"
grep -Fq 'readonly property real handleX: track.level * (width - slot)' "$package_root/data/osd/KernoraOsdItem.qml" \
  || fail "the volume pop-up is not the expressive slider"
for wallpaper in shapes pastel rhythm starfall ribbon; do
  main="$package_root/data/wallpaper/org.kernora.$wallpaper/contents/ui/main.qml"
  grep -Fq 'readonly property bool lockScreen: typeof authenticator !== "undefined"' "$main" \
    && grep -Fq 'function phaseAt(time: double): real {' "$main" \
    && grep -Fq 'intro: root.switched ? 0 : 1' "$main" \
    && grep -Fq 'running: root.running && !root.lockScreen' "$main" \
    && grep -Fq '<entry name="IntroAt" type="String">' "$package_root/data/wallpaper/org.kernora.$wallpaper/contents/config/main.xml" \
    || fail "the $wallpaper wallpaper does not run on the clock or replays its intro at login"
done
for screen in lockscreen/LockScreen.qml sddm-theme/kernora/Main.qml; do
  grep -Fq 'revealSpring.jumpTo(Math.max(0, Math.min(1, ' "$package_root/data/$screen" \
    && grep -Fq 'onWheel: wheel => {' "$package_root/data/$screen" \
    && grep -Fq 'flick > 600 || (flick > -600 && ' "$package_root/data/$screen" \
    || fail "$screen has no swipe up"
done
grep -Fq '"lock_24px.svg": ("lock", "onSurface")' "$package_root/tools/gen-greeter-palette" \
  && grep -Fq 'msgid "Swipe up or start typing"' "$package_root/data/shell/po/kernora-ui.ru.po" \
  || fail "the swipe hint has no icon or translation"
grep -Fq 'leave.start();' "$package_root/data/sddm-theme/kernora/Main.qml" \
  && grep -Fq 'return (offset + Date.now() / 1000 / loop) % 1;' "$package_root/data/sddm-theme/kernora/Main.qml" \
  && grep -Fq 'onFinished: Qt.quit()' "$package_root/data/lockscreen/LockScreen.qml" \
  && ! grep -Fq 'Qt.quit();' "$package_root/data/lockscreen/LockScreen.qml" \
  || fail "login and lock screens do not slide away on success"
grep -Fxq 'data/greeter/kernora-splash-wallpaper usr/libexec' "$package_root/debian/kernora-desktop.install" \
  && grep -Fq '/usr/libexec/kernora-splash-wallpaper || true' "$package_root/data/greeter/kernora-greeter-background" \
  && grep -Fq '/usr/libexec/kernora-splash-wallpaper || true' "$package_root/debian/kernora-desktop.postinst" \
  && [[ -x "$package_root/data/greeter/kernora-splash-wallpaper" ]] \
  || fail "the splash does not learn which wallpaper to show"
grep -Fxq 'FloatingToolbar 1.0 FloatingToolbar.qml' "$package_root/data/ui/qmldir" \
  && grep -Fq 'checkedFill: M3.secondaryContainer' "$package_root/data/ui/IconButton.qml" \
  || fail "there is no floating toolbar"
for file in shell/shade/contents/ui/PanelRow.qml shell/shade/contents/ui/MediaCard.qml shell/launcher/contents/ui/LauncherButton.qml \
    lockscreen/LockScreen.qml lockscreen/KernoraMediaControls.qml look-and-feel/org.kernora.desktop/contents/logout/Logout.qml \
    calamares/branding/kernora/keyboardq.qml calamares/branding/kernora/finishedq.qml; do
  ! grep -Fq 'Behavior on radius' "$package_root/data/$file" && grep -Fq 'MMorph {' "$package_root/data/$file" \
    || fail "$file still changes shape on a plain curve"
done
for script in kernora-desktop.preinst kernora-desktop.postrm; do
  for module in kcm_lookandfeel kcm_desktoptheme kcm_colors kcm_style kcm_icons kcm_cursortheme \
      kcm_kwindecoration kcm_splashscreen kcm_sddm kcm_soundtheme; do
    grep -q "^pickers=.*\b$module\b" "$package_root/debian/$script" \
      || fail "$module can still bring the KDE look back ($script)"
  done
  grep -Fq '/usr/bin/lookandfeeltool /usr/bin/plasma-apply-lookandfeel' "$package_root/debian/$script" \
    && grep -Fq '/usr/bin/kvantummanager' "$package_root/debian/$script" \
    || fail "theme reset tools are still around ($script)"
done
grep -Fxq 'Exec=/usr/bin/kernora-installer --autostart' "$package_root/data/installer/org.kernora.installer-autostart.desktop" \
  && grep -Fxq 'data/installer/org.kernora.installer-autostart.desktop etc/xdg/autostart' "$package_root/debian/kernora-calamares.install" \
  && grep -Fq "grep -qw 'boot=live' /proc/cmdline" "$package_root/data/installer/kernora-installer" \
  || fail "the live session does not open the installer"
grep -Fxq 'Id=kernora_welcome_retired' "$package_root/data/kconf_update/kernora-welcome-retired.upd" \
  && grep -Fxq 'data/kconf_update/kernora-welcome-retired.sh usr/share/kconf_update' "$package_root/debian/kernora-desktop.install" \
  && [[ -x "$package_root/data/kconf_update/kernora-welcome-retired.sh" ]] \
  || fail "welcome stays in the menu after people went through it"
shade_ui="$package_root/data/shell/shade/contents/ui"
grep -Fq 'internet: internetTile' "$shade_ui/ShadeSheet.qml" && grep -Fq 'TileGrid {' "$shade_ui/ShadeSheet.qml" \
  && grep -Fq 'root.detail === "internet" ? internetPanel' "$shade_ui/ShadeSheet.qml" \
  && grep -Fq '"/kernora-quicksettingsrc"' "$shade_ui/TileGrid.qml" \
  && grep -Fq 'handler.addAndActivateConnection(entry.modelData.devicePath, entry.modelData.specificPath, password.text)' "$shade_ui/InternetPanel.qml" \
  && grep -Fq 'device.connectToDevice()' "$shade_ui/BluetoothPanel.qml" \
  && grep -Fq 'readonly property bool wiredConnected' "$shade_ui/sources/NetworkSource.qml" \
  || fail "quick settings are not the android style internet, bluetooth and editable tiles"
grep -Fq 'property bool compact: false' "$package_root/data/shell/m3/MTile.qml" \
  && grep -Fq 'readonly property bool split: hasDetails && !compact && available' "$package_root/data/shell/m3/MTile.qml" \
  || fail "tiles have no small or split form"
grep -Fq 'SessionGroup {' "$package_root/data/shell/launcher/contents/ui/LauncherView.qml" \
  && grep -Fq 'MMorph { id: pressMorph; active: mouse.pressed }' "$package_root/data/shell/launcher/contents/ui/AppTile.qml" \
  || fail "the launcher is not the expressive one"
grep -Fq 'msgid "Edit tiles"' "$package_root/data/shell/po/plasma_applet_org.kernora.quicksettings.ru.po" \
  && grep -Fq 'msgid "Pair new device"' "$package_root/data/shell/po/plasma_applet_org.kernora.quicksettings.ru.po" \
  || fail "the new quick settings are not translated"
grep -Fq 'root.backend.openSettings("appearance")' "$package_root/data/shell/shade/contents/ui/ShadeSheet.qml" \
  && ! grep -Fq 'kcm_lookandfeel' "$package_root/data/shell/shade/contents/ui/ShadeSheet.qml" \
  || fail "the dark theme tile still points at the KDE global theme"
grep -Fxq 'Id=kernora_sound_theme_without_ocean' "$package_root/data/kconf_update/kernora-sound-theme.upd" \
  || fail "ocean users are not moved to the Kernora sounds"
grep -Fq 'GRUB_THEME=/boot/grub/themes/kernora/theme.txt' "$package_root/data/grub/kernora.cfg" \
  && grep -Fq '/usr/libexec/kernora-grub-theme' "$package_root/data/grub/kernora.cfg" \
  && grep -Fq '/usr/libexec/kernora-grub-theme || true' "$package_root/data/greeter/kernora-greeter-background" \
  && grep -Fq '/usr/libexec/kernora-grub-theme || true' "$package_root/debian/kernora-desktop.postinst" \
  && grep -Fq 'generated/grub-themes/$$colour-$$mode $$mode' "$package_root/debian/rules" \
  || fail "the boot menu does not follow the colour and theme"
grep -Fq '/usr/libexec/kernora-boot-theme --initramfs || true' "$package_root/data/greeter/kernora-greeter-background" \
  && grep -Fq '/usr/libexec/kernora-boot-theme || true' "$package_root/debian/kernora-desktop.postinst" \
  && grep -Fq 'gen-plymouth-theme --masks' "$package_root/debian/rules" \
  && grep -Fq 'pack-boot-masks generated/plymouth-masks generated/boot/plymouth.pack' "$package_root/debian/rules" \
  || fail "the boot splash does not follow the colour and theme"
python3 -I -m py_compile "$package_root/data/plymouth/kernora-boot-theme" 2>/dev/null \
  || fail "the boot theme tool does not compile"
find "$package_root/data/plymouth" -name __pycache__ -exec rm -rf {} +
bash -n "$package_root/data/grub/kernora-grub-theme" || fail "the grub theme helper does not parse"
! grep -qi 'ember' "$package_root/data/calamares/branding/kernora/branding.desc" \
  || fail "the installer still says Ember"
grep -Fq '/^[0-9.]+$/.test(version) ? ["", ""] : ["«", "»"]' "$package_root/data/calamares/branding/kernora/welcomeq.qml" \
  || fail "the installer puts quotes around a plain version number"
grep -Fq 'source: parent.user ? parent.user.picture : ""' "$greeter_qml" \
  && ! grep -Fq '"file://" + parent.user.picture' "$greeter_qml" \
  || fail "the login screen breaks the avatar url sddm already gives it"
tokens_out=$(mktemp)
python3 "$package_root/tools/gen-qml-tokens" "$tokens_out" >/dev/null
grep -Fq 'tokens.darkOverride !== null ? tokens.darkOverride : tokens.schemeDark' "$tokens_out" \
  && grep -Fq '"/kdeglobals"' "$tokens_out" && grep -Fq '"/kdedefaults/kdeglobals"' "$tokens_out" \
  || fail "M3 does not read light or dark from the colour scheme"
rm -f "$tokens_out"
helper="$package_root/data/greeter/kernora-greeter-background"
grep -Fq 'colour=%s' "$helper" && grep -Fq 'mode=%s' "$helper" || fail "the greeter helper does not record colour and mode"
plymouth_out=$(mktemp -d)
(cd "$package_root/tools" && python3 gen-plymouth-theme ../data/icons/kernora-logo.svg ../data/symbols "$plymouth_out") >/dev/null
[[ -s "$plymouth_out/wave-0.svg" && -s "$plymouth_out/wave-89.svg" && ! -e "$plymouth_out/bullet.svg" ]] \
  && grep -Fq 'waves[tick % wave_count]' "$plymouth_out/kernora.script" \
  || fail "the boot splash has no wavy indicator"
rm -rf "$plymouth_out"
grep -Fq 'generated/faces/*.png usr/share/kernora/faces' "$package_root/debian/kernora-desktop.install" \
  || fail "the Kernora face is not built in every colour"

grep -Fq 'data/android/pyclip.py usr/share/kernora/android/python' "$package_root/debian/kernora-desktop.install" \
  && grep -Fq '"wl-copy", "--type", "text/plain;charset=utf-8"' "$android/pyclip.py" \
  && grep -Fq 'install --no-install-recommends waydroid wl-clipboard' "$android/kernora-android" \
  || fail "Android apps cannot share the clipboard with the desktop"
grep -Fq 'data/kwin-scripts/kernora-android-place usr/share/kwin/scripts' "$package_root/debian/kernora-desktop.install" \
  && grep -Fq '"EnabledByDefault": true' "$package_root/data/kwin-scripts/kernora-android-place/metadata.json" \
  && grep -Fq 'window.frameGeometry = rect;' "$package_root/data/kwin-scripts/kernora-android-place/contents/code/main.js" \
  && grep -Fq 'window.output.devicePixelRatio' "$package_root/data/kwin-scripts/kernora-android-place/contents/code/main.js" \
  && ! grep -Fq 'Qt.' "$package_root/data/kwin-scripts/kernora-android-place/contents/code/main.js" \
  && grep -Fq 'window.keepAbove = true;' "$package_root/data/kwin-scripts/kernora-android-place/contents/code/main.js" \
  && grep -Fq '"org.kde.kwin.Scripting.start"' "$android/kernora-android-display" \
  || fail "Android windows that grow are not kept on the screen"
grep -Fq 'def asking_task()' "$android/kernora-android-windows" \
  && grep -Fq 'questions.ask(found[1], found[0])' "$android/kernora-android-windows" \
  && grep -Fq 'focus_task(self.task_id)' "$android/kernora-android-windows" \
  && grep -Fq 'if self.top_input_task() == task_id:' "$android/kernora-android-windows" \
  || fail "permission answers can reach the wrong Android window"
grep -Fq 'def warm_up(kind: str, stamp: str)' "$android/kernora-android-session" \
  && grep -Fq 'warm_up(done.get("kind", ""), stamp)' "$android/kernora-android-session" \
  && grep -Fq 'kernora-android-warming' "$android/kernora-android" \
  && grep -Fq 'def start_paths()' "$android/kernora-android-session" \
  || fail "Android is not warmed up after setup"
grep -Fq '(sleep 10; rm -f "$ready")' "$android/waydroid" \
  && grep -Fq 'RATE_WINDOW = 30' "$android/kernora-android-fetch" \
  && grep -Fq 'properties["persist.sys.locale"] = language' "$android/kernora-android-device" \
  && grep -Fq 'data-size' "$android/kernora-android" \
  && grep -Fq 'org.kernora.android.report' "$android/org.kernora.android.policy" \
  && grep -Fq 'data/android/kernora-android-report usr/libexec' "$package_root/debian/kernora-desktop.install" \
  || fail "an Android apps fix from 1.4.74 is missing"
grep -Fq 'loginMode=emptySession' "$package_root/data/xdg-ksmserverrc/ksmserverrc" \
  && grep -Fq 'data/xdg-ksmserverrc/ksmserverrc usr/share/kernora/xdg' "$package_root/debian/kernora-desktop.install" \
  && grep -Fq 'touch /run/reboot-required' "$package_root/debian/kernora-desktop.postinst" \
  || fail "logging in or updating does not behave as Settings says"
PYTHONDONTWRITEBYTECODE=1 python3 -c 'import ast, sys; [ast.parse(open(path).read()) for path in sys.argv[1:]]' \
  "$android/kernora-android-session" "$android/kernora-android-windows" "$android/kernora-android-device" \
  "$android/kernora-android-display" "$android/kernora-android-fetch" "$android/pyclip.py" \
  || fail "an Android helper does not parse"

PYTHONDONTWRITEBYTECODE=1 python3 "$project_root/tests/locales/run.py" \
  || fail "locale restoration and installer preparation failed"

printf 'kernora-desktop source test: OK\n'
