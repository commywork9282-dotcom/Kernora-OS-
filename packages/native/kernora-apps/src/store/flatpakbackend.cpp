// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "flatpakbackend.h"

#include <flatpak.h>

#include <QDateTime>
#include <QFileInfo>
#include <QMutexLocker>

#include <KFormat>
#include <KLocalizedString>

namespace
{
QString utf8(const char *text)
{
    return text ? QString::fromUtf8(text) : QString();
}

struct Run {
    FlatpakWorker *worker = nullptr;
    QString job;
    QString error;
    guint64 total = 0;
    guint64 done = 0;
    guint64 current = 0;
    int count = 0;
    int index = 0;
    bool removing = false;
};

void emitProgress(Run *run, FlatpakTransactionProgress *progress)
{
    const int percent = qBound(0, flatpak_transaction_progress_get_progress(progress), 100);
    const guint64 bytes = qMin(flatpak_transaction_progress_get_bytes_transferred(progress), run->current);
    int overall = percent;
    if (run->total > 0) {
        const guint64 downloaded = run->done + (run->current > 0 ? bytes : 0);
        overall = int(qMin<guint64>(100, downloaded * 100 / run->total));
        if (run->index + 1 >= run->count) {
            overall = qMax(overall, (overall + percent) / 2);
        }
    } else if (run->count > 0) {
        overall = (run->index * 100 + percent) / run->count;
    }
    QString status;
    if (run->removing) {
        status = i18n("Removing…");
    } else if (run->total > 0 && run->current > 0 && bytes < run->current) {
        const KFormat format;
        status = i18n("Downloading %1 of %2", format.formatByteSize(double(run->done + bytes), 1, KFormat::JEDECBinaryDialect), format.formatByteSize(double(run->total), 1, KFormat::JEDECBinaryDialect));
    } else {
        status = i18n("Installing…");
    }
    Q_EMIT run->worker->progress(run->job, overall, status);
}

void onProgressChanged(FlatpakTransactionProgress *progress, gpointer data)
{
    emitProgress(static_cast<Run *>(data), progress);
}

gboolean onReady(FlatpakTransaction *transaction, gpointer data)
{
    auto *run = static_cast<Run *>(data);
    GList *operations = flatpak_transaction_get_operations(transaction);
    run->count = int(g_list_length(operations));
    run->total = 0;
    for (GList *item = operations; item; item = item->next) {
        auto *operation = FLATPAK_TRANSACTION_OPERATION(item->data);
        run->total += flatpak_transaction_operation_get_download_size(operation);
    }
    g_list_free_full(operations, g_object_unref);
    return TRUE;
}

void onNewOperation(FlatpakTransaction *, FlatpakTransactionOperation *operation, FlatpakTransactionProgress *progress, gpointer data)
{
    auto *run = static_cast<Run *>(data);
    run->current = flatpak_transaction_operation_get_download_size(operation);
    run->removing = flatpak_transaction_operation_get_operation_type(operation) == FLATPAK_TRANSACTION_OPERATION_UNINSTALL;
    flatpak_transaction_progress_set_update_frequency(progress, 200);
    g_signal_connect(progress, "changed", G_CALLBACK(onProgressChanged), data);
    emitProgress(run, progress);
}

void onOperationDone(FlatpakTransaction *, FlatpakTransactionOperation *operation, const char *, int, gpointer data)
{
    auto *run = static_cast<Run *>(data);
    run->done += flatpak_transaction_operation_get_download_size(operation);
    run->current = 0;
    run->index += 1;
}

gboolean onOperationError(FlatpakTransaction *, FlatpakTransactionOperation *, GError *error, int details, gpointer data)
{
    auto *run = static_cast<Run *>(data);
    if (details & FLATPAK_TRANSACTION_ERROR_DETAILS_NON_FATAL) {
        return TRUE;
    }
    if (error && !g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED)) {
        run->error = utf8(error->message);
    }
    return FALSE;
}

gboolean onAddNewRemote(FlatpakTransaction *, int, const char *, const char *, const char *, gpointer)
{
    return TRUE;
}

int onChooseRemote(FlatpakTransaction *, const char *, const char *, const char *const *remotes, gpointer)
{
    for (int index = 0; remotes && remotes[index]; ++index) {
        if (qstrcmp(remotes[index], "flathub") == 0) {
            return index;
        }
    }
    return 0;
}

gboolean onEndOfLifedWithRebase(FlatpakTransaction *, const char *, const char *, const char *, const char *rebasedTo, const char *const *, gpointer)
{
    return rebasedTo != nullptr;
}

bool cancelled(GError *error)
{
    return error && g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED);
}
}

FlatpakWorker::FlatpakWorker(QObject *parent)
    : QObject(parent)
{
    m_background = g_cancellable_new();
    qRegisterMetaType<FlatpakApp>();
    qRegisterMetaType<QList<FlatpakApp>>();
}

FlatpakWorker::~FlatpakWorker()
{
    g_object_unref(m_background);
    if (m_system) {
        g_object_unref(m_system);
    }
    if (m_user) {
        g_object_unref(m_user);
    }
}

FlatpakInstallation *FlatpakWorker::installation(const QString &name)
{
    GError *error = nullptr;
    if (name == QLatin1String("user")) {
        if (!m_user) {
            m_user = flatpak_installation_new_user(nullptr, &error);
            g_clear_error(&error);
        }
        return m_user;
    }
    if (!m_system) {
        m_system = flatpak_installation_new_system(nullptr, &error);
        g_clear_error(&error);
    }
    return m_system;
}

GCancellable *FlatpakWorker::beginJob(const QString &job)
{
    QMutexLocker lock(&m_mutex);
    if (m_stopping) {
        return nullptr;
    }
    if (m_cancellables.contains(job)) {
        GCancellable *existing = m_cancellables.value(job);
        if (!existing) {
            m_cancellables.remove(job);
            return nullptr;
        }
    }
    GCancellable *cancellable = g_cancellable_new();
    m_cancellables.insert(job, cancellable);
    return cancellable;
}

void FlatpakWorker::endJob(const QString &job)
{
    QMutexLocker lock(&m_mutex);
    GCancellable *cancellable = m_cancellables.take(job);
    if (cancellable) {
        g_object_unref(cancellable);
    }
}

void FlatpakWorker::cancel(const QString &job)
{
    QMutexLocker lock(&m_mutex);
    auto found = m_cancellables.find(job);
    if (found == m_cancellables.end()) {
        m_cancellables.insert(job, nullptr);
        return;
    }
    if (found.value()) {
        g_cancellable_cancel(found.value());
    }
}

void FlatpakWorker::stop()
{
    QMutexLocker lock(&m_mutex);
    m_stopping = true;
    g_cancellable_cancel(m_background);
    for (GCancellable *job : std::as_const(m_cancellables)) {
        if (job) {
            g_cancellable_cancel(job);
        }
    }
}

void FlatpakWorker::listInstalled()
{
    QList<FlatpakApp> apps;
    for (const QString &name : {QStringLiteral("system"), QStringLiteral("user")}) {
        FlatpakInstallation *target = installation(name);
        if (!target) {
            continue;
        }
        flatpak_installation_drop_caches(target, nullptr, nullptr);
        GError *error = nullptr;
        GPtrArray *refs = flatpak_installation_list_installed_refs_by_kind(target, FLATPAK_REF_KIND_APP, m_background, &error);
        g_clear_error(&error);
        if (!refs) {
            continue;
        }
        for (guint index = 0; index < refs->len; ++index) {
            auto *ref = FLATPAK_INSTALLED_REF(g_ptr_array_index(refs, index));
            FlatpakApp app;
            app.name = utf8(flatpak_ref_get_name(FLATPAK_REF(ref)));
            char *formatted = flatpak_ref_format_ref(FLATPAK_REF(ref));
            app.ref = utf8(formatted);
            g_free(formatted);
            app.origin = utf8(flatpak_installed_ref_get_origin(ref));
            app.installation = name;
            app.title = utf8(flatpak_installed_ref_get_appdata_name(ref));
            app.summary = utf8(flatpak_installed_ref_get_appdata_summary(ref));
            app.version = utf8(flatpak_installed_ref_get_appdata_version(ref));
            app.size = qint64(flatpak_installed_ref_get_installed_size(ref));
            apps.append(app);
        }
        g_ptr_array_unref(refs);
    }
    Q_EMIT installedListed(apps);
}

void FlatpakWorker::refreshAppstream(bool force)
{
    bool changed = false;
    QString message;
    for (const QString &name : {QStringLiteral("system"), QStringLiteral("user")}) {
        FlatpakInstallation *target = installation(name);
        if (!target) {
            continue;
        }
        GError *error = nullptr;
        GPtrArray *remotes = flatpak_installation_list_remotes(target, m_background, &error);
        g_clear_error(&error);
        if (!remotes) {
            continue;
        }
        for (guint index = 0; index < remotes->len; ++index) {
            auto *remote = FLATPAK_REMOTE(g_ptr_array_index(remotes, index));
            if (flatpak_remote_get_disabled(remote) || flatpak_remote_get_noenumerate(remote)) {
                continue;
            }
            const char *remoteName = flatpak_remote_get_name(remote);
            if (!force) {
                GFile *stamp = flatpak_remote_get_appstream_timestamp(remote, nullptr);
                char *path = stamp ? g_file_get_path(stamp) : nullptr;
                const QFileInfo info(utf8(path));
                g_free(path);
                if (stamp) {
                    g_object_unref(stamp);
                }
                if (info.exists() && info.lastModified().secsTo(QDateTime::currentDateTime()) < 6 * 3600) {
                    continue;
                }
            }
            gboolean updated = FALSE;
            if (flatpak_installation_update_appstream_full_sync(target, remoteName, nullptr, nullptr, nullptr, &updated, m_background, &error)) {
                changed = changed || updated;
            } else {
                message = utf8(error ? error->message : nullptr);
            }
            g_clear_error(&error);
        }
        g_ptr_array_unref(remotes);
    }
    Q_EMIT appstreamRefreshed(changed, message);
}

void FlatpakWorker::checkUpdates()
{
    QString message;
    QStringList names;
    QStringList refs;
    for (const QString &name : {QStringLiteral("system"), QStringLiteral("user")}) {
        FlatpakInstallation *target = installation(name);
        if (!target) {
            continue;
        }
        GError *error = nullptr;
        GPtrArray *updates = flatpak_installation_list_installed_refs_for_update(target, m_background, &error);
        if (error && !cancelled(error)) {
            message = utf8(error->message);
        }
        g_clear_error(&error);
        if (!updates) {
            continue;
        }
        for (guint index = 0; index < updates->len; ++index) {
            auto *ref = FLATPAK_REF(g_ptr_array_index(updates, index));
            char *formatted = flatpak_ref_format_ref(ref);
            refs.append(name + QLatin1Char('\t') + utf8(formatted));
            g_free(formatted);
            if (flatpak_ref_get_kind(ref) == FLATPAK_REF_KIND_APP) {
                names.append(utf8(flatpak_ref_get_name(ref)));
            }
        }
        g_ptr_array_unref(updates);
    }
    Q_EMIT updatesChecked(names, refs, message);
}

void FlatpakWorker::run(const QString &job, int action, const QString &ref, const QString &installationName, const QByteArray &data)
{
    GCancellable *cancellable = beginJob(job);
    if (!cancellable) {
        Q_EMIT finished(job, false, QString());
        return;
    }

    QList<QPair<QString, QStringList>> batches;
    if (action == Update && ref.isEmpty()) {
        for (const QString &name : {QStringLiteral("system"), QStringLiteral("user")}) {
            FlatpakInstallation *target = installation(name);
            if (!target) {
                continue;
            }
            GError *error = nullptr;
            GPtrArray *updates = flatpak_installation_list_installed_refs_for_update(target, cancellable, &error);
            if (error) {
                const QString message = cancelled(error) ? QString() : utf8(error->message);
                g_clear_error(&error);
                endJob(job);
                Q_EMIT finished(job, false, message);
                return;
            }
            QStringList list;
            for (guint index = 0; updates && index < updates->len; ++index) {
                char *formatted = flatpak_ref_format_ref(FLATPAK_REF(g_ptr_array_index(updates, index)));
                list.append(utf8(formatted));
                g_free(formatted);
            }
            if (updates) {
                g_ptr_array_unref(updates);
            }
            if (!list.isEmpty()) {
                batches.append({name, list});
            }
        }
    } else {
        batches.append({installationName.isEmpty() ? QStringLiteral("system") : installationName, {ref}});
    }

    bool success = true;
    QString message;
    for (const auto &batch : std::as_const(batches)) {
        FlatpakInstallation *target = installation(batch.first);
        GError *error = nullptr;
        FlatpakTransaction *transaction = target ? flatpak_transaction_new_for_installation(target, cancellable, &error) : nullptr;
        if (!transaction) {
            message = error ? utf8(error->message) : i18n("Flatpak is not available.");
            g_clear_error(&error);
            success = false;
            break;
        }

        bool added = true;
        for (const QString &item : batch.second) {
            const QByteArray refBytes = item.toUtf8();
            switch (action) {
            case Install:
                added = flatpak_transaction_add_install(transaction, data.constData(), refBytes.constData(), nullptr, &error);
                break;
            case InstallRef: {
                GBytes *bytes = g_bytes_new(data.constData(), gsize(data.size()));
                added = flatpak_transaction_add_install_flatpakref(transaction, bytes, &error);
                g_bytes_unref(bytes);
                break;
            }
            case Remove:
                flatpak_transaction_set_include_unused_uninstall_ops(transaction, TRUE);
                added = flatpak_transaction_add_uninstall(transaction, refBytes.constData(), &error);
                break;
            case Update:
                added = flatpak_transaction_add_update(transaction, refBytes.constData(), nullptr, nullptr, &error);
                break;
            }
            if (!added) {
                break;
            }
        }

        Run state;
        state.worker = this;
        state.job = job;
        if (added) {
            g_signal_connect(transaction, "ready", G_CALLBACK(onReady), &state);
            g_signal_connect(transaction, "new-operation", G_CALLBACK(onNewOperation), &state);
            g_signal_connect(transaction, "operation-done", G_CALLBACK(onOperationDone), &state);
            g_signal_connect(transaction, "operation-error", G_CALLBACK(onOperationError), &state);
            g_signal_connect(transaction, "add-new-remote", G_CALLBACK(onAddNewRemote), &state);
            g_signal_connect(transaction, "choose-remote-for-ref", G_CALLBACK(onChooseRemote), &state);
            g_signal_connect(transaction, "end-of-lifed-with-rebase", G_CALLBACK(onEndOfLifedWithRebase), &state);
            added = flatpak_transaction_run(transaction, cancellable, &error);
        }
        if (!added) {
            success = false;
            if (!cancelled(error)) {
                message = !state.error.isEmpty() ? state.error : utf8(error ? error->message : nullptr);
                if (message.isEmpty()) {
                    message = i18n("The app could not be installed.");
                }
            }
        }
        g_clear_error(&error);
        g_object_unref(transaction);
        if (!success) {
            break;
        }
    }

    endJob(job);
    listInstalled();
    Q_EMIT finished(job, success, message);
}
