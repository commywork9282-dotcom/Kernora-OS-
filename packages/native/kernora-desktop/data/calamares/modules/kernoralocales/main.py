import gettext
import subprocess

import libcalamares

_ = gettext.translation("calamares-python", localedir=libcalamares.utils.gettext_path(),
                        languages=libcalamares.utils.gettext_languages(), fallback=True).gettext


def pretty_name():
    return _("Configuring locales.")


def run():
    root = libcalamares.globalstorage.value("rootMountPoint")
    if not root:
        return "Locale configuration error", "The installation target is missing."
    command = ["/usr/libexec/kernora-locales", "--root", root]
    result = subprocess.run(command, text=True, capture_output=True)
    if result.returncode:
        return "Could not prepare selected locales", result.stderr
    return None
