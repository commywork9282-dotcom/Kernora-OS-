// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "appearance.h"
#include "wallpapercolours.h"

#include <QColor>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFontDatabase>
#include <QHash>
#include <QJSEngine>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>

#include <KConfig>
#include <KConfigGroup>
#include <KLocalizedString>
#include <KSharedConfig>

#include <algorithm>
#include <cmath>
#include <memory>
#include <utility>

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

QString Appearance::wantedColour() const
{
    return m_pending ? m_pendingColour : m_busy ? m_targetColour : colour();
}

QString Appearance::wantedGeneration() const
{
    return m_pending ? m_pendingGeneration : m_busy ? m_targetGeneration : generation();
}

bool Appearance::wantedDark() const
{
    return m_pending ? m_pendingDark : m_busy ? m_targetDark : dark();
}

void Appearance::setDark(bool enable, const QJSValue &callback)
{
    applyTheme(wantedColour(), wantedGeneration(), enable, callback);
}

void Appearance::setGeneration(const QString &generation, const QJSValue &callback)
{
    applyTheme(wantedColour(), generation, wantedDark(), callback);
}

void Appearance::setColour(const QString &colour, const QJSValue &callback)
{
    setColourSource(QStringLiteral("preset"));
    applyTheme(colour, wantedGeneration(), wantedDark(), callback);
}

QString Appearance::colourSource() const
{
    auto config = KSharedConfig::openConfig(QStringLiteral("kernorarc"));
    config->reparseConfiguration();
    const QString fallback = colour() == QLatin1String("kernora") ? QStringLiteral("wallpaper") : QStringLiteral("preset");
    const QString value = KConfigGroup(config, QStringLiteral("Style")).readEntry("colourSource", fallback);
    return value == QLatin1String("preset") ? value : QStringLiteral("wallpaper");
}

void Appearance::setColourSource(const QString &source)
{
    const QString previous = colourSource();
    auto config = KSharedConfig::openConfig(QStringLiteral("kernorarc"));
    KConfigGroup style(config, QStringLiteral("Style"));
    if (style.readEntry("colourSource", QString()) == source) {
        return;
    }
    style.writeEntry("colourSource", source);
    config->sync();
    if (previous != source) {
        Q_EMIT colourChanged();
    }
}

static QString wallpaperFile(const QString &wallpaper)
{
    const QUrl url(wallpaper);
    QString path = url.isLocalFile() ? url.toLocalFile() : wallpaper;
    if (path.endsWith(QLatin1Char('/'))) {
        path.chop(1);
    }
    const QFileInfo info(path);
    if (!info.isDir()) {
        return info.isFile() ? info.absoluteFilePath() : QString();
    }
    const QStringList filters{QStringLiteral("*.jpg"), QStringLiteral("*.jpeg"), QStringLiteral("*.png"), QStringLiteral("*.webp")};
    const auto images = QDir(path + QStringLiteral("/contents/images")).entryInfoList(filters, QDir::Files, QDir::Size);
    return images.isEmpty() ? QString() : images.first().absoluteFilePath();
}

QStringList Appearance::wallpaperColours(const QString &wallpaper) const
{
    static QHash<QString, QStringList> cache;
    const QString file = wallpaperFile(wallpaper);
    if (file.isEmpty()) {
        return {};
    }
    const QString key = file + QLatin1Char('@') + QString::number(QFileInfo(file).lastModified().toSecsSinceEpoch());
    const auto cached = cache.constFind(key);
    if (cached != cache.constEnd()) {
        return *cached;
    }

    struct Preset {
        QString id;
        Kernora::WallpaperColours::HueChroma cam;
    };
    QList<Preset> chromatic;
    QList<Preset> neutral;
    for (const QVariant &entry : colours()) {
        const QString id = entry.toMap().value(QStringLiteral("id")).toString();
        const QString palette = paletteFile(id);
        if (palette.isEmpty()) {
            continue;
        }
        KConfig config(palette, KConfig::SimpleConfig);
        const QColor seed(QLatin1Char('#') + KConfigGroup(&config, QStringLiteral("Colour")).readEntry("seed", QString()));
        if (!seed.isValid()) {
            continue;
        }
        const Preset preset{id, Kernora::WallpaperColours::hueChroma(seed.rgb())};
        (preset.cam.chroma >= 30.0 ? chromatic : neutral).append(preset);
    }

    const auto nearest = [](const QList<Preset> &presets, const Kernora::WallpaperColours::HueChroma &cam, bool useChroma) {
        QString best;
        double bestDistance = 0.0;
        for (const Preset &preset : presets) {
            const double hue = 180.0 - std::abs(std::abs(preset.cam.hue - cam.hue) - 180.0);
            const double distance = useChroma ? hue / 180.0 * std::min(cam.chroma, preset.cam.chroma) + std::abs(preset.cam.chroma - cam.chroma) : hue;
            if (best.isEmpty() || distance < bestDistance) {
                best = preset.id;
                bestDistance = distance;
            }
        }
        return best;
    };

    QStringList vivid;
    QStringList muted;
    for (const QRgb seed : Kernora::WallpaperColours::seedsFromFile(file)) {
        const auto cam = Kernora::WallpaperColours::hueChroma(seed);
        const bool colourful = cam.chroma >= 12.0 && !chromatic.isEmpty();
        const QString id = colourful ? nearest(chromatic, cam, false) : nearest(neutral, cam, true);
        if (!id.isEmpty() && !vivid.contains(id) && !muted.contains(id)) {
            (colourful ? vivid : muted).append(id);
        }
    }
    const QStringList result = vivid + muted;
    cache.insert(key, result);
    return result;
}

void Appearance::setWallpaperColour(const QString &colour, const QJSValue &callback)
{
    setColourSource(QStringLiteral("wallpaper"));
    applyTheme(colour, wantedGeneration(), wantedDark(), callback);
}

void Appearance::followWallpaper(const QString &wallpaper, const QJSValue &callback)
{
    const QStringList found = colourSource() == QLatin1String("wallpaper") ? wallpaperColours(wallpaper) : QStringList();
    if (!found.isEmpty()) {
        setColourSource(QStringLiteral("wallpaper"));
    }
    if (found.isEmpty() || found.first() == wantedColour()) {
        if (callback.isCallable()) {
            QJSValue(callback).call({true});
        }
        return;
    }
    applyTheme(found.first(), wantedGeneration(), wantedDark(), callback);
}

void Appearance::apply(const QString &generation, bool enable, const QJSValue &callback)
{
    applyTheme(colour(), generation, enable, callback);
}

void Appearance::applyTheme(const QString &requestedColour, const QString &requested, bool enable, const QJSValue &callback)
{
    if (m_busy) {
        m_pending = true;
        m_pendingColour = requestedColour;
        m_pendingGeneration = requested;
        m_pendingDark = enable;
        m_pendingCallback = callback;
        return;
    }
    m_busy = true;
    m_targetColour = requestedColour;
    m_targetGeneration = requested;
    m_targetDark = enable;
    Q_EMIT busyChanged();

    const QString colour = requestedColour == QLatin1String("kernora") || !paletteFile(requestedColour).isEmpty() ? requestedColour : QStringLiteral("kernora");
    const QString generation = requested == QLatin1String("md1") || requested == QLatin1String("md2") ? requested : QStringLiteral("md3");
    const bool colourChanges = colour != this->colour();
    const QString previousGeneration = this->generation();
    const bool generationChanges = generation != previousGeneration;
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

    const QString previousFace = previousGeneration == QLatin1String("md3") ? QStringLiteral("Google Sans Flex") : QStringLiteral("Roboto");
    const QString face = generation == QLatin1String("md3") ? QStringLiteral("Google Sans Flex") : QStringLiteral("Roboto");
    if (face != previousFace) {
        const QList<std::pair<QString, QString>> fontKeys = {{QStringLiteral("General"), QStringLiteral("font")},
                                                             {QStringLiteral("General"), QStringLiteral("menuFont")},
                                                             {QStringLiteral("General"), QStringLiteral("toolBarFont")},
                                                             {QStringLiteral("General"), QStringLiteral("smallestReadableFont")},
                                                             {QStringLiteral("WM"), QStringLiteral("activeFont")}};
        for (const auto &[groupName, key] : fontKeys) {
            KConfigGroup group(globals, groupName);
            const QString value = group.readEntry(key, QString());
            if (value.startsWith(previousFace + QLatin1Char(','))) {
                group.writeEntry(key, QString(face + value.mid(previousFace.size())), KConfig::Notify);
            }
        }
        globals->sync();
        QDBusMessage fontsChanged = QDBusMessage::createSignal(QStringLiteral("/KGlobalSettings"), QStringLiteral("org.kde.KGlobalSettings"),
                                                               QStringLiteral("notifyChange"));
        fontsChanged.setArguments({1, 0});
        QDBusConnection::sessionBus().send(fontsChanged);
    }

    auto kwin = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
    KConfigGroup decoration(kwin, QStringLiteral("org.kde.kdecoration2"));
    decoration.writeEntry("theme", QString(QStringLiteral("__aurorae__svg__kernora") + lower + (enable ? QString() : QStringLiteral("-light"))),
                          KConfig::Notify);
    KConfigGroup corners(kwin, QStringLiteral("Round-Corners"));
    corners.writeEntry("OutlineThickness", enable ? 1 : 0);
    corners.writeEntry("InactiveOutlineThickness", enable ? 1 : 0);
    kwin->sync();

    writeTerminalColours(colour, enable);

    QDBusMessage panels = QDBusMessage::createMethodCall(QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"),
                                                         QStringLiteral("org.kde.PlasmaShell"), QStringLiteral("evaluateScript"));
    panels.setArguments({QStringLiteral("panels().forEach(function (panel) { if (panel.widgets('org.kernora.datetime').length > 0) { return; } "
                                        "var square = panel.widgets('org.kernora.launcher').some(function (launcher) { launcher.currentConfigGroup = ['General']; "
                                        "return String(launcher.readConfig('panelShape')) !== 'round'; }); panel.floating = square ? false : %1; });")
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
        QDBusMessage corners = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/Effects"),
                                                              QStringLiteral("org.kde.kwin.Effects"), QStringLiteral("reconfigureEffect"));
        corners.setArguments({QStringLiteral("kwin4_effect_shapecorners")});
        QDBusConnection::sessionBus().send(corners);
        QDBusMessage style = QDBusMessage::createSignal(QStringLiteral("/KGlobalSettings"), QStringLiteral("org.kde.KGlobalSettings"), QStringLiteral("notifyChange"));
        style.setArguments({2, 0});
        QDBusConnection::sessionBus().send(style);
        m_busy = false;
        Q_EMIT darkChanged();
        if (state->callback.isCallable()) {
            QJSValue function = state->callback;
            function.call({QJSValue(state->ok)});
        }
        if (m_pending) {
            m_pending = false;
            const QJSValue pendingCallback = m_pendingCallback;
            m_pendingCallback = QJSValue();
            applyTheme(m_pendingColour, m_pendingGeneration, m_pendingDark, pendingCallback);
            return;
        }
        Q_EMIT busyChanged();
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
