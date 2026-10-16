// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "flatpakbackend.h"

#include <QHash>
#include <QObject>
#include <QStringList>
#include <QThread>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include <AppStreamQt/component.h>

#include <optional>

class QJSEngine;
class QQmlEngine;
class QNetworkAccessManager;
class DebianBackend;

namespace AppStream
{
class Pool;
}

class Store : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool ready READ ready NOTIFY stateChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY stateChanged)
    Q_PROPERTY(QString loadingText READ loadingText NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(bool live READ live CONSTANT)
    Q_PROPERTY(bool checkingUpdates READ checkingUpdates NOTIFY updatesChanged)
    Q_PROPERTY(QString updateError READ updateError NOTIFY updatesChanged)
    Q_PROPERTY(int updateCount READ updateCount NOTIFY updatesChanged)
    Q_PROPERTY(int pendingUpdates READ pendingUpdates NOTIFY updatesChanged)
    Q_PROPERTY(int installedCount READ installedCount NOTIFY catalogChanged)
    Q_PROPERTY(int busyCount READ busyCount NOTIFY jobsChanged)
    Q_PROPERTY(QVariantList categories READ categories CONSTANT)

public:
    enum Filter {
        All,
        Installed,
        Updates,
    };
    Q_ENUM(Filter)

    enum Role {
        IdRole = Qt::UserRole + 1,
        NameRole,
        SummaryRole,
        IconRole,
        DeveloperRole,
        InstalledRole,
        BusyRole,
        ProgressRole,
        StatusRole,
        UpdateRole,
        VerifiedRole,
        SourceRole,
        RatingRole,
        AccentRole,
    };

    static Store *instance();
    static Store *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    bool ready() const { return m_ready; }
    bool loading() const { return m_loading > 0; }
    QString loadingText() const { return m_loadingText; }
    QString error() const { return m_error; }
    bool live() const;
    bool checkingUpdates() const { return m_checkingUpdates; }
    QString updateError() const { return m_updateError; }
    int updateCount() const;
    int pendingUpdates() const { return m_pendingRefs.size(); }
    int installedCount() const;
    int busyCount() const { return m_jobs.size(); }
    QVariantList categories() const;

    Q_INVOKABLE QVariantMap details(const QString &id) const;
    Q_INVOKABLE QVariantMap state(const QString &id) const;
    Q_INVOKABLE QStringList collection(const QString &name) const;
    Q_INVOKABLE QString categoryName(const QString &category) const;
    Q_INVOKABLE void install(const QString &id, const QString &source);
    Q_INVOKABLE void remove(const QString &id);
    Q_INVOKABLE void update(const QString &id);
    Q_INVOKABLE void updateAll();
    Q_INVOKABLE void cancel(const QString &id);
    Q_INVOKABLE bool launch(const QString &id);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE QString openUrl(const QString &url);
    Q_INVOKABLE void openSystemUpdates() const;

    QStringList query(const QString &text, const QString &category, Filter filter) const;
    QVariant value(const QString &id, int role) const;
    bool contains(const QString &id) const { return m_apps.contains(id); }

Q_SIGNALS:
    void stateChanged();
    void catalogChanged();
    void appChanged(const QString &id);
    void updatesChanged();
    void jobsChanged();
    void message(const QString &text);

private:
    struct App {
        QString id;
        QString name;
        QString summary;
        QString developer;
        QString icon;
        QString desktopId;
        QString accentLight;
        QString accentDark;
        QStringList categories;
        QString flatpakName;
        QString flatpakRef;
        QString flatpakRemote;
        QStringList packages;
        bool verified = false;
        bool flatpak = false;
        bool debian = false;
        QString flatpakComponent;
        QString debianComponent;
        std::optional<FlatpakApp> installedFlatpak;
        bool update = false;
        QString localPath;
        QString localKind;
        QByteArray localData;
        QVariantMap localInfo;
    };

    struct Job {
        QString action;
        QString source;
        int progress = -1;
        QString status;
    };

    struct Rating {
        int total = 0;
        double stars = 0;
        QVariantList votes;
    };

    explicit Store(QObject *parent = nullptr);
    ~Store() override;

    void beginLoading(const QString &text);
    void endLoading();
    void loadPool();
    void buildCatalog();
    void sortCatalog();
    void loadRatings();
    void fetchRatings();
    void applyInstalled(const QList<FlatpakApp> &apps);
    void attachInstalled();
    void applyUpdates(const QStringList &names, const QStringList &refs, const QString &error);
    void startJob(const QString &id, const QString &action, const QString &source);
    void jobProgress(const QString &id, int percent, const QString &status);
    void jobFinished(const QString &id, bool success, const QString &error);
    void notify(const QString &title, const QString &text, const QString &icon);
    bool debianInstalled(const App &app) const;
    bool isInstalled(const App &app) const;
    QString installedSource(const App &app) const;
    QString iconFor(const AppStream::Component &component) const;
    std::optional<AppStream::Component> component(const App &app, bool flatpak) const;
    QString idFor(const QString &id) const;
    QString openFlatpakRef(const QString &path);
    QString openDeb(const QString &path);

    AppStream::Pool *m_pool = nullptr;
    QThread m_thread;
    FlatpakWorker *m_flatpak = nullptr;
    DebianBackend *m_debian = nullptr;
    QNetworkAccessManager *m_network = nullptr;

    QHash<QString, App> m_apps;
    QStringList m_order;
    QHash<QString, QString> m_flatpakIndex;
    QHash<QString, Job> m_jobs;
    QHash<QString, Rating> m_ratings;
    QHash<QString, QStringList> m_collections;
    QStringList m_pendingRefs;
    QStringList m_updateNames;
    QList<FlatpakApp> m_installed;

    QString m_updateError;
    bool m_checkingUpdates = true;
    bool m_ready = false;
    int m_loading = 0;
    QString m_loadingText;
    QString m_error;
    bool m_flathubTried = false;
    bool m_debianTried = false;
    bool m_waitingFlathub = false;
    bool m_poolLoading = false;
    bool m_reloadPending = false;
};
