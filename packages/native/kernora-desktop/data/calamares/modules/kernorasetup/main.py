# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-3.0-or-later

import gettext
import json
import os
import re
import shutil

import libcalamares

_ = gettext.translation("calamares-python", localedir=libcalamares.utils.gettext_path(),
                        languages=libcalamares.utils.gettext_languages(), fallback=True).gettext


def pretty_name():
    return _("Configuring the user account.")


def target_user(root, name):
    with open(os.path.join(root, "etc/passwd"), encoding="utf-8") as passwd:
        for line in passwd:
            fields = line.rstrip("\n").split(":")
            if len(fields) >= 6 and fields[0] == name:
                return int(fields[2]), int(fields[3]), fields[5]
    return None


def install_avatar(root, name, source):
    found = target_user(root, name)
    if found is None:
        return
    uid, gid, home = found
    home = os.path.join(root, home.lstrip("/"))
    if os.path.isdir(home):
        face = os.path.join(home, ".face")
        shutil.copyfile(source, face)
        os.chown(face, uid, gid)
        os.chmod(face, 0o644)
    icons = os.path.join(root, "var/lib/AccountsService/icons")
    users = os.path.join(root, "var/lib/AccountsService/users")
    os.makedirs(icons, mode=0o775, exist_ok=True)
    os.makedirs(users, mode=0o700, exist_ok=True)
    icon = os.path.join(icons, name)
    shutil.copyfile(source, icon)
    os.chmod(icon, 0o644)
    entry = os.path.join(users, name)
    lines = []
    if os.path.isfile(entry):
        with open(entry, encoding="utf-8") as existing:
            lines = [line for line in existing.read().splitlines() if not line.startswith("Icon=")]
    if "[User]" not in lines:
        lines.insert(0, "[User]")
    lines.insert(lines.index("[User]") + 1, "Icon=/var/lib/AccountsService/icons/" + name)
    if not any(line.startswith("SystemAccount=") for line in lines):
        lines.append("SystemAccount=false")
    with open(entry, "w", encoding="utf-8") as out:
        out.write("\n".join(lines) + "\n")
    os.chmod(entry, 0o600)


def set_entry(path, group, key, value, uid, gid):
    lines = []
    if os.path.isfile(path):
        with open(path, encoding="utf-8") as existing:
            lines = existing.read().splitlines()
    header = "[" + group + "]"
    if header not in lines:
        if lines and lines[-1] != "":
            lines.append("")
        lines.append(header)
    start = lines.index(header) + 1
    end = start
    while end < len(lines) and not lines[end].startswith("["):
        end += 1
    section = [line for line in lines[start:end] if not line.startswith(key + "=")]
    section.insert(0, key + "=" + value)
    lines[start:end] = section
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as out:
        out.write("\n".join(lines) + "\n")
    os.chown(path, uid, gid)


def style_values(style):
    wallpaper = str(style.get("wallpaper") or "org.kernora.shapes")
    colour = str(style.get("colour") or "kernora")
    dark = bool(style.get("dark", True))
    return wallpaper, colour, dark


def greeter_state(root, name, wallpaper, colour, mode):
    found = target_user(root, name)
    if found is None:
        return
    uid, gid, home = found
    base = os.path.join(root, home.lstrip("/"))
    if not os.path.isdir(base):
        return
    local = os.path.join(base, ".local")
    state = os.path.join(local, "state")
    for folder, mode_bits in ((local, 0o755), (state, 0o700)):
        if not os.path.isdir(folder):
            os.makedirs(folder)
            os.chown(folder, uid, gid)
            os.chmod(folder, mode_bits)
    path = os.path.join(state, "kernora-update-notifierstaterc")
    for key, value in (("plugin", wallpaper), ("image", ""), ("stamp", "0"), ("colour", colour), ("mode", mode)):
        set_entry(path, "Greeter", key, value, uid, gid)
    os.chmod(path, 0o600)


def sync_greeter(root, name, style):
    wallpaper, colour, dark = style_values(style)
    mode = "dark" if dark else "light"
    if not re.match(r"^org\.kernora\.[a-z]+$", wallpaper) or not re.match(r"^[a-z]+(-[a-z]+)*$", colour):
        return
    if libcalamares.utils.target_env_call(["/usr/libexec/kernora-greeter-background", wallpaper, "", colour, mode]) != 0:
        return
    greeter_state(root, name, wallpaper, colour, mode)


def install_style(root, name, style):
    found = target_user(root, name)
    if found is None:
        return
    uid, gid, home = found
    config = os.path.join(root, home.lstrip("/"), ".config")
    if not os.path.isdir(os.path.dirname(config)):
        return
    if not os.path.isdir(config):
        os.makedirs(config)
        os.chown(config, uid, gid)
    shapes = "true" if style.get("originalShapes") else "false"
    set_entry(os.path.join(config, "kernorarc"), "Icons", "originalShapes", shapes, uid, gid)
    wallpaper, colour, dark = style_values(style)
    if wallpaper == "org.kernora.shapes" and colour == "kernora" and dark:
        return
    path = os.path.join(config, "kernora-setup-style")
    set_entry(path, "Style", "wallpaper", wallpaper, uid, gid)
    set_entry(path, "Style", "colour", colour, uid, gid)
    set_entry(path, "Style", "dark", "true" if dark else "false", uid, gid)


def user_config(root, name):
    found = target_user(root, name)
    if found is None:
        return None
    uid, gid, home = found
    config = os.path.join(root, home.lstrip("/"), ".config")
    if not os.path.isdir(os.path.dirname(config)):
        return None
    if not os.path.isdir(config):
        os.makedirs(config)
        os.chown(config, uid, gid)
    return config, uid, gid


def font_entry(size, weight):
    return "Google Sans Flex,{:g},-1,5,{},0,0,0,0,0,0,0,0,0,0,1".format(size, weight)


def install_accessibility(root, name, chosen):
    found = user_config(root, name)
    if found is None:
        return
    config, uid, gid = found
    path = os.path.join(config, "kdeglobals")
    try:
        size = float(chosen.get("fontSize", 10.5))
    except (TypeError, ValueError):
        size = 10.5
    if size in (12, 13.5, 15):
        small = size - 1.5
        for key, value in (("font", font_entry(size, 400)), ("menuFont", font_entry(size, 400)),
                           ("toolBarFont", font_entry(small, 400)), ("smallestReadableFont", font_entry(small, 400))):
            set_entry(path, "General", key, value, uid, gid)
        set_entry(path, "WM", "activeFont", font_entry(size, 500), uid, gid)
    if chosen.get("reduceMotion") is True:
        set_entry(path, "KDE", "AnimationDurationFactor", "0", uid, gid)


def mark_first_login(root, name):
    found = user_config(root, name)
    if found is None:
        return
    config, uid, gid = found
    set_entry(os.path.join(config, "kernora-first-login"), "Setup", "firstLogin", "true", uid, gid)


def hide_welcome(root, name):
    found = target_user(root, name)
    if found is None:
        return
    uid, gid, home = found
    config = os.path.join(root, home.lstrip("/"), ".config")
    if not os.path.isdir(os.path.dirname(config)):
        return
    if not os.path.isdir(config):
        os.makedirs(config)
        os.chown(config, uid, gid)
    welcome = os.path.join(config, "kernora-welcomerc")
    set_entry(welcome, "General", "ShowOnLogin", "false", uid, gid)
    try:
        with open(os.path.join(root, "usr/share/kernora/whatsnew.json"), encoding="utf-8") as notes:
            latest = json.load(notes)[0]["id"]
    except (OSError, ValueError, LookupError, TypeError):
        latest = ""
    if latest:
        set_entry(welcome, "WhatsNew", "Seen", str(latest), uid, gid)


def run():
    storage = libcalamares.globalstorage
    root = storage.value("rootMountPoint")
    name = storage.value("username")
    if not root or not name:
        return None
    avatar = storage.value("kernoraAvatar")
    if avatar and os.path.isfile(avatar):
        try:
            install_avatar(root, name, avatar)
        except OSError as error:
            libcalamares.utils.warning("kernorasetup: avatar not copied: {}".format(error))
    style = storage.value("kernoraStyle")
    if isinstance(style, str):
        try:
            style = json.loads(style)
        except ValueError:
            style = None
    if not isinstance(style, dict):
        style = {}
    try:
        install_style(root, name, style)
    except OSError as error:
        libcalamares.utils.warning("kernorasetup: style not saved: {}".format(error))
    try:
        sync_greeter(root, name, style)
    except OSError as error:
        libcalamares.utils.warning("kernorasetup: login screen keeps its style: {}".format(error))
    chosen = storage.value("kernoraAccessibility")
    if isinstance(chosen, str):
        try:
            chosen = json.loads(chosen)
        except ValueError:
            chosen = None
    if isinstance(chosen, dict):
        try:
            install_accessibility(root, name, chosen)
        except OSError as error:
            libcalamares.utils.warning("kernorasetup: accessibility not saved: {}".format(error))
    try:
        mark_first_login(root, name)
    except OSError as error:
        libcalamares.utils.warning("kernorasetup: first login screen skipped: {}".format(error))
    try:
        hide_welcome(root, name)
    except OSError as error:
        libcalamares.utils.warning("kernorasetup: welcome stays on: {}".format(error))
    return None
