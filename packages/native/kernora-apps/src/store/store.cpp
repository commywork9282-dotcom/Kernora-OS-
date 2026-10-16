// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "store.h"

#include "debianbackend.h"

#include <QCollator>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJSEngine>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>

#include <AppStreamQt/bundle.h>
#include <AppStreamQt/branding.h>
#include <AppStreamQt/developer.h>
#include <AppStreamQt/icon.h>
#include <AppStreamQt/image.h>
#include <AppStreamQt/launchable.h>
#include <AppStreamQt/pool.h>
#include <AppStreamQt/release-list.h>
#include <AppStreamQt/release.h>
#include <AppStreamQt/screenshot.h>

#include <KFormat>
#include <KConfigGroup>
#include <KDesktopFile>
#include <KIO/ApplicationLauncherJob>
#include <KIO/CommandLauncherJob>
#include <KLocalizedString>
#include <KNotification>
#include <KService>
#include <KShell>

using AppStream::Component;

namespace
{
struct Category {
    const char *id;
    const char *icon;
    QStringList names;
};

const QList<Category> &categoryList()
{
    static const QList<Category> list = {
        {"games", "applications-games", {QStringLiteral("Game")}},
        {"internet",
         "applications-internet",
         {QStringLiteral("Network"), QStringLiteral("Chat"), QStringLiteral("InstantMessaging"), QStringLiteral("Email"), QStringLiteral("WebBrowser"),
          QStringLiteral("P2P"), QStringLiteral("FileTransfer"), QStringLiteral("Telephony"), QStringLiteral("VideoConference")}},
        {"multimedia",
         "applications-multimedia",
         {QStringLiteral("AudioVideo"), QStringLiteral("Audio"), QStringLiteral("Video"), QStringLiteral("Music"), QStringLiteral("Player"),
          QStringLiteral("Recorder")}},
        {"graphics",
         "applications-graphics",
         {QStringLiteral("Graphics"), QStringLiteral("Photography"), QStringLiteral("2DGraphics"), QStringLiteral("3DGraphics"),
          QStringLiteral("VectorGraphics"), QStringLiteral("RasterGraphics")}},
        {"office", "applications-office", {QStringLiteral("Office")}},
        {"education", "applications-education", {QStringLiteral("Education"), QStringLiteral("Science")}},
        {"development", "applications-development", {QStringLiteral("Development")}},
        {"utilities", "applications-utilities", {QStringLiteral("Utility"), QStringLiteral("System")}},
    };
    return list;
}

QString normalised(QString id)
{
    if (id.endsWith(QLatin1String(".desktop"))) {
        id.chop(8);
    }
    return id.toLower();
}

QString flatpakName(const QString &ref)
{
    return ref.section(QLatin1Char('/'), 1, 1);
}

QString escaped(const QString &text)
{
    QString result;
    const QStringList paragraphs = text.split(QStringLiteral("\n\n"), Qt::SkipEmptyParts);
    for (const QString &paragraph : paragraphs) {
        result += QStringLiteral("<p>%1</p>").arg(paragraph.simplified().toHtmlEscaped());
    }
    return result;
}

QString ratingsFile()
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/ratings.json");
}
}

Store *Store::instance()
{
    static Store *store = new Store(QCoreApplication::instance());
    return store;
}

Store *Store::create(QQmlEngine *, QJSEngine *)
{
    Store *store = instance();
    QJSEngine::setObjectOwnership(store, QJSEngine::CppOwnership);
    return store;
}

Store::Store(QObject *parent)
    : QObject(parent)
    , m_pool(new AppStream::Pool(this))
    , m_flatpak(new FlatpakWorker)
    , m_debian(new DebianBackend(this))
    , m_network(new QNetworkAccessManager(this))
{
    m_pool->setFlags(AppStream::Pool::Flags(AppStream::Pool::FlagLoadOsCatalog) | AppStream::Pool::FlagLoadFlatpak);
    connect(m_pool, &AppStream::Pool::loadFinished, this, [this]() {
        m_poolLoading = false;
        buildCatalog();
        endLoading();
        if (m_reloadPending) {
            m_reloadPending = false;
            loadPool();
            return;
        }
        const bool hasFlatpak = std::any_of(m_apps.cbegin(), m_apps.cend(), [](const App &app) {
            return app.flatpak;
        });
        const bool hasDebian = std::any_of(m_apps.cbegin(), m_apps.cend(), [](const App &app) {
            return app.debian;
        });
        if (!hasFlatpak && !m_flathubTried) {
            m_flathubTried = true;
            m_waitingFlathub = true;
            beginLoading(i18n("Downloading the Flathub catalogue…"));
            QMetaObject::invokeMethod(m_flatpak, "refreshAppstream", Qt::QueuedConnection, Q_ARG(bool, true));
        } else if (!m_flathubTried) {
            m_flathubTried = true;
            QMetaObject::invokeMethod(m_flatpak, "refreshAppstream", Qt::QueuedConnection, Q_ARG(bool, false));
        }
        if (!hasDebian && !m_debianTried && m_debian->available()) {
            m_debianTried = true;
            beginLoading(i18n("Downloading the Debian catalogue…"));
            m_debian->refreshCache([this](bool) {
                endLoading();
                loadPool();
            });
        }
        if (m_loading == 0 && m_apps.isEmpty()) {
            m_error = i18n("The catalogue could not be downloaded. Check the internet connection and try again.");
            Q_EMIT stateChanged();
        }
    });

    m_flatpak->moveToThread(&m_thread);
    connect(&m_thread, &QThread::finished, m_flatpak, &QObject::deleteLater);
    connect(m_flatpak, &FlatpakWorker::installedListed, this, &Store::applyInstalled);
    connect(m_flatpak, &FlatpakWorker::updatesChecked, this, &Store::applyUpdates);
    connect(m_flatpak, &FlatpakWorker::appstreamRefreshed, this, [this](bool changed, const QString &) {
        const bool waiting = m_waitingFlathub;
        if (waiting) {
            m_waitingFlathub = false;
            endLoading();
        }
        if (changed || waiting) {
            loadPool();
        }
    });
    connect(m_flatpak, &FlatpakWorker::progress, this, &Store::jobProgress);
    connect(m_flatpak, &FlatpakWorker::finished, this, &Store::jobFinished);
    connect(m_debian, &DebianBackend::progress, this, &Store::jobProgress);
    connect(m_debian, &DebianBackend::finished, this, &Store::jobFinished);
    m_thread.start();

    const QString featured = QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("kernora/store/featured.json"));
    QFile file(featured);
    if (file.open(QIODevice::ReadOnly)) {
        const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
        for (auto it = root.constBegin(); it != root.constEnd(); ++it) {
            QStringList ids;
            for (const QJsonValue &value : it.value().toArray()) {
                ids.append(value.toString());
            }
            m_collections.insert(it.key(), ids);
        }
    }

    loadRatings();
    m_debian->loadInstalled();
    QMetaObject::invokeMethod(m_flatpak, "listInstalled", Qt::QueuedConnection);
    loadPool();
    fetchRatings();
}

Store::~Store()
{
    for (auto it = m_jobs.constBegin(); it != m_jobs.constEnd(); ++it) {
        m_flatpak->cancel(it.key());
    }
    m_flatpak->stop();
    m_thread.quit();
    m_thread.wait();
}

bool Store::live() const
{
    return QFileInfo::exists(QStringLiteral("/run/live/medium"));
}

void Store::beginLoading(const QString &text)
{
    m_loading += 1;
    m_loadingText = text;
    m_error.clear();
    Q_EMIT stateChanged();
}

void Store::endLoading()
{
    m_loading = qMax(0, m_loading - 1);
    if (m_loading == 0) {
        m_loadingText.clear();
    }
    Q_EMIT stateChanged();
}

void Store::loadPool()
{
    if (m_poolLoading) {
        m_reloadPending = true;
        return;
    }
    m_poolLoading = true;
    beginLoading(m_ready ? m_loadingText.isEmpty() ? i18n("Updating the catalogue…") : m_loadingText : i18n("Loading the catalogue…"));
    m_pool->loadAsync();
}

QString Store::iconFor(const Component &component) const
{
    QString stock;
    QString remote;
    QString local;
    uint best = 0;
    const QList<AppStream::Icon> icons = component.icons();
    for (const AppStream::Icon &icon : icons) {
        switch (icon.kind()) {
        case AppStream::Icon::KindStock:
            stock = icon.name();
            break;
        case AppStream::Icon::KindCached:
        case AppStream::Icon::KindLocal: {
            const QUrl url = icon.url();
            const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
            if (icon.width() >= best && QFileInfo::exists(path)) {
                best = icon.width();
                local = QUrl::fromLocalFile(path).toString();
            }
            break;
        }
        case AppStream::Icon::KindRemote:
            if (remote.isEmpty() || icon.width() >= 128) {
                remote = icon.url().toString();
            }
            break;
        default:
            break;
        }
    }
    if (!local.isEmpty()) {
        return local;
    }
    if (!stock.isEmpty()) {
        return stock;
    }
    return remote;
}

std::optional<Component> Store::component(const App &app, bool flatpak) const
{
    const QString id = flatpak ? app.flatpakComponent : app.debianComponent;
    if (id.isEmpty() || m_poolLoading) {
        return std::nullopt;
    }
    const QList<Component> found = m_pool->componentsById(id).toList();
    for (const Component &candidate : found) {
        const AppStream::Bundle bundle = candidate.bundle(AppStream::Bundle::KindFlatpak);
        if (bundle.isEmpty() != flatpak && (!flatpak || bundle.id() == app.flatpakRef)) {
            return candidate;
        }
    }
    return std::nullopt;
}

void Store::buildCatalog()
{
    QHash<QString, App> apps;
    QHash<QString, QString> index;
    for (auto it = m_apps.constBegin(); it != m_apps.constEnd(); ++it) {
        if (!it.value().localPath.isEmpty()) {
            apps.insert(it.key(), it.value());
        }
    }

    QHash<QString, Component> flatpakComponents;
    QHash<QString, Component> debianComponents;
    const QList<Component> components = m_pool->componentsByKind(Component::KindDesktopApp).toList();
    for (const Component &component : components) {
        const QString id = normalised(component.id());
        if (id.isEmpty() || id.startsWith(QLatin1String("org.kernora.")) || component.name().isEmpty()) {
            continue;
        }
        const AppStream::Bundle bundle = component.bundle(AppStream::Bundle::KindFlatpak);
        const bool flatpak = !bundle.isEmpty();
        if ((flatpak && !bundle.id().startsWith(QLatin1String("app/"))) || (!flatpak && component.packageNames().isEmpty())) {
            continue;
        }
        App &app = apps[id];
        app.id = id;
        if (flatpak ? !app.flatpak : !app.debian) {
            (flatpak ? flatpakComponents : debianComponents).insert(id, component);
        }
        if (flatpak) {
            if (app.flatpak) {
                continue;
            }
            app.flatpak = true;
            app.flatpakComponent = component.id();
            app.flatpakRef = bundle.id();
            app.flatpakName = flatpakName(bundle.id());
            const QString origin = component.origin();
            app.flatpakRemote = origin.isEmpty() || origin.contains(QLatin1Char(':')) || origin == QLatin1String("flatpak") ? QStringLiteral("flathub") : origin;
            index.insert(app.flatpakName, id);
        } else if (!app.debian) {
            app.debian = true;
            app.debianComponent = component.id();
            app.packages = component.packageNames();
        }
    }

    for (auto it = apps.begin(); it != apps.end(); ++it) {
        App &app = it.value();
        if (!app.localPath.isEmpty() || (!app.flatpak && !app.debian)) {
            continue;
        }
        const Component primary = app.flatpak ? flatpakComponents.value(app.id) : debianComponents.value(app.id);
        app.name = primary.name();
        app.summary = primary.summary();
        const AppStream::Developer developer = primary.developer();
        app.developer = developer.cPtr() ? developer.name() : QString();
        if (app.developer.isEmpty()) {
            app.developer = primary.projectGroup();
        }
        app.icon = iconFor(primary);
        if (app.icon.isEmpty() && app.debian && app.flatpak) {
            app.icon = iconFor(debianComponents.value(app.id));
        }
        app.categories = primary.categories();
        if (app.flatpak) {
            app.verified = primary.customValue(QStringLiteral("flathub::verification::verified")) == QLatin1String("true");
        }
        const QStringList launchables = primary.launchable(AppStream::Launchable::KindDesktopId).entries();
        app.desktopId = launchables.value(0, app.id + QStringLiteral(".desktop"));
        AppStream::Branding branding = primary.branding();
        if (branding.cPtr()) {
            app.accentLight = branding.color(AppStream::Branding::ColorKind::Primary, AppStream::Branding::ColorSchemeKind::Light);
            app.accentDark = branding.color(AppStream::Branding::ColorKind::Primary, AppStream::Branding::ColorSchemeKind::Dark);
        }
    }

    m_apps = apps;
    m_flatpakIndex = index;
    attachInstalled();
    if (!m_apps.isEmpty()) {
        m_ready = true;
        m_error.clear();
    }
    sortCatalog();
    Q_EMIT stateChanged();
    Q_EMIT catalogChanged();
}

void Store::sortCatalog()
{
    QStringList order;
    order.reserve(m_apps.size());
    for (auto it = m_apps.constBegin(); it != m_apps.constEnd(); ++it) {
        if (it.value().localPath.isEmpty()) {
            order.append(it.key());
        }
    }
    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(order.begin(), order.end(), [this, &collator](const QString &left, const QString &right) {
        const App &a = m_apps[left];
        const App &b = m_apps[right];
        const int ratingA = m_ratings.value(left).total;
        const int ratingB = m_ratings.value(right).total;
        if (ratingA != ratingB) {
            return ratingA > ratingB;
        }
        if (a.verified != b.verified) {
            return a.verified;
        }
        if (a.flatpak != b.flatpak) {
            return a.flatpak;
        }
        return collator.compare(a.name, b.name) < 0;
    });
    m_order = order;
}

void Store::loadRatings()
{
    QFile file(ratingsFile());
    if (!file.open(QIODevice::ReadOnly)) {
        return;
    }
    const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    m_ratings.clear();
    for (auto it = root.constBegin(); it != root.constEnd(); ++it) {
        const QJsonObject entry = it.value().toObject();
        Rating rating;
        int weighted = 0;
        int counted = 0;
        for (int star = 1; star <= 5; ++star) {
            const int votes = entry.value(QStringLiteral("star%1").arg(star)).toInt();
            weighted += votes * star;
            counted += votes;
            rating.votes.append(votes);
        }
        rating.total = entry.value(QStringLiteral("total")).toInt();
        rating.stars = counted > 0 ? double(weighted) / counted : 0;
        const QString id = normalised(it.key());
        if (rating.total > m_ratings.value(id).total) {
            m_ratings.insert(id, rating);
        }
    }
}

void Store::fetchRatings()
{
    const QFileInfo cached(ratingsFile());
    if (cached.exists() && cached.lastModified().secsTo(QDateTime::currentDateTime()) < 3 * 24 * 3600) {
        return;
    }
    QNetworkRequest request(QUrl(QStringLiteral("https://odrs.gnome.org/1.0/reviews/api/ratings")));
    request.setTransferTimeout(30000);
    QNetworkReply *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            return;
        }
        const QByteArray data = reply->readAll();
        if (!QJsonDocument::fromJson(data).isObject()) {
            return;
        }
        QDir().mkpath(QFileInfo(ratingsFile()).absolutePath());
        QSaveFile file(ratingsFile());
        if (file.open(QIODevice::WriteOnly)) {
            file.write(data);
            file.commit();
        }
        loadRatings();
        sortCatalog();
        Q_EMIT catalogChanged();
    });
}

void Store::applyInstalled(const QList<FlatpakApp> &installed)
{
    m_installed = installed;
    attachInstalled();
    sortCatalog();
    if (!m_apps.isEmpty()) {
        m_ready = true;
        Q_EMIT stateChanged();
    }
    Q_EMIT catalogChanged();
    for (auto it = m_apps.constBegin(); it != m_apps.constEnd(); ++it) {
        Q_EMIT appChanged(it.key());
    }
    m_checkingUpdates = true;
    Q_EMIT updatesChanged();
    QMetaObject::invokeMethod(m_flatpak, "checkUpdates", Qt::QueuedConnection);
}

void Store::attachInstalled()
{
    for (auto it = m_apps.begin(); it != m_apps.end();) {
        App &app = it.value();
        app.installedFlatpak.reset();
        app.update = false;
        if (!app.flatpak && !app.debian && app.localPath.isEmpty()) {
            it = m_apps.erase(it);
        } else {
            ++it;
        }
    }
    for (const FlatpakApp &flatpak : std::as_const(m_installed)) {
        QString id = m_flatpakIndex.value(flatpak.name);
        if (id.isEmpty()) {
            id = flatpak.name;
            if (!m_apps.contains(id)) {
                App app;
                app.id = id;
                app.name = flatpak.title.isEmpty() ? flatpak.name : flatpak.title;
                app.summary = flatpak.summary;
                app.icon = flatpak.name;
                app.desktopId = flatpak.name + QStringLiteral(".desktop");
                app.flatpakName = flatpak.name;
                m_apps.insert(id, app);
            }
            m_flatpakIndex.insert(flatpak.name, id);
        }
        App &app = m_apps[id];
        app.installedFlatpak = flatpak;
        app.update = m_updateNames.contains(flatpak.name);
        for (App &local : m_apps) {
            if (local.localKind == QLatin1String("flatpakref") && local.flatpakName == flatpak.name) {
                local.installedFlatpak = flatpak;
                local.update = app.update;
            }
        }
    }
}

void Store::applyUpdates(const QStringList &names, const QStringList &refs, const QString &error)
{
    m_checkingUpdates = false;
    m_updateError = error;
    if (!error.isEmpty()) {
        Q_EMIT updatesChanged();
        return;
    }
    m_updateNames = names;
    for (auto it = m_apps.begin(); it != m_apps.end(); ++it) {
        const bool update = it.value().installedFlatpak && names.contains(it.value().installedFlatpak->name);
        if (update != it.value().update) {
            it.value().update = update;
            Q_EMIT appChanged(it.key());
        }
    }
    m_pendingRefs = refs;
    Q_EMIT updatesChanged();
}

bool Store::debianInstalled(const App &app) const
{
    if (app.localKind == QLatin1String("deb")) {
        const QString package = app.localInfo.value(QStringLiteral("package")).toString();
        return !package.isEmpty() && m_debian->installedVersion(package) == app.localInfo.value(QStringLiteral("version")).toString();
    }
    if (!app.debian) {
        return false;
    }
    return std::any_of(app.packages.cbegin(), app.packages.cend(), [this](const QString &package) {
        return m_debian->isInstalled(package);
    });
}

bool Store::isInstalled(const App &app) const
{
    return app.installedFlatpak.has_value() || debianInstalled(app);
}

QString Store::installedSource(const App &app) const
{
    if (app.installedFlatpak) {
        return QStringLiteral("flatpak");
    }
    if (debianInstalled(app)) {
        return QStringLiteral("debian");
    }
    return QString();
}

int Store::updateCount() const
{
    int count = 0;
    for (const App &app : m_apps) {
        count += app.update ? 1 : 0;
    }
    return count;
}

int Store::installedCount() const
{
    int count = 0;
    for (const App &app : m_apps) {
        count += app.localPath.isEmpty() && isInstalled(app) ? 1 : 0;
    }
    return count;
}

QVariantList Store::categories() const
{
    QVariantList list;
    for (const Category &category : categoryList()) {
        list.append(QVariantMap{{QStringLiteral("id"), QString::fromLatin1(category.id)},
                                {QStringLiteral("name"), categoryName(QString::fromLatin1(category.id))},
                                {QStringLiteral("icon"), QString::fromLatin1(category.icon)}});
    }
    return list;
}

QString Store::categoryName(const QString &category) const
{
    if (category == QLatin1String("games")) {
        return i18n("Games");
    }
    if (category == QLatin1String("internet")) {
        return i18n("Internet & chat");
    }
    if (category == QLatin1String("multimedia")) {
        return i18n("Music & video");
    }
    if (category == QLatin1String("graphics")) {
        return i18n("Graphics & photos");
    }
    if (category == QLatin1String("office")) {
        return i18n("Office");
    }
    if (category == QLatin1String("education")) {
        return i18n("Learning & science");
    }
    if (category == QLatin1String("development")) {
        return i18n("Development");
    }
    if (category == QLatin1String("utilities")) {
        return i18n("Tools");
    }
    return QString();
}

QString Store::idFor(const QString &raw) const
{
    const QString id = normalised(raw);
    if (m_apps.contains(id)) {
        return id;
    }
    return m_flatpakIndex.value(id);
}

QStringList Store::collection(const QString &name) const
{
    QStringList result;
    for (const QString &raw : m_collections.value(name)) {
        const QString id = idFor(raw);
        if (!id.isEmpty() && !result.contains(id)) {
            result.append(id);
        }
    }
    return result;
}

QStringList Store::query(const QString &text, const QString &category, Filter filter) const
{
    QStringList result;
    const QString term = text.trimmed();
    if (filter == Installed || filter == Updates) {
        for (auto it = m_apps.constBegin(); it != m_apps.constEnd(); ++it) {
            const App &app = it.value();
            if (!app.localPath.isEmpty()) {
                continue;
            }
            if ((filter == Installed && isInstalled(app)) || (filter == Updates && app.update)) {
                result.append(it.key());
            }
        }
        QCollator collator;
        collator.setCaseSensitivity(Qt::CaseInsensitive);
        std::sort(result.begin(), result.end(), [this, &collator](const QString &left, const QString &right) {
            return collator.compare(m_apps[left].name, m_apps[right].name) < 0;
        });
        return result;
    }

    if (!term.isEmpty()) {
        QStringList exact;
        const QList<Component> found = m_pool->search(term).toList();
        for (const Component &component : found) {
            const QString id = normalised(component.id());
            if (!m_apps.contains(id) || result.contains(id) || exact.contains(id)) {
                continue;
            }
            if (m_apps[id].name.compare(term, Qt::CaseInsensitive) == 0) {
                exact.append(id);
            } else {
                result.append(id);
            }
        }
        for (auto it = m_apps.constBegin(); it != m_apps.constEnd(); ++it) {
            if (it.value().installedFlatpak && !it.value().flatpak && it.value().name.contains(term, Qt::CaseInsensitive) && !result.contains(it.key())) {
                result.append(it.key());
            }
        }
        return exact + result;
    }

    if (!category.isEmpty()) {
        QStringList names;
        for (const Category &entry : categoryList()) {
            if (category == QLatin1String(entry.id)) {
                names = entry.names;
            }
        }
        for (const QString &id : m_order) {
            const QStringList &categories = m_apps[id].categories;
            if (std::any_of(names.cbegin(), names.cend(), [&categories](const QString &name) {
                    return categories.contains(name);
                })) {
                result.append(id);
            }
        }
        return result;
    }
    return m_order;
}

QVariant Store::value(const QString &id, int role) const
{
    const auto found = m_apps.constFind(id);
    if (found == m_apps.constEnd()) {
        return QVariant();
    }
    const App &app = found.value();
    switch (role) {
    case IdRole:
        return id;
    case NameRole:
        return app.name;
    case SummaryRole:
        return app.summary;
    case IconRole:
        return app.icon;
    case DeveloperRole:
        return app.developer;
    case InstalledRole:
        return isInstalled(app);
    case BusyRole:
        return m_jobs.contains(id);
    case ProgressRole:
        return m_jobs.value(id).progress;
    case StatusRole:
        return m_jobs.value(id).status;
    case UpdateRole:
        return app.update;
    case VerifiedRole:
        return app.verified;
    case SourceRole: {
        const QString installed = installedSource(app);
        if (!installed.isEmpty()) {
            return installed;
        }
        return app.flatpak ? QStringLiteral("flatpak") : QStringLiteral("debian");
    }
    case RatingRole:
        return m_ratings.value(id).stars;
    case AccentRole:
        return app.accentLight;
    }
    return QVariant();
}

QVariantMap Store::state(const QString &id) const
{
    const auto found = m_apps.constFind(id);
    if (found == m_apps.constEnd()) {
        if (m_jobs.contains(id)) {
            const Job job = m_jobs.value(id);
            return {{QStringLiteral("busy"), true}, {QStringLiteral("progress"), job.progress}, {QStringLiteral("status"), job.status}};
        }
        return {};
    }
    const App &app = found.value();
    const Job job = m_jobs.value(id);
    QString version;
    if (app.installedFlatpak) {
        version = app.installedFlatpak->version;
    } else if (debianInstalled(app)) {
        for (const QString &package : app.packages) {
            if (m_debian->isInstalled(package)) {
                version = m_debian->installedVersion(package);
                break;
            }
        }
        if (app.localKind == QLatin1String("deb")) {
            version = app.localInfo.value(QStringLiteral("version")).toString();
        }
    }
    return {
        {QStringLiteral("installed"), isInstalled(app)},
        {QStringLiteral("installedSource"), installedSource(app)},
        {QStringLiteral("installedVersion"), version},
        {QStringLiteral("installedSize"), app.installedFlatpak ? KFormat().formatByteSize(double(app.installedFlatpak->size), 1, KFormat::JEDECBinaryDialect) : QString()},
        {QStringLiteral("busy"), m_jobs.contains(id)},
        {QStringLiteral("action"), job.action},
        {QStringLiteral("progress"), job.progress},
        {QStringLiteral("status"), job.status},
        {QStringLiteral("update"), app.update},
    };
}

QVariantMap Store::details(const QString &id) const
{
    const auto found = m_apps.constFind(id);
    if (found == m_apps.constEnd()) {
        return {};
    }
    const App &app = found.value();
    QVariantMap result{
        {QStringLiteral("id"), id},
        {QStringLiteral("name"), app.name},
        {QStringLiteral("summary"), app.summary},
        {QStringLiteral("developer"), app.developer},
        {QStringLiteral("icon"), app.icon},
        {QStringLiteral("verified"), app.verified},
        {QStringLiteral("accentLight"), app.accentLight},
        {QStringLiteral("accentDark"), app.accentDark},
        {QStringLiteral("rating"), m_ratings.value(id).stars},
        {QStringLiteral("ratingCount"), m_ratings.value(id).total},
        {QStringLiteral("ratingVotes"), m_ratings.value(id).votes},
        {QStringLiteral("local"), !app.localPath.isEmpty()},
    };

    QVariantList sources;
    if (app.flatpak || app.localKind == QLatin1String("flatpakref") || (app.installedFlatpak && !app.debian)) {
        sources.append(QVariantMap{{QStringLiteral("key"), QStringLiteral("flatpak")},
                                   {QStringLiteral("title"), app.localKind == QLatin1String("flatpakref") ? i18n("Flatpak file") : QStringLiteral("Flathub")}});
    }
    if (app.debian || app.localKind == QLatin1String("deb")) {
        sources.append(QVariantMap{{QStringLiteral("key"), QStringLiteral("debian")},
                                   {QStringLiteral("title"), app.localKind == QLatin1String("deb") ? i18n("Package file") : QStringLiteral("Debian")}});
    }
    result.insert(QStringLiteral("sources"), sources);

    if (!app.localPath.isEmpty()) {
        result.insert(QStringLiteral("description"), app.localInfo.value(QStringLiteral("description")));
        result.insert(QStringLiteral("version"), app.localInfo.value(QStringLiteral("version")));
        result.insert(QStringLiteral("license"), app.localInfo.value(QStringLiteral("license")));
        result.insert(QStringLiteral("homepage"), app.localInfo.value(QStringLiteral("homepage")));
        result.insert(QStringLiteral("file"), QFileInfo(app.localPath).fileName());
        result.insert(QStringLiteral("screenshots"), QVariantList());
        return result;
    }

    QVariantMap perSource;
    std::optional<Component> primaryComponent;
    for (const bool flatpak : {true, false}) {
        if (flatpak ? !app.flatpak : !app.debian) {
            continue;
        }
        const std::optional<Component> found = component(app, flatpak);
        if (!found) {
            continue;
        }
        if (!primaryComponent) {
            primaryComponent = found;
        }
        QVariantMap info;
        const AppStream::ReleaseList releases = found->releasesPlain();
        if (releases.cPtr() && releases.size() > 0) {
            const std::optional<AppStream::Release> latest = releases.indexSafe(0);
            if (latest) {
                info.insert(QStringLiteral("version"), latest->version());
                info.insert(QStringLiteral("released"), latest->timestamp());
            }
        }
        if (!flatpak) {
            info.insert(QStringLiteral("package"), app.packages.value(0));
        }
        perSource.insert(flatpak ? QStringLiteral("flatpak") : QStringLiteral("debian"), info);
    }
    result.insert(QStringLiteral("perSource"), perSource);

    if (!primaryComponent) {
        result.insert(QStringLiteral("description"), escaped(app.summary));
        result.insert(QStringLiteral("screenshots"), QVariantList());
        return result;
    }
    const Component &primary = *primaryComponent;
    result.insert(QStringLiteral("description"), primary.description());
    QString license = primary.projectLicense();
    if (license.startsWith(QLatin1String("LicenseRef-proprietary"))) {
        license = i18n("Proprietary");
    }
    result.insert(QStringLiteral("license"), license);
    result.insert(QStringLiteral("homepage"), primary.url(Component::UrlKindHomepage).toString());
    result.insert(QStringLiteral("free"), primary.isFloss());

    QVariantList categoryNames;
    for (const Category &category : categoryList()) {
        if (std::any_of(category.names.cbegin(), category.names.cend(), [&app](const QString &name) {
                return app.categories.contains(name);
            })) {
            categoryNames.append(QVariantMap{{QStringLiteral("id"), QString::fromLatin1(category.id)},
                                             {QStringLiteral("name"), categoryName(QString::fromLatin1(category.id))}});
        }
    }
    result.insert(QStringLiteral("categories"), categoryNames);

    QVariantList screenshots;
    const QList<AppStream::Screenshot> shots = primary.screenshotsAll();
    for (const AppStream::Screenshot &shot : shots) {
        if (shot.mediaKind() != AppStream::Screenshot::MediaKindImage) {
            continue;
        }
        QUrl full;
        uint fullWidth = 0;
        QUrl thumb;
        uint thumbWidth = 0;
        const QList<AppStream::Image> images = shot.images();
        for (const AppStream::Image &image : images) {
            if (image.kind() == AppStream::Image::KindSource || image.width() > fullWidth) {
                if (image.kind() == AppStream::Image::KindSource || fullWidth == 0 || image.width() > fullWidth) {
                    full = image.url();
                    fullWidth = image.kind() == AppStream::Image::KindSource ? 100000 : image.width();
                }
            }
            if (image.width() >= 600 && (thumbWidth == 0 || image.width() < thumbWidth)) {
                thumb = image.url();
                thumbWidth = image.width();
            }
        }
        if (full.isEmpty()) {
            continue;
        }
        screenshots.append(QVariantMap{{QStringLiteral("full"), full},
                                       {QStringLiteral("thumb"), thumb.isEmpty() ? full : thumb},
                                       {QStringLiteral("caption"), shot.caption()}});
    }
    result.insert(QStringLiteral("screenshots"), screenshots);
    return result;
}

void Store::startJob(const QString &id, const QString &action, const QString &source)
{
    Job job;
    job.action = action;
    job.source = source;
    job.status = i18n("Waiting…");
    m_jobs.insert(id, job);
    Q_EMIT appChanged(id);
    Q_EMIT jobsChanged();
}

void Store::install(const QString &id, const QString &source)
{
    if (m_jobs.contains(QStringLiteral("*updates")) || m_jobs.contains(id) || !m_apps.contains(id)) {
        return;
    }
    const App &app = m_apps[id];
    if (app.localKind == QLatin1String("deb")) {
        if (app.localInfo.value(QStringLiteral("package")).toString().isEmpty()) {
            Q_EMIT message(i18n("This package could not be read. Choose a valid Debian package and try again."));
            return;
        }
        startJob(id, QStringLiteral("install"), QStringLiteral("debian"));
        m_debian->installFile(id, app.localPath);
        return;
    }
    if (app.localKind == QLatin1String("flatpakref")) {
        startJob(id, QStringLiteral("install"), QStringLiteral("flatpak"));
        QMetaObject::invokeMethod(m_flatpak, "run", Qt::QueuedConnection, Q_ARG(QString, id), Q_ARG(int, FlatpakWorker::InstallRef), Q_ARG(QString, QString()),
                                  Q_ARG(QString, QStringLiteral("system")), Q_ARG(QByteArray, app.localData));
        return;
    }
    const bool useFlatpak = app.flatpak && (source == QLatin1String("flatpak") || !app.debian);
    if (useFlatpak) {
        startJob(id, QStringLiteral("install"), QStringLiteral("flatpak"));
        QMetaObject::invokeMethod(m_flatpak, "run", Qt::QueuedConnection, Q_ARG(QString, id), Q_ARG(int, FlatpakWorker::Install), Q_ARG(QString, app.flatpakRef),
                                  Q_ARG(QString, QStringLiteral("system")), Q_ARG(QByteArray, app.flatpakRemote.toUtf8()));
    } else if (app.debian) {
        startJob(id, QStringLiteral("install"), QStringLiteral("debian"));
        m_debian->install(id, app.packages.mid(0, 1));
    }
}

void Store::remove(const QString &id)
{
    if (m_jobs.contains(QStringLiteral("*updates")) || m_jobs.contains(id) || !m_apps.contains(id)) {
        return;
    }
    const App &app = m_apps[id];
    if (app.installedFlatpak) {
        startJob(id, QStringLiteral("remove"), QStringLiteral("flatpak"));
        QMetaObject::invokeMethod(m_flatpak, "run", Qt::QueuedConnection, Q_ARG(QString, id), Q_ARG(int, FlatpakWorker::Remove),
                                  Q_ARG(QString, app.installedFlatpak->ref), Q_ARG(QString, app.installedFlatpak->installation), Q_ARG(QByteArray, QByteArray()));
        return;
    }
    QStringList packages;
    if (app.localKind == QLatin1String("deb")) {
        packages.append(app.localInfo.value(QStringLiteral("package")).toString());
    }
    for (const QString &package : app.packages) {
        if (m_debian->isInstalled(package)) {
            packages.append(package);
        }
    }
    if (!packages.isEmpty()) {
        startJob(id, QStringLiteral("remove"), QStringLiteral("debian"));
        m_debian->remove(id, packages);
    }
}

void Store::update(const QString &id)
{
    if (m_jobs.contains(QStringLiteral("*updates")) || m_jobs.contains(id) || !m_apps.contains(id) || !m_apps[id].installedFlatpak) {
        return;
    }
    const App &app = m_apps[id];
    startJob(id, QStringLiteral("update"), QStringLiteral("flatpak"));
    QMetaObject::invokeMethod(m_flatpak, "run", Qt::QueuedConnection, Q_ARG(QString, id), Q_ARG(int, FlatpakWorker::Update),
                              Q_ARG(QString, app.installedFlatpak->ref), Q_ARG(QString, app.installedFlatpak->installation), Q_ARG(QByteArray, QByteArray()));
}

void Store::updateAll()
{
    const QString id = QStringLiteral("*updates");
    if (!m_jobs.isEmpty() || m_pendingRefs.isEmpty() || m_checkingUpdates || !m_updateError.isEmpty()) {
        return;
    }
    startJob(id, QStringLiteral("update"), QStringLiteral("flatpak"));
    QMetaObject::invokeMethod(m_flatpak, "run", Qt::QueuedConnection, Q_ARG(QString, id), Q_ARG(int, FlatpakWorker::Update), Q_ARG(QString, QString()),
                              Q_ARG(QString, QString()), Q_ARG(QByteArray, QByteArray()));
}

void Store::cancel(const QString &id)
{
    if (!m_jobs.contains(id)) {
        return;
    }
    if (m_jobs[id].source == QLatin1String("debian")) {
        m_debian->cancel(id);
    } else {
        m_flatpak->cancel(id);
    }
    m_jobs[id].status = i18n("Cancelling…");
    Q_EMIT appChanged(id);
}

void Store::jobProgress(const QString &id, int percent, const QString &status)
{
    if (!m_jobs.contains(id)) {
        return;
    }
    Job &job = m_jobs[id];
    job.progress = percent;
    if (!status.isEmpty()) {
        job.status = status;
    }
    Q_EMIT appChanged(id);
}

void Store::notify(const QString &title, const QString &text, const QString &icon)
{
    if (QGuiApplication::applicationState() == Qt::ApplicationActive && QGuiApplication::focusWindow()) {
        return;
    }
    auto *notification = new KNotification(QStringLiteral("done"));
    notification->setComponentName(QStringLiteral("kernora-store"));
    notification->setTitle(title);
    notification->setText(text);
    notification->setIconName(icon.startsWith(QLatin1String("file:")) || icon.isEmpty() ? QStringLiteral("org.kernora.store") : icon);
    notification->sendEvent();
}

void Store::jobFinished(const QString &id, bool success, const QString &error)
{
    if (!m_jobs.contains(id)) {
        return;
    }
    const Job job = m_jobs.take(id);
    const QString name = m_apps.contains(id) ? m_apps[id].name : QString();
    const QString icon = m_apps.contains(id) ? m_apps[id].icon : QString();
    if (job.source == QLatin1String("flatpak") || id == QLatin1String("*updates")) {
        QMetaObject::invokeMethod(m_flatpak, "listInstalled", Qt::QueuedConnection);
    }
    if (success) {
        if (job.action == QLatin1String("install")) {
            Q_EMIT message(i18n("%1 is installed", name));
            notify(i18n("%1 is installed", name), i18n("Open it from the app menu."), icon);
        } else if (job.action == QLatin1String("remove")) {
            Q_EMIT message(i18n("%1 is removed", name));
        } else if (id == QLatin1String("*updates")) {
            Q_EMIT message(i18n("All apps are up to date"));
            notify(i18n("All apps are up to date"), QString(), QString());
        } else {
            Q_EMIT message(i18n("%1 is updated", name));
        }
    } else if (!error.isEmpty()) {
        QString text;
        if (job.action == QLatin1String("remove")) {
            text = i18n("%1 could not be removed: %2", name, error);
        } else if (job.action == QLatin1String("update")) {
            text = name.isEmpty() ? i18n("The updates could not be installed: %1", error) : i18n("%1 could not be updated: %2", name, error);
        } else {
            text = i18n("%1 could not be installed: %2", name, error);
        }
        Q_EMIT message(text);
        notify(text, QString(), icon);
    }
    Q_EMIT appChanged(id);
    Q_EMIT jobsChanged();
    Q_EMIT catalogChanged();
}

bool Store::launch(const QString &id)
{
    if (!m_apps.contains(id) || !isInstalled(m_apps[id])) {
        return false;
    }
    const App &app = m_apps[id];
    if (app.installedFlatpak) {
        const FlatpakApp &installed = *app.installedFlatpak;
        const QString scope = installed.installation == QLatin1String("user") ? QStringLiteral("--user") : QStringLiteral("--system");
        const QString exportRoot = installed.installation == QLatin1String("user")
            ? QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/flatpak")
            : QStringLiteral("/var/lib/flatpak");
        const QString desktopPath = exportRoot + QStringLiteral("/exports/share/applications/") + installed.name + QStringLiteral(".desktop");
        if (QFileInfo::exists(desktopPath)) {
            KDesktopFile desktop(desktopPath);
            KConfigGroup group = desktop.desktopGroup();
            QStringList arguments = KShell::splitArgs(group.readEntry("Exec", QString()));
            const auto run = std::find_if(arguments.cbegin(), arguments.cend(), [](const QString &argument) {
                return QFileInfo(argument).fileName() == QLatin1String("flatpak");
            });
            const int executable = int(std::distance(arguments.cbegin(), run));
            int appIndex = arguments.indexOf(installed.name, executable + 2);
            if (executable + 1 >= arguments.size() || arguments.at(executable + 1) != QLatin1String("run") || appIndex < 0) {
                arguments = {QStringLiteral("flatpak"), QStringLiteral("run"), scope, installed.ref};
            } else {
                arguments[executable] = QStringLiteral("flatpak");
                for (int index = executable + 2; index < appIndex;) {
                    const QString argument = arguments.at(index);
                    if (argument == QLatin1String("--user") || argument == QLatin1String("--system")
                        || argument.startsWith(QLatin1String("--branch=")) || argument.startsWith(QLatin1String("--arch="))) {
                        arguments.removeAt(index);
                        --appIndex;
                    } else if ((argument == QLatin1String("--branch") || argument == QLatin1String("--arch")) && index + 1 < appIndex) {
                        arguments.removeAt(index);
                        arguments.removeAt(index);
                        appIndex -= 2;
                    } else {
                        ++index;
                    }
                }
                arguments[appIndex] = installed.ref;
                arguments.insert(executable + 2, scope);
            }
            const QString command = KShell::joinArgs(arguments);
            group.writeEntry("Exec", command);
            group.writeEntry("DBusActivatable", false);
            desktop.markAsClean();
            KService::Ptr service(new KService(&desktop, desktopPath));
            if (service->isValid() && service->exec() == command && !service->property<bool>(QStringLiteral("DBusActivatable"))) {
                auto *job = new KIO::ApplicationLauncherJob(service);
                connect(job, &KJob::result, this, [this](KJob *job) {
                    if (job->error()) {
                        Q_EMIT message(job->errorText());
                    }
                });
                job->start();
                return true;
            }
        }
        auto *job = new KIO::CommandLauncherJob(QStringLiteral("flatpak"), {QStringLiteral("run"), scope, installed.ref});
        job->setDesktopName(installed.name);
        connect(job, &KJob::result, this, [this](KJob *job) {
            if (job->error()) {
                Q_EMIT message(job->errorText());
            }
        });
        job->start();
        return true;
    }
    QStringList options;
    if (const auto native = component(app, false)) {
        options = native->launchable(AppStream::Launchable::KindDesktopId).entries();
    }
    const QString package = app.localInfo.value(QStringLiteral("package")).toString();
    options.append({app.desktopId, app.id + QStringLiteral(".desktop"),
                    package.isEmpty() ? QString() : package + QStringLiteral(".desktop")});
    QStringList candidates;
    for (const QString &candidate : std::as_const(options)) {
        if (!candidate.isEmpty() && candidate != QLatin1String(".desktop") && !candidates.contains(candidate)) {
            candidates.append(candidate);
        }
    }
    for (const QString &candidate : std::as_const(candidates)) {
        const QStringList paths = QStandardPaths::locateAll(QStandardPaths::ApplicationsLocation, candidate);
        for (const QString &path : paths) {
            KService::Ptr service(new KService(path));
            if (!service->isValid() || !service->property<QString>(QStringLiteral("X-Flatpak")).isEmpty()) {
                continue;
            }
            auto *job = new KIO::ApplicationLauncherJob(service);
            connect(job, &KJob::result, this, [this](KJob *job) {
                if (job->error()) {
                    Q_EMIT message(job->errorText());
                }
            });
            job->start();
            return true;
        }
    }
    return false;
}

void Store::refresh()
{
    if (loading()) {
        return;
    }
    m_error.clear();
    m_flathubTried = true;
    if (!m_waitingFlathub) {
        m_waitingFlathub = true;
        beginLoading(i18n("Downloading the Flathub catalogue…"));
    }
    QMetaObject::invokeMethod(m_flatpak, "refreshAppstream", Qt::QueuedConnection, Q_ARG(bool, true));
    if (m_debian->available()) {
        m_debianTried = true;
        beginLoading(i18n("Downloading the Debian catalogue…"));
        m_debian->refreshCache([this](bool) {
            m_debian->loadInstalled();
            endLoading();
            loadPool();
        });
    }
    QMetaObject::invokeMethod(m_flatpak, "listInstalled", Qt::QueuedConnection);
}

QString Store::openUrl(const QString &text)
{
    const QUrl url = QUrl::fromUserInput(text, QDir::currentPath(), QUrl::AssumeLocalFile);
    if (text.startsWith(QLatin1String("appstream:"))) {
        QString id = text.mid(10);
        while (id.startsWith(QLatin1Char('/'))) {
            id.remove(0, 1);
        }
        return idFor(id.section(QLatin1Char('/'), 0, 0));
    }
    if (!url.isLocalFile()) {
        return QString();
    }
    const QString path = url.toLocalFile();
    if (path.endsWith(QLatin1String(".flatpakref"), Qt::CaseInsensitive)) {
        return openFlatpakRef(path);
    }
    if (path.endsWith(QLatin1String(".deb"), Qt::CaseInsensitive)) {
        return openDeb(path);
    }
    return QString();
}

QString Store::openFlatpakRef(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly) || file.size() > 1024 * 1024) {
        return QString();
    }
    const QByteArray data = file.readAll();
    QHash<QString, QString> keys;
    for (const QByteArray &line : data.split('\n')) {
        const int at = line.indexOf('=');
        if (at > 0 && !line.startsWith('[') && !line.startsWith('#')) {
            keys.insert(QString::fromUtf8(line.left(at).trimmed()), QString::fromUtf8(line.mid(at + 1).trimmed()));
        }
    }
    const QString name = keys.value(QStringLiteral("Name"));
    if (name.isEmpty() || keys.value(QStringLiteral("IsRuntime")) == QLatin1String("true")) {
        return QString();
    }
    const QString known = m_flatpakIndex.value(name);
    if (!known.isEmpty() && m_apps[known].flatpak) {
        return known;
    }
    App app;
    app.id = QStringLiteral("file:") + path;
    app.name = keys.value(QStringLiteral("Title"), name);
    app.summary = keys.value(QStringLiteral("Comment"));
    app.icon = keys.value(QStringLiteral("Icon"), QStringLiteral("application-x-executable"));
    app.desktopId = name + QStringLiteral(".desktop");
    app.flatpakName = name;
    app.localPath = path;
    app.localKind = QStringLiteral("flatpakref");
    app.localData = data;
    app.localInfo.insert(QStringLiteral("description"), escaped(keys.value(QStringLiteral("Description"), app.summary)));
    app.localInfo.insert(QStringLiteral("homepage"), keys.value(QStringLiteral("Homepage")));
    m_apps.insert(app.id, app);
    return app.id;
}

QString Store::openDeb(const QString &path)
{
    App app;
    app.id = QStringLiteral("file:") + path;
    app.name = QFileInfo(path).completeBaseName().section(QLatin1Char('_'), 0, 0);
    app.icon = QStringLiteral("application-vnd.debian.binary-package");
    app.localPath = path;
    app.localKind = QStringLiteral("deb");
    m_apps.insert(app.id, app);
    const QString id = app.id;
    m_debian->fileDetails(path, [this, id](const QVariantMap &values) {
        if (!m_apps.contains(id)) {
            return;
        }
        App &target = m_apps[id];
        target.localInfo = values;
        const QString package = values.value(QStringLiteral("package")).toString();
        if (!package.isEmpty()) {
            target.name = package;
            target.desktopId = package + QStringLiteral(".desktop");
            const QString desktop = QStandardPaths::locate(QStandardPaths::ApplicationsLocation, target.desktopId);
            if (!desktop.isEmpty()) {
                KService service(desktop);
                if (!service.name().isEmpty()) {
                    target.name = service.name();
                }
                if (!service.icon().isEmpty()) {
                    target.icon = service.icon();
                }
            }
        }
        target.summary = values.value(QStringLiteral("summary")).toString();
        target.localInfo.insert(QStringLiteral("description"), escaped(values.value(QStringLiteral("description")).toString()));
        Q_EMIT appChanged(id);
    });
    return id;
}

void Store::openSystemUpdates() const
{
    QProcess::startDetached(QStringLiteral("kernora-settings"), {QStringLiteral("kcm_updates")});
}
