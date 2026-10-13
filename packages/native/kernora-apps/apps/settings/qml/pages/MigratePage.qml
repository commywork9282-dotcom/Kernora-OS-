/*
    SPDX-FileCopyrightText: 2026 Lumo contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Bring files from Windows")
    subtitle: i18n("Copy your documents, pictures and more from a Windows drive or a USB stick. Nothing on the Windows drive is changed.")

    property var drives: []
    property var sources: []
    property string source: ""
    property bool scanning: false
    property string opening: ""
    property bool copying: false
    property string current: ""
    property var report: []

    readonly property var folders: [
        { key: "Documents", target: "documents", label: i18n("Documents"), icon: "folder-documents" },
        { key: "Pictures", target: "pictures", label: i18n("Pictures"), icon: "folder-pictures" },
        { key: "Music", target: "music", label: i18n("Music"), icon: "folder-music" },
        { key: "Videos", target: "videos", label: i18n("Videos"), icon: "folder-videos" },
        { key: "Desktop", target: "desktop", label: i18n("Desktop"), icon: "user-desktop" },
        { key: "Downloads", target: "downloads", label: i18n("Downloads"), icon: "folder-download" }
    ]
    property var chosen: ({ Documents: true, Pictures: true, Music: true, Videos: true, Desktop: true, Downloads: false, wallpaper: true, bookmarks: true })

    readonly property var browsers: [
        { name: "Edge", path: "AppData/Local/Microsoft/Edge/User Data/Default/Bookmarks" },
        { name: "Chrome", path: "AppData/Local/Google/Chrome/User Data/Default/Bookmarks" },
        { name: "Brave", path: "AppData/Local/BraveSoftware/Brave-Browser/User Data/Default/Bookmarks" }
    ]
    readonly property string wallpaperPath: "AppData/Roaming/Microsoft/Windows/Themes/TranscodedWallpaper"

    function toggle(key: string, on: bool): void {
        const next = Object.assign({}, chosen);
        next[key] = on;
        chosen = next;
    }

    function scan(): void {
        scanning = true;
        Process.run("lsblk", ["-J", "-p", "-o", "PATH,FSTYPE,MOUNTPOINT,LABEL,SIZE,TYPE"], (code, output) => {
            const found = [];
            try {
                const walk = devices => {
                    for (const device of devices || []) {
                        if (device.type === "part" && ["ntfs", "ntfs3", "exfat", "vfat"].includes(device.fstype)) {
                            found.push({ path: device.path, fstype: device.fstype, mount: device.mountpoint || "", label: device.label || "", size: device.size || "" });
                        }
                        walk(device.children);
                    }
                };
                walk(JSON.parse(output).blockdevices);
            } catch (e) {
            }
            page.drives = found;
            page.findSources();
        });
    }

    function findSources(): void {
        const mounts = drives.filter(d => d.mount.length > 0).map(d => d.mount);
        if (mounts.length === 0) {
            sources = [];
            scanning = false;
            return;
        }
        const script = 'for m in "$@"; do for d in "$m"/Users/*/; do [ -d "$d/Documents" ] || [ -d "$d/Desktop" ] || continue; printf "%s\\n" "${d%/}"; done; if [ -d "$m/Documents" ] || [ -d "$m/Pictures" ]; then printf "%s\\n" "$m"; fi; done';
        Process.run("sh", ["-c", script, "sh"].concat(mounts), (code, output) => {
            page.sources = output.split("\n").filter(line => line.length > 0
                && !/\/Users\/(Default|Default User|Public|All Users)$/.test(line));
            if (page.sources.length === 1 && page.source.length === 0) {
                page.source = page.sources[0];
            }
            page.scanning = false;
        });
    }

    function openDrive(drive: var): void {
        opening = drive.path;
        Process.run("udisksctl", ["mount", "-b", drive.path, "-o", "ro"], (code, output, error) => {
            page.opening = "";
            if (code !== 0) {
                page.notify(error.includes("hibernat") || error.includes("unclean")
                    ? i18n("Windows is still holding this drive. Shut Windows down fully, without Fast Startup, and try again.")
                    : i18n("Couldn't open %1", drive.label || drive.path));
            }
            page.scan();
        });
    }

    function sourceName(path: string): string {
        const user = path.match(/\/Users\/([^/]+)$/);
        return user ? i18n("%1 on Windows", user[1]) : path.split("/").pop() || path;
    }

    function step(queue: var): void {
        if (queue.length === 0) {
            copying = false;
            current = "";
            page.notify(i18n("Your files are here"));
            return;
        }
        const job = queue[0];
        current = job.label;
        job.run(() => step(queue.slice(1)));
    }

    function copyFolder(from: string, to: string, label: string, done: var): void {
        Process.run("sh", ["-c", 'mkdir -p "$2" && cp -rn -- "$1"/. "$2"/', "sh", from, to], code => {
            page.report = page.report.concat([{ label: label, ok: code === 0 }]);
            done();
        });
    }

    function exists(path: string): bool {
        return Files.exists(Qt.url("file://" + path));
    }

    function escape(text: string): string {
        return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }

    function bookmarksHtml(root: var): string {
        const lines = ["<!DOCTYPE NETSCAPE-Bookmark-file-1>", '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">',
                       "<TITLE>Bookmarks</TITLE>", "<H1>Bookmarks</H1>", "<DL><p>"];
        const add = (node, depth) => {
            const pad = "    ".repeat(depth);
            if (node.type === "url") {
                lines.push(pad + '<DT><A HREF="' + escape(node.url) + '">' + escape(node.name) + "</A>");
            } else if (node.children) {
                lines.push(pad + "<DT><H3>" + escape(node.name) + "</H3>");
                lines.push(pad + "<DL><p>");
                for (const child of node.children) {
                    add(child, depth + 1);
                }
                lines.push(pad + "</DL><p>");
            }
        };
        for (const key of ["bookmark_bar", "other", "synced"]) {
            if (root.roots && root.roots[key]) {
                add(root.roots[key], 1);
            }
        }
        lines.push("</DL><p>");
        return lines.join("\n") + "\n";
    }

    function start(): void {
        const from = source;
        const queue = [];
        report = [];
        for (const folder of folders) {
            if (chosen[folder.key] && exists(from + "/" + folder.key)) {
                const target = Files.standardFolder(folder.target).toString().replace(/^file:\/\//, "");
                queue.push({ label: folder.label, run: done => copyFolder(from + "/" + folder.key, decodeURIComponent(target), folder.label, done) });
            }
        }
        if (chosen.wallpaper && exists(from + "/" + wallpaperPath)) {
            queue.push({ label: i18n("Wallpaper"), run: done => {
                const pictures = decodeURIComponent(Files.standardFolder("pictures").toString().replace(/^file:\/\//, ""));
                const target = pictures + "/" + i18n("Windows wallpaper") + ".jpg";
                Process.run("sh", ["-c", 'mkdir -p "$(dirname "$2")" && cp -f -- "$1" "$2"', "sh", from + "/" + wallpaperPath, target], code => {
                    if (code === 0) {
                        Files.setWallpaper(Qt.url("file://" + target));
                    }
                    page.report = page.report.concat([{ label: i18n("Wallpaper"), ok: code === 0 }]);
                    done();
                });
            } });
        }
        if (chosen.bookmarks) {
            for (const browser of browsers) {
                const path = from + "/" + browser.path;
                if (!exists(path)) {
                    continue;
                }
                queue.push({ label: i18n("Bookmarks from %1", browser.name), run: done => {
                    const file = Files.readText(Qt.url("file://" + path));
                    let ok = false;
                    try {
                        const documents = decodeURIComponent(Files.standardFolder("documents").toString().replace(/^file:\/\//, ""));
                        ok = file.ok && Files.writeText(Qt.url("file://" + documents + "/" + i18n("Bookmarks from %1", browser.name) + ".html"),
                                                        bookmarksHtml(JSON.parse(file.text)));
                    } catch (e) {
                        ok = false;
                    }
                    page.report = page.report.concat([{ label: i18n("Bookmarks from %1", browser.name), ok: ok }]);
                    done();
                } });
            }
        }
        if (queue.length === 0) {
            page.notify(i18n("There is nothing to copy from this place"));
            return;
        }
        copying = true;
        step(queue);
    }

    Component.onCompleted: scan()

    FolderDialog {
        id: folderDialog
        title: i18n("Choose the folder with your files")
        onAccepted: {
            const path = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""));
            if (!page.sources.includes(path)) {
                page.sources = page.sources.concat([path]);
            }
            page.source = path;
        }
    }

    Group {
        title: i18n("Where are your files?")
        note: page.scanning ? i18n("Looking for Windows drives…")
            : page.drives.length === 0 && page.sources.length === 0 ? i18n("No Windows drive or USB stick found. Connect one, or choose a folder.") : ""

        Repeater {
            model: page.drives.filter(d => d.mount.length === 0)
            delegate: ListItem {
                id: driveRow
                required property var modelData
                title: modelData.label.length > 0 ? modelData.label : i18n("Drive %1", modelData.path.replace("/dev/", ""))
                subtitle: modelData.size + " · " + i18n("Not opened yet")
                icon: "drive-harddisk"
                trailing: Component {
                    QQC2.Button {
                        text: page.opening === driveRow.modelData.path ? i18n("Opening…") : i18n("Open")
                        flat: true
                        enabled: page.opening.length === 0
                        onClicked: page.openDrive(driveRow.modelData)
                    }
                }
                onClicked: page.openDrive(modelData)
            }
        }

        Repeater {
            model: page.sources
            delegate: ListItem {
                required property string modelData
                title: page.sourceName(modelData)
                subtitle: modelData
                icon: "user-identity"
                accent: page.source === modelData ? 0 : -1
                iconStyle: page.source === modelData ? "circle" : "plain"
                value: page.source === modelData ? i18n("Selected") : ""
                onClicked: page.source = modelData
            }
        }

        ListItem {
            title: i18n("Choose a folder")
            subtitle: i18n("For files you copied to a USB stick yourself")
            icon: "folder-open"
            chevron: true
            onClicked: folderDialog.open()
        }
        ListItem {
            title: i18n("Look again")
            icon: "view-refresh"
            enabled: !page.scanning
            onClicked: page.scan()
        }
    }

    Group {
        title: i18n("What to bring")
        visible: page.source.length > 0
        note: i18n("Files you already have here are kept; nothing is overwritten. Bookmarks are saved in Documents: open them in LibreWolf with Bookmarks › Manage bookmarks › Import and Backup › Import Bookmarks from HTML.")

        Repeater {
            model: page.folders
            delegate: ListItem {
                required property var modelData
                title: modelData.label
                icon: modelData.icon
                checkable: true
                checked: page.chosen[modelData.key] === true
                enabled: !page.copying
                onToggled: on => page.toggle(modelData.key, on)
            }
        }
        ListItem {
            title: i18n("Wallpaper")
            icon: "preferences-desktop-wallpaper"
            checkable: true
            checked: page.chosen.wallpaper === true
            enabled: !page.copying
            onToggled: on => page.toggle("wallpaper", on)
        }
        ListItem {
            title: i18n("Browser bookmarks")
            subtitle: i18n("From Edge, Chrome and Brave")
            icon: "bookmarks"
            checkable: true
            checked: page.chosen.bookmarks === true
            enabled: !page.copying
            onToggled: on => page.toggle("bookmarks", on)
        }
    }

    RowLayout {
        width: parent.width
        visible: page.source.length > 0
        spacing: 16
        LinearProgress {
            Layout.fillWidth: true
            indeterminate: true
            visible: page.copying
        }
        MText {
            Layout.fillWidth: !page.copying
            role: "labelLarge"
            color: M3.surfaceVariantContent
            text: page.copying ? i18n("Copying %1…", page.current) : ""
        }
        QQC2.Button {
            text: i18n("Bring my files")
            highlighted: true
            enabled: !page.copying
            onClicked: page.start()
        }
    }

    Group {
        title: i18n("Done")
        visible: page.report.length > 0 && !page.copying

        Repeater {
            model: page.report
            delegate: ListItem {
                required property var modelData
                title: modelData.label
                subtitle: modelData.ok ? i18n("Copied") : i18n("Some files could not be copied")
                icon: modelData.ok ? "dialog-ok" : "dialog-warning"
                interactive: false
            }
        }
        ListItem {
            title: i18n("Open Files")
            icon: "org.kernora.files"
            chevron: true
            onClicked: Process.launchApplication("org.kernora.files.desktop", [])
        }
    }
}
