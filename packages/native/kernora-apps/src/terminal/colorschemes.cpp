// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "colorschemes.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QVariantMap>

namespace
{
const QStringList colourNames{QStringLiteral("black"), QStringLiteral("red"),     QStringLiteral("green"), QStringLiteral("yellow"),
                              QStringLiteral("blue"),  QStringLiteral("magenta"), QStringLiteral("cyan"),  QStringLiteral("white")};

QString presetDirectory()
{
    const QString override = qEnvironmentVariable("KERNORA_QML_TERMINAL");
    if (!override.isEmpty()) {
        return QDir(override).absoluteFilePath(QStringLiteral("../schemes"));
    }
    return QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("kernora/terminal/schemes"), QStandardPaths::LocateDirectory);
}

QString userDirectory()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/kernora-terminal/schemes");
}

QColor colour(QString value)
{
    value = value.trimmed();
    if (value.startsWith(QLatin1Char('"')) || value.startsWith(QLatin1Char('\''))) {
        value = value.mid(1);
    }
    if (value.endsWith(QLatin1Char('"')) || value.endsWith(QLatin1Char('\''))) {
        value.chop(1);
    }
    if (value.startsWith(QLatin1String("0x"), Qt::CaseInsensitive)) {
        value = QLatin1Char('#') + value.mid(2);
    }
    const QColor result = QColor::fromString(value);
    return result.isValid() && value.startsWith(QLatin1Char('#')) ? result : QColor();
}

QString colourText(const QColor &colour)
{
    return QStringLiteral("%1,%2,%3").arg(colour.red()).arg(colour.green()).arg(colour.blue());
}
}

ColorSchemes::ColorSchemes()
{
    reload();
}

QString ColorSchemes::directory() const
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/kernora-terminal/color-schemes");
}

QString ColorSchemes::prettyName(const QString &fileName)
{
    QString base = QFileInfo(fileName).completeBaseName();
    base.replace(QLatin1Char('_'), QLatin1Char(' ')).replace(QLatin1Char('-'), QLatin1Char(' '));
    QStringList words = base.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    for (QString &word : words) {
        word[0] = word.at(0).toUpper();
    }
    return words.join(QLatin1Char(' '));
}

bool ColorSchemes::parse(const QString &path, Scheme *scheme)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }
    QHash<QString, QColor> values;
    QString group;
    static const QRegularExpression header(QStringLiteral(R"(^\s*\[\s*colors\.([a-z_]+)\s*\]\s*$)"));
    static const QRegularExpression otherHeader(QStringLiteral(R"(^\s*\[)"));
    static const QRegularExpression yamlGroup(QStringLiteral(R"(^\s*([a-z_]+)\s*:\s*$)"));
    static const QRegularExpression pair(QStringLiteral(R"(([a-z_]+)\s*[=:]\s*("[^"]*"|'[^']*'|[#0-9a-fA-Fx]+))"));
    static const QRegularExpression inlineTable(QStringLiteral(R"(^\s*([a-z_]+)\s*=\s*\{(.*)\}\s*$)"));
    while (!file.atEnd()) {
        QString line = QString::fromUtf8(file.readLine());
        const int comment = line.indexOf(QLatin1Char('#'));
        if (comment >= 0 && !line.left(comment).contains(QLatin1Char('"')) && !line.left(comment).contains(QLatin1Char('\''))) {
            line = line.left(comment);
        }
        if (line.trimmed().isEmpty()) {
            continue;
        }
        if (const auto match = header.match(line); match.hasMatch()) {
            group = match.captured(1);
            continue;
        }
        if (otherHeader.match(line).hasMatch()) {
            group.clear();
            continue;
        }
        if (const auto match = inlineTable.match(line); match.hasMatch()) {
            auto pairs = pair.globalMatch(match.captured(2));
            while (pairs.hasNext()) {
                const auto item = pairs.next();
                values.insert(match.captured(1) + QLatin1Char('.') + item.captured(1), colour(item.captured(2)));
            }
            continue;
        }
        if (const auto match = yamlGroup.match(line); match.hasMatch()) {
            group = match.captured(1);
            continue;
        }
        if (const auto match = pair.match(line); match.hasMatch() && !group.isEmpty()) {
            values.insert(group + QLatin1Char('.') + match.captured(1), colour(match.captured(2)));
        }
    }
    scheme->background = values.value(QStringLiteral("primary.background"));
    scheme->foreground = values.value(QStringLiteral("primary.foreground"));
    scheme->normal.clear();
    scheme->bright.clear();
    for (const QString &name : colourNames) {
        const QColor normal = values.value(QStringLiteral("normal.") + name);
        if (!normal.isValid()) {
            return false;
        }
        const QColor bright = values.value(QStringLiteral("bright.") + name);
        scheme->normal.append(normal);
        scheme->bright.append(bright.isValid() ? bright : normal);
    }
    return scheme->background.isValid() && scheme->foreground.isValid();
}

void ColorSchemes::write(const Scheme &scheme) const
{
    QDir().mkpath(directory());
    QFile file(directory() + QLatin1Char('/') + scheme.id + QStringLiteral(".colorscheme"));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        return;
    }
    QString text;
    const QString background = colourText(scheme.background);
    text += QStringLiteral("[Background]\nColor=%1\n\n[BackgroundIntense]\nColor=%1\n\n[BackgroundFaint]\nColor=%1\n\n").arg(background);
    for (int i = 0; i < 8; ++i) {
        text += QStringLiteral("[Color%1]\nColor=%2\n\n[Color%1Intense]\nColor=%3\n\n[Color%1Faint]\nColor=%2\n\n")
                    .arg(i)
                    .arg(colourText(scheme.normal.at(i)), colourText(scheme.bright.at(i)));
    }
    const QString foreground = colourText(scheme.foreground);
    text += QStringLiteral("[Foreground]\nColor=%1\n\n[ForegroundIntense]\nColor=%1\n\n[ForegroundFaint]\nColor=%1\n\n").arg(foreground);
    text += QStringLiteral("[General]\nDescription=%1\nOpacity=1\n").arg(scheme.name);
    file.write(text.toUtf8());
}

void ColorSchemes::reload()
{
    m_schemes.clear();
    const auto load = [this](const QString &folder, bool preset) {
        if (folder.isEmpty()) {
            return;
        }
        const QFileInfoList files = QDir(folder).entryInfoList({QStringLiteral("*.toml"), QStringLiteral("*.yml"), QStringLiteral("*.yaml")}, QDir::Files, QDir::Name);
        for (const QFileInfo &info : files) {
            Scheme scheme;
            if (!parse(info.absoluteFilePath(), &scheme)) {
                continue;
            }
            const QString base = info.completeBaseName().toLower().replace(QRegularExpression(QStringLiteral("[^a-z0-9_-]")), QStringLiteral("-"));
            scheme.id = (preset ? QStringLiteral("kt-p-") : QStringLiteral("kt-u-")) + base;
            scheme.name = prettyName(info.fileName());
            scheme.preset = preset;
            write(scheme);
            m_schemes.append(scheme);
        }
    };
    load(presetDirectory(), true);
    load(userDirectory(), false);
}

QVariantList ColorSchemes::list() const
{
    QVariantList result;
    for (const Scheme &scheme : m_schemes) {
        result.append(QVariantMap{{QStringLiteral("id"), scheme.id},
                                  {QStringLiteral("name"), scheme.name},
                                  {QStringLiteral("preset"), scheme.preset},
                                  {QStringLiteral("background"), scheme.background},
                                  {QStringLiteral("foreground"), scheme.foreground}});
    }
    return result;
}

const ColorSchemes::Scheme *ColorSchemes::find(const QString &id) const
{
    for (const Scheme &scheme : m_schemes) {
        if (scheme.id == id) {
            return &scheme;
        }
    }
    return nullptr;
}

QStringList ColorSchemes::import(const QStringList &files, QString *error)
{
    QStringList added;
    QDir().mkpath(userDirectory());
    for (const QString &path : files) {
        Scheme scheme;
        if (!parse(path, &scheme)) {
            if (error) {
                *error = QFileInfo(path).fileName();
            }
            continue;
        }
        const QFileInfo info(path);
        const QString target = userDirectory() + QLatin1Char('/') + info.fileName();
        QFile::remove(target);
        if (QFile::copy(path, target)) {
            added.append(prettyName(info.fileName()));
        }
    }
    reload();
    return added;
}
