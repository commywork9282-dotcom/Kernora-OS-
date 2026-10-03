// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

.pragma library

const groups = {
    image: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "svgz", "avif", "heic", "heif", "tif", "tiff", "ico", "jxl", "raw", "cr2", "nef", "dng"],
    video: ["mp4", "mkv", "webm", "avi", "mov", "m4v", "wmv", "flv", "mpg", "mpeg", "ogv", "3gp", "ts"],
    audio: ["mp3", "flac", "ogg", "oga", "opus", "wav", "m4a", "aac", "wma", "aiff", "ape", "mka"],
    archive: ["zip", "tar", "gz", "tgz", "xz", "txz", "bz2", "tbz2", "zst", "7z", "rar", "iso", "deb", "rpm", "cab", "lz", "lzma"],
    document: ["pdf", "odt", "ods", "odp", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "rtf", "epub", "djvu"],
    code: ["c", "h", "cpp", "hpp", "cc", "py", "js", "ts", "qml", "rs", "go", "java", "kt", "sh", "bash", "zsh", "rb", "php", "pl", "lua", "css", "scss", "html", "htm", "xml", "json", "yaml", "yml", "toml", "ini", "conf", "cmake", "mk", "sql", "desktop", "service"],
    text: ["txt", "md", "markdown", "log", "csv", "tsv", "rst", "tex", "srt", "nfo", "readme"],
    program: ["appimage", "run", "bin", "exe", "msi", "flatpakref"]
};

const icons = {
    folder: "folder",
    image: "image-x-generic",
    video: "video-x-generic",
    audio: "audio-x-generic",
    archive: "application-x-archive",
    document: "x-office-document",
    code: "text-x-script",
    text: "text-x-generic",
    program: "application-x-executable",
    other: "text-x-generic"
};

const accents = {
    folder: -1,
    image: 4,
    video: 5,
    audio: 1,
    archive: 3,
    document: 0,
    code: 2,
    text: 0,
    program: 2,
    other: -1
};

function suffixOf(name) {
    const dot = name.lastIndexOf(".");
    return dot > 0 ? name.slice(dot + 1).toLowerCase() : "";
}

function kindOf(name, isDir) {
    if (isDir) {
        return "folder";
    }
    const suffix = suffixOf(name);
    for (const kind in groups) {
        if (groups[kind].indexOf(suffix) >= 0) {
            return kind;
        }
    }
    return "other";
}

function iconOf(kind) {
    return icons[kind] || icons.other;
}

function accentOf(kind) {
    return kind in accents ? accents[kind] : -1;
}

function hasThumbnail(name) {
    return ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "ico", "tif", "tiff", "jxl"].indexOf(suffixOf(name)) >= 0;
}

function isArchive(name) {
    return groups.archive.indexOf(suffixOf(name)) >= 0 || /\.tar\.(gz|xz|bz2|zst)$/i.test(name);
}
