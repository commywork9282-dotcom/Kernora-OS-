# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-3.0-or-later

import gettext
import json
import os
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
    wallpaper = str(style.get("wallpaper") or "org.kernora.shapes")
    colour = str(style.get("colour") or "kernora")
    dark = bool(style.get("dark", True))
    if wallpaper == "org.kernora.shapes" and colour == "kernora" and dark:
        return
    path = os.path.join(config, "kernora-setup-style")
    set_entry(path, "Style", "wallpaper", wallpaper, uid, gid)
    set_entry(path, "Style", "colour", colour, uid, gid)
    set_entry(path, "Style", "dark", "true" if dark else "false", uid, gid)


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
    if isinstance(style, dict):
        try:
            install_style(root, name, style)
        except OSError as error:
            libcalamares.utils.warning("kernorasetup: style not saved: {}".format(error))
    try:
        hide_welcome(root, name)
    except OSError as error:
        libcalamares.utils.warning("kernorasetup: welcome stays on: {}".format(error))
    return None
