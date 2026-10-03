// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "portal.h"

#include <QDBusConnection>
#include <QDBusMetaType>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QSet>
#include <QStandardPaths>
#include <QUrl>

#include <KWindowSystem>

using namespace Qt::StringLiterals;

namespace
{
enum Response : uint { Success = 0, Cancelled = 1, Other = 2 };

QString chooserFile()
{
    const QString override = qEnvironmentVariable("KERNORA_QML_FILECHOOSER");
    if (!override.isEmpty()) {
        return QDir(override).filePath(u"Chooser.qml"_s);
    }
    return QStandardPaths::locate(QStandardPaths::GenericDataLocation, u"kernora/filechooser/Chooser.qml"_s);
}

QString pathOf(const QVariant &value)
{
    QByteArray bytes = value.toByteArray();
    while (bytes.endsWith('\0')) {
        bytes.chop(1);
    }
    return QFile::decodeName(bytes);
}

QStringList globsOf(const Portal::Filter &filter)
{
    static const QMimeDatabase database;
    QStringList globs;
    for (const Portal::FilterCondition &condition : filter.conditions) {
        if (condition.type == 0) {
            globs.append(condition.pattern);
            continue;
        }
        if (condition.pattern.endsWith(u"/*"_s)) {
            const QString prefix = condition.pattern.chopped(1);
            const auto types = database.allMimeTypes();
            for (const QMimeType &type : types) {
                if (type.name().startsWith(prefix)) {
                    globs.append(type.globPatterns());
                }
            }
        } else {
            const QMimeType type = database.mimeTypeForName(condition.pattern);
            if (type.isValid()) {
                globs.append(type.globPatterns());
            }
        }
    }
    globs.removeDuplicates();
    if (globs.contains(u"*"_s) || globs.contains(u"*.*"_s)) {
        return {};
    }
    return globs;
}

bool sameFilter(const Portal::Filter &a, const Portal::Filter &b)
{
    if (a.name != b.name || a.conditions.size() != b.conditions.size()) {
        return false;
    }
    for (int i = 0; i < a.conditions.size(); ++i) {
        if (a.conditions[i].type != b.conditions[i].type || a.conditions[i].pattern != b.conditions[i].pattern) {
            return false;
        }
    }
    return true;
}
}

FileChooser::FileChooser(QQmlEngine *engine, QObject *parent)
    : QObject(parent)
    , m_engine(engine)
{
}

uint FileChooser::OpenFile(const QDBusObjectPath &handle, const QString &app_id, const QString &parent_window, const QString &title,
                           const QVariantMap &options, const QDBusMessage &message, QVariantMap &results)
{
    Q_UNUSED(app_id)
    Q_UNUSED(results)
    ask(u"open"_s, handle, parent_window, title, options, message);
    return Other;
}

uint FileChooser::SaveFile(const QDBusObjectPath &handle, const QString &app_id, const QString &parent_window, const QString &title,
                           const QVariantMap &options, const QDBusMessage &message, QVariantMap &results)
{
    Q_UNUSED(app_id)
    Q_UNUSED(results)
    ask(u"save"_s, handle, parent_window, title, options, message);
    return Other;
}

uint FileChooser::SaveFiles(const QDBusObjectPath &handle, const QString &app_id, const QString &parent_window, const QString &title,
                            const QVariantMap &options, const QDBusMessage &message, QVariantMap &results)
{
    Q_UNUSED(app_id)
    Q_UNUSED(results)
    ask(u"saveFiles"_s, handle, parent_window, title, options, message);
    return Other;
}

void FileChooser::ask(const QString &mode, const QDBusObjectPath &handle, const QString &parentWindow, const QString &title,
                      const QVariantMap &options, const QDBusMessage &message)
{
    message.setDelayedReply(true);

    Portal::Filters filters;
    if (options.contains(u"filters"_s)) {
        filters = qdbus_cast<Portal::Filters>(options.value(u"filters"_s));
    }
    int currentFilter = filters.isEmpty() ? -1 : 0;
    if (options.contains(u"current_filter"_s)) {
        const auto current = qdbus_cast<Portal::Filter>(options.value(u"current_filter"_s));
        currentFilter = -1;
        for (int i = 0; i < filters.size(); ++i) {
            if (sameFilter(filters[i], current)) {
                currentFilter = i;
                break;
            }
        }
        if (currentFilter < 0 && !current.conditions.isEmpty()) {
            filters.append(current);
            currentFilter = filters.size() - 1;
        }
    }
    QVariantList filterList;
    for (const Portal::Filter &filter : std::as_const(filters)) {
        filterList.append(QVariantMap{{u"name"_s, filter.name.trimmed()}, {u"globs"_s, globsOf(filter)}});
    }

    QVariantList choiceList;
    if (options.contains(u"choices"_s)) {
        const auto choices = qdbus_cast<Portal::Choices>(options.value(u"choices"_s));
        for (const Portal::Choice &choice : choices) {
            QVariantList choiceOptions;
            for (const Portal::ChoiceOption &option : choice.options) {
                choiceOptions.append(QVariantMap{{u"value"_s, option.id}, {u"label"_s, option.label}});
            }
            choiceList.append(QVariantMap{{u"id"_s, choice.id},
                                          {u"label"_s, choice.label},
                                          {u"options"_s, choiceOptions},
                                          {u"selected"_s, choice.selected}});
        }
    }

    QString folder = pathOf(options.value(u"current_folder"_s));
    const bool folderGiven = !folder.isEmpty() || options.contains(u"current_file"_s);
    QString name = options.value(u"current_name"_s).toString();
    const QString currentFile = pathOf(options.value(u"current_file"_s));
    if (!currentFile.isEmpty()) {
        const QFileInfo file(currentFile);
        folder = file.absolutePath();
        name = file.fileName();
    }
    if (folder.isEmpty() || !QFileInfo(folder).isDir()) {
        folder = QDir::homePath();
    }
    QStringList fileNames;
    if (options.contains(u"files"_s)) {
        const auto files = qdbus_cast<QList<QByteArray>>(options.value(u"files"_s));
        for (const QByteArray &file : files) {
            fileNames.append(QFileInfo(pathOf(file)).fileName());
        }
    }

    auto *request = new PendingRequest(message, handle, filters, this);
    QDBusConnection::sessionBus().registerObject(handle.path(), request, QDBusConnection::ExportScriptableSlots);
    ++m_pending;
    connect(request, &PendingRequest::done, this, [this] {
        if (--m_pending == 0) {
            Q_EMIT idle();
        }
    });

    if (!m_component) {
        m_component = new QQmlComponent(m_engine, QUrl::fromLocalFile(chooserFile()), this);
    }
    const QVariantMap properties{
        {u"mode"_s, mode},
        {u"heading"_s, title},
        {u"acceptLabel"_s, options.value(u"accept_label"_s).toString()},
        {u"multiple"_s, options.value(u"multiple"_s).toBool()},
        {u"directory"_s, options.value(u"directory"_s).toBool()},
        {u"filters"_s, filterList},
        {u"currentFilter"_s, currentFilter},
        {u"choices"_s, choiceList},
        {u"startFolder"_s, QUrl::fromLocalFile(folder)},
        {u"folderGiven"_s, folderGiven},
        {u"startName"_s, name},
        {u"fileNames"_s, fileNames},
    };
    QObject *object = m_component->isReady() ? m_component->createWithInitialProperties(properties) : nullptr;
    auto *window = qobject_cast<QQuickWindow *>(object);
    if (!window) {
        qWarning("kernora-filechooser: %s", qPrintable(m_component->errorString()));
        delete object;
        request->finished(QVariantMap{{u"failed"_s, true}});
        return;
    }
    request->setWindow(window);
    connect(window, SIGNAL(finished(QVariant)), request, SLOT(finished(QVariant)));

    if (parentWindow.startsWith(u"x11:"_s)) {
        KWindowSystem::setMainWindow(window, WId(parentWindow.mid(4).toULongLong(nullptr, 16)));
    } else if (parentWindow.startsWith(u"wayland:"_s)) {
        KWindowSystem::setMainWindow(window, parentWindow.mid(8));
    }
    window->show();
    window->requestActivate();
}

PendingRequest::PendingRequest(const QDBusMessage &message, const QDBusObjectPath &handle, const Portal::Filters &filters, QObject *parent)
    : QObject(parent)
    , m_message(message)
    , m_handle(handle)
    , m_filters(filters)
{
}

void PendingRequest::setWindow(QObject *window)
{
    m_window = window;
}

void PendingRequest::finished(const QVariant &result)
{
    const QVariantMap map = result.toMap();
    if (map.value(u"failed"_s).toBool()) {
        reply(Other, {});
        return;
    }
    if (!map.value(u"accepted"_s).toBool()) {
        reply(Cancelled, {});
        return;
    }
    QVariantMap results;
    results.insert(u"uris"_s, map.value(u"uris"_s).toStringList());
    const int filter = map.value(u"filter"_s, -1).toInt();
    if (filter >= 0 && filter < m_filters.size()) {
        results.insert(u"current_filter"_s, QVariant::fromValue(m_filters.at(filter)));
    }
    const QVariantList choices = map.value(u"choices"_s).toList();
    if (!choices.isEmpty()) {
        Portal::ChoiceResults chosen;
        for (const QVariant &choice : choices) {
            const QVariantMap entry = choice.toMap();
            chosen.append({entry.value(u"id"_s).toString(), entry.value(u"value"_s).toString()});
        }
        results.insert(u"choices"_s, QVariant::fromValue(chosen));
    }
    reply(Success, results);
}

void PendingRequest::Close()
{
    reply(Other, {});
}

void PendingRequest::reply(uint response, const QVariantMap &results)
{
    if (m_answered) {
        return;
    }
    m_answered = true;
    QDBusConnection::sessionBus().send(m_message.createReply(QVariantList{QVariant::fromValue(response), results}));
    QDBusConnection::sessionBus().unregisterObject(m_handle.path());
    if (m_window) {
        m_window->deleteLater();
    }
    Q_EMIT done();
    deleteLater();
}
