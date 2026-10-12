// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QByteArray>
#include <QHash>
#include <QList>
#include <QMetaType>
#include <QMutex>
#include <QObject>
#include <QString>
#include <QStringList>

typedef struct _FlatpakInstallation FlatpakInstallation;
typedef struct _GCancellable GCancellable;

struct FlatpakApp {
    QString name;
    QString ref;
    QString origin;
    QString installation;
    QString title;
    QString summary;
    QString version;
    qint64 size = 0;
};
Q_DECLARE_METATYPE(FlatpakApp)

class FlatpakWorker : public QObject
{
    Q_OBJECT

public:
    enum Action {
        Install,
        Remove,
        Update,
        InstallRef,
    };
    Q_ENUM(Action)

    explicit FlatpakWorker(QObject *parent = nullptr);
    ~FlatpakWorker() override;

    void cancel(const QString &job);
    void stop();

public Q_SLOTS:
    void listInstalled();
    void refreshAppstream(bool force);
    void checkUpdates();
    void run(const QString &job, int action, const QString &ref, const QString &installation, const QByteArray &data);

Q_SIGNALS:
    void installedListed(const QList<FlatpakApp> &apps);
    void appstreamRefreshed(bool changed, const QString &error);
    void updatesChecked(const QStringList &names, const QStringList &refs, const QString &error);
    void progress(const QString &job, int percent, const QString &status);
    void finished(const QString &job, bool success, const QString &error);

private:
    FlatpakInstallation *installation(const QString &name);
    GCancellable *beginJob(const QString &job);
    void endJob(const QString &job);

    FlatpakInstallation *m_system = nullptr;
    FlatpakInstallation *m_user = nullptr;
    GCancellable *m_background = nullptr;
    bool m_stopping = false;
    QMutex m_mutex;
    QHash<QString, GCancellable *> m_cancellables;
};
