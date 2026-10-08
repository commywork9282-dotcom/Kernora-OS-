// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "appearance.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QFile>
#include <QFontDatabase>
#include <QJSEngine>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>

#include <KConfig>
#include <KConfigGroup>
#include <KLocalizedString>
#include <KSharedConfig>

#include <memory>

struct Appearance::Switch {
    QList<QPair<QString, QString>> steps;
    QJSValue callback;
    bool ok = true;
};

Appearance::Appearance(QObject *parent)
    : QObject(parent)
    , m_watcher(KConfigWatcher::create(KSharedConfig::openConfig(QStringLiteral("kdeglobals"))))
{
    connect(m_watcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &group) {
        if (group.name() == QLatin1String("General")) {
            Q_EMIT darkChanged();
        }
    });
}

bool Appearance::dark() const
{
    const KConfigGroup general(KSharedConfig::openConfig(QStringLiteral("kdeglobals")), QStringLiteral("General"));
    return !general.readEntry("ColorScheme", QStringLiteral("KernoraDark")).endsWith(QLatin1String("Light"));
}

QString Appearance::generation() const
{
    auto config = KSharedConfig::openConfig(QStringLiteral("kernorarc"));
    config->reparseConfiguration();
    const QString value = KConfigGroup(config, QStringLiteral("Style")).readEntry("generation", QStringLiteral("md3"));
    return value == QLatin1String("md1") || value == QLatin1String("md2") ? value : QStringLiteral("md3");
}

static QString paletteFile(const QString &colour)
{
    return QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("kernora/palettes/%1.conf").arg(colour));
}

static QString colourSuffix(const QString &colour)
{
    if (colour == QLatin1String("kernora")) {
        return QString();
    }
    QString suffix;
    const QStringList parts = colour.split(QLatin1Char('-'), Qt::SkipEmptyParts);
    for (const QString &part : parts) {
        suffix += part.left(1).toUpper() + part.mid(1);
    }
    return suffix;
}

QString Appearance::colour() const
{
    auto config = KSharedConfig::openConfig(QStringLiteral("kernorarc"));
    config->reparseConfiguration();
    const QString value = KConfigGroup(config, QStringLiteral("Style")).readEntry("colour", QStringLiteral("kernora"));
    return value != QLatin1String("kernora") && paletteFile(value).isEmpty() ? QStringLiteral("kernora") : value;
}

QVariantList Appearance::colours() const
{
    const bool russian = KLocalizedString::languages().value(0).startsWith(QLatin1String("ru"));
    QList<QPair<int, QVariantMap>> found;
    QStringList seen;
    const QStringList roots = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, QStringLiteral("kernora/palettes"),
                                                        QStandardPaths::LocateDirectory);
    for (const QString &root : roots) {
        const auto files = QDir(root).entryInfoList({QStringLiteral("*.conf")}, QDir::Files, QDir::Name);
        for (const QFileInfo &file : files) {
            KConfig palette(file.absoluteFilePath(), KConfig::SimpleConfig);
            const KConfigGroup group(&palette, QStringLiteral("Colour"));
            const QString id = group.readEntry("id", file.completeBaseName());
            if (seen.contains(id)) {
                continue;
            }
            seen.append(id);
            QVariantMap entry{{QStringLiteral("id"), id},
                              {QStringLiteral("name"), group.readEntry(russian ? "name_ru" : "name", id)}};
            for (const QString &mode : {QStringLiteral("dark"), QStringLiteral("light")}) {
                QVariantMap swatch;
                for (const QString &role : {QStringLiteral("primary"), QStringLiteral("secondaryContainer"), QStringLiteral("tertiary")}) {
                    swatch.insert(role, QString(QLatin1Char('#') + group.readEntry(QString(mode + QLatin1Char('_') + role), QStringLiteral("808080"))));
                }
                entry.insert(mode, swatch);
            }
            found.append({group.readEntry("order", 100), entry});
        }
    }
    std::sort(found.begin(), found.end(), [](const auto &a, const auto &b) {
        return a.first < b.first;
    });
    QVariantList result;
    for (const auto &item : std::as_const(found)) {
        result.append(item.second);
    }
    return result;
}

void Appearance::writeTerminalColours(const QString &colour, bool dark) const
{
    const QString themes = colour == QLatin1String("kernora") ? QStringLiteral("kernora/terminal") : QStringLiteral("kernora/terminal/") + colour;
    const QString source = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                                  QStringLiteral("%1/%2.toml").arg(themes, dark ? QStringLiteral("dark") : QStringLiteral("light")));
    if (source.isEmpty()) {
        return;
    }
    QFile in(source);
    if (!in.open(QIODevice::ReadOnly)) {
        return;
    }
    const QString folder = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/alacritty");
    QDir().mkpath(folder);
    QSaveFile out(folder + QStringLiteral("/kernora-colors.toml"));
    if (out.open(QIODevice::WriteOnly)) {
        out.write(in.readAll());
        out.commit();
    }
}

void Appearance::setDark(bool enable, const QJSValue &callback)
{
    applyTheme(colour(), generation(), enable, callback);
}

void Appearance::setGeneration(const QString &generation, const QJSValue &callback)
{
    applyTheme(colour(), generation, dark(), callback);
}

void Appearance::setColour(const QString &colour, const QJSValue &callback)
{
    applyTheme(colour, generation(), dark(), callback);
}

void Appearance::apply(const QString &generation, bool enable, const QJSValue &callback)
{
    applyTheme(colour(), generation, enable, callback);
}

void Appearance::applyTheme(const QString &requestedColour, const QString &requested, bool enable, const QJSValue &callback)
{
    if (m_busy) {
        return;
    }
    m_busy = true;
    Q_EMIT busyChanged();

    const QString colour = requestedColour == QLatin1String("kernora") || !paletteFile(requestedColour).isEmpty() ? requestedColour : QStringLiteral("kernora");
    const QString generation = requested == QLatin1String("md1") || requested == QLatin1String("md2") ? requested : QStringLiteral("md3");
    const bool colourChanges = colour != this->colour();
    const bool generationChanges = generation != this->generation();
    const bool themesChange = generationChanges || colourChanges;
    const QString slug = colour == QLatin1String("kernora") ? QString() : QLatin1Char('-') + colour;
    const QString lower = slug + (generation == QLatin1String("md3") ? QString() : QLatin1Char('-') + generation);
    const QString upper = colourSuffix(colour) + (generation == QLatin1String("md3") ? QString() : generation.toUpper());

    auto kernora = KSharedConfig::openConfig(QStringLiteral("kernorarc"));
    KConfigGroup style(kernora, QStringLiteral("Style"));
    style.writeEntry("generation", generation);
    style.writeEntry("colour", colour);
    kernora->sync();

    const QString kvantumFolder = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/Kvantum");
    QDir().mkpath(kvantumFolder);
    KConfig kvantum(kvantumFolder + QStringLiteral("/kvantum.kvconfig"), KConfig::SimpleConfig);
    KConfigGroup kvantumGeneral(&kvantum, QStringLiteral("General"));
    kvantumGeneral.writeEntry("theme", QString(QStringLiteral("Kernora") + upper));
    kvantum.sync();

    if (themesChange) {
        QDBusMessage gtk = QDBusMessage::createMethodCall(QStringLiteral("org.kde.GtkConfig"), QStringLiteral("/GtkConfig"),
                                                          QStringLiteral("org.kde.GtkConfig"), QStringLiteral("setGtkTheme"));
        gtk.setArguments({QString(QStringLiteral("Kernora") + upper)});
        QDBusConnection::sessionBus().send(gtk);
    }

    auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    KConfigGroup kde(globals, QStringLiteral("KDE"));
    if (themesChange) {
        kde.writeEntry("widgetStyle", enable ? QStringLiteral("kvantum") : QStringLiteral("kvantum-dark"), KConfig::Notify);
        globals->sync();
    }
    kde.writeEntry("widgetStyle", enable ? QStringLiteral("kvantum-dark") : QStringLiteral("kvantum"), KConfig::Notify);
    globals->sync();

    auto kwin = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
    KConfigGroup decoration(kwin, QStringLiteral("org.kde.kdecoration2"));
    decoration.writeEntry("theme", QString(QStringLiteral("__aurorae__svg__kernora") + lower + (enable ? QString() : QStringLiteral("-light"))),
                          KConfig::Notify);
    kwin->sync();

    writeTerminalColours(colour, enable);

    QDBusMessage panels = QDBusMessage::createMethodCall(QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"),
                                                         QStringLiteral("org.kde.PlasmaShell"), QStringLiteral("evaluateScript"));
    panels.setArguments({QStringLiteral("panels().forEach(function (panel) { panel.floating = %1; });")
                             .arg(generation == QLatin1String("md1") ? QStringLiteral("false") : QStringLiteral("true"))});
    QDBusConnection::sessionBus().send(panels);

    auto state = std::make_shared<Switch>();
    state->steps = {
        {QStringLiteral("plasma-apply-desktoptheme"), QStringLiteral("kernora") + lower + (enable ? QString() : QStringLiteral("-light"))},
        {QStringLiteral("plasma-apply-colorscheme"), QStringLiteral("Kernora") + upper + (enable ? QStringLiteral("Dark") : QStringLiteral("Light"))},
    };
    if (colourChanges) {
        state->steps.append({QStringLiteral(KERNORA_LIBEXECDIR "/plasma-changeicons"),
                             colour == QLatin1String("kernora") ? QStringLiteral("Kernora") : QStringLiteral("Kernora-") + colour});
    }
    state->callback = callback;
    if (generationChanges) {
        Q_EMIT generationChanged();
    }
    if (colourChanges) {
        Q_EMIT colourChanged();
    }
    runStep(state, 0);
}

void Appearance::runStep(const std::shared_ptr<Switch> &state, int index)
{
    if (index >= state->steps.size()) {
        QDBusConnection::sessionBus().send(
            QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"), QStringLiteral("org.kde.KWin"), QStringLiteral("reconfigure")));
        QDBusMessage style = QDBusMessage::createSignal(QStringLiteral("/KGlobalSettings"), QStringLiteral("org.kde.KGlobalSettings"), QStringLiteral("notifyChange"));
        style.setArguments({2, 0});
        QDBusConnection::sessionBus().send(style);
        m_busy = false;
        Q_EMIT busyChanged();
        Q_EMIT darkChanged();
        if (state->callback.isCallable()) {
            QJSValue function = state->callback;
            function.call({QJSValue(state->ok)});
        }
        return;
    }
    auto *process = new QProcess(this);
    auto done = [this, process, state, index](bool success) {
        if (!success) {
            state->ok = false;
        }
        process->deleteLater();
        runStep(state, index + 1);
    };
    connect(process, &QProcess::finished, this, [done](int code, QProcess::ExitStatus status) {
        done(code == 0 && status == QProcess::NormalExit);
    });
    connect(process, &QProcess::errorOccurred, this, [done](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            done(false);
        }
    });
    process->start(state->steps.at(index).first, {state->steps.at(index).second});
}

QStringList Appearance::fontFamilies(bool monospace) const
{
    QStringList list;
    for (const QString &family : QFontDatabase::families()) {
        if (family.startsWith(QLatin1Char('.')) || QFontDatabase::isPrivateFamily(family)) {
            continue;
        }
        if (monospace && !QFontDatabase::isFixedPitch(family)) {
            continue;
        }
        if (!QFontDatabase::writingSystems(family).contains(QFontDatabase::Latin) || family.contains(QLatin1String("Emoji"))) {
            continue;
        }
        list.append(family);
    }
    list.removeDuplicates();
    return list;
}
