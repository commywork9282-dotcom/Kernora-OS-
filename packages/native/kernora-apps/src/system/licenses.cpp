// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "licenses.h"

#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>

#include <KLocalizedString>

Licenses::Licenses(QObject *parent)
    : QObject(parent)
{
}

static QString copyrightFile(const QString &package)
{
    const QString own = QStringLiteral("/usr/share/doc/%1/copyright").arg(package);
    if (QFileInfo::exists(own)) {
        return own;
    }
    return QStringLiteral("/usr/share/kernora/copyright/%1").arg(package);
}

QString Licenses::licenseSummary(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    QStringList names;
    static const QRegularExpression field(QStringLiteral("^License:\\s*(\\S.*)$"));
    int lines = 0;
    while (!file.atEnd() && lines++ < 4000) {
        const QString line = QString::fromUtf8(file.readLine()).trimmed();
        const auto match = field.match(line);
        if (!match.hasMatch()) {
            continue;
        }
        const QStringList parts = match.captured(1).split(QRegularExpression(QStringLiteral("\\s+(or|and)\\s+")), Qt::SkipEmptyParts);
        for (QString part : parts) {
            part = part.remove(QLatin1Char('(')).remove(QLatin1Char(')')).trimmed();
            if (!part.isEmpty() && !names.contains(part) && part.length() < 40) {
                names.append(part);
            }
        }
    }
    return names.mid(0, 4).join(QStringLiteral(", "));
}

QVariantList Licenses::components() const
{
    struct Component {
        const char *package;
        QString name;
        QString description;
        const char *homepage;
    };
    const QList<Component> notable = {
        {"linux-image-amd64", QStringLiteral("Linux"), i18n("The operating system kernel"), "https://kernel.org"},
        {"base-files", QStringLiteral("Debian"), i18n("The distribution Lumo is based on"), "https://www.debian.org"},
        {"plasma-workspace", QStringLiteral("KDE Plasma"), i18n("The desktop technology under the Lumo shell"), "https://kde.org/plasma-desktop"},
        {"kwin-common", QStringLiteral("KWin"), i18n("The window manager and compositor"), "https://kde.org"},
        {"libkf6coreaddons6", QStringLiteral("KDE Frameworks"), i18n("Libraries used by the desktop and the applications"), "https://develop.kde.org/products/frameworks"},
        {"libqt6core6t64", QStringLiteral("Qt"), i18n("The application framework"), "https://www.qt.io"},
        {"kernora-desktop", QStringLiteral("Material Symbols"), i18n("Icons by Google, Apache License 2.0"), "https://fonts.google.com/icons"},
        {"kernora-desktop", QStringLiteral("Google Sans Flex"), i18n("The system typeface by Google, SIL Open Font License 1.1"), "https://fonts.google.com/specimen/Google+Sans+Flex"},
        {"fonts-roboto-unhinted", QStringLiteral("Roboto"), i18n("The boot menu typeface by Google"), "https://fonts.google.com/specimen/Roboto"},
        {"qt-style-kvantum", QStringLiteral("Kvantum"), i18n("The engine that draws application widgets"), "https://github.com/tsujan/Kvantum"},
        {"librewolf", QStringLiteral("LibreWolf"), i18n("The web browser, built from Firefox"), "https://librewolf.net"},
        {"calamares", QStringLiteral("Calamares"), i18n("The system installer"), "https://calamares.io"},
        {"systemd", QStringLiteral("systemd"), i18n("The system and service manager"), "https://systemd.io"},
        {"network-manager", QStringLiteral("NetworkManager"), i18n("Network connections"), "https://networkmanager.dev"},
        {"pipewire", QStringLiteral("PipeWire"), i18n("Sound and screen sharing"), "https://pipewire.org"},
        {"mesa-vulkan-drivers", QStringLiteral("Mesa"), i18n("Graphics drivers"), "https://mesa3d.org"},
        {"alacritty", QStringLiteral("Alacritty"), i18n("The terminal"), "https://alacritty.org"},
    };
    QVariantList list;
    for (const Component &component : notable) {
        const QString package = QString::fromLatin1(component.package);
        const QString path = copyrightFile(package);
        if (!QFileInfo::exists(path)) {
            continue;
        }
        list.append(QVariantMap{{QStringLiteral("package"), package},
                                {QStringLiteral("name"), component.name},
                                {QStringLiteral("description"), component.description},
                                {QStringLiteral("licenses"), licenseSummary(path)},
                                {QStringLiteral("copyright"), path},
                                {QStringLiteral("homepage"), QString::fromLatin1(component.homepage)}});
    }
    return list;
}

QVariantList Licenses::packages() const
{
    QVariantList list;
    QFile status(QStringLiteral("/var/lib/dpkg/status"));
    if (!status.open(QIODevice::ReadOnly)) {
        return list;
    }
    QString package;
    QString version;
    bool installed = false;
    auto flush = [&]() {
        if (!package.isEmpty() && installed) {
            QString path = copyrightFile(package);
            if (!QFileInfo::exists(path)) {
                path = copyrightFile(package.section(QLatin1Char(':'), 0, 0));
            }
            if (QFileInfo::exists(path)) {
                list.append(QVariantMap{{QStringLiteral("package"), package},
                                        {QStringLiteral("version"), version},
                                        {QStringLiteral("copyright"), path}});
            }
        }
        package.clear();
        version.clear();
        installed = false;
    };
    while (!status.atEnd()) {
        const QByteArray line = status.readLine();
        if (line.trimmed().isEmpty()) {
            flush();
        } else if (line.startsWith("Package: ")) {
            package = QString::fromUtf8(line.mid(9)).trimmed();
        } else if (line.startsWith("Version: ")) {
            version = QString::fromUtf8(line.mid(9)).trimmed();
        } else if (line.startsWith("Status: ")) {
            installed = line.contains("install ok installed");
        }
    }
    flush();
    std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("package")).toString() < b.toMap().value(QStringLiteral("package")).toString();
    });
    return list;
}

QString Licenses::text(const QString &path) const
{
    if (!path.startsWith(QLatin1String("/usr/share/doc/")) && !path.startsWith(QLatin1String("/usr/share/common-licenses/"))) {
        return QString();
    }
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    return QString::fromUtf8(file.readAll());
}
