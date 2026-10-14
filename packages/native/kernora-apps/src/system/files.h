// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QJSValue>
#include <QObject>
#include <QUrl>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class Files : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Files(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap info(const QUrl &url) const;
    Q_INVOKABLE QString mimeType(const QUrl &url) const;
    Q_INVOKABLE QString iconName(const QUrl &url) const;
    Q_INVOKABLE bool exists(const QUrl &url) const;

    Q_INVOKABLE QVariantMap readText(const QUrl &url) const;
    Q_INVOKABLE bool writeText(const QUrl &url, const QString &text);

    Q_INVOKABLE void trash(const QList<QUrl> &urls, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void remove(const QList<QUrl> &urls, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void rename(const QUrl &url, const QString &newName, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void copy(const QList<QUrl> &urls, const QUrl &destination, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void showProperties(const QList<QUrl> &urls);
    Q_INVOKABLE void restore(const QList<QUrl> &urls, const QJSValue &callback = QJSValue());
    Q_INVOKABLE QUrl trashFolder() const;
    Q_INVOKABLE QVariantMap trashInfo(const QUrl &url) const;
    Q_INVOKABLE void createFolder(const QUrl &parent, const QString &name, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void move(const QList<QUrl> &urls, const QUrl &destination, const QJSValue &callback = QJSValue());
    Q_INVOKABLE QList<QUrl> conflicts(const QList<QUrl> &urls, const QUrl &destination) const;
    Q_INVOKABLE void transfer(const QList<QUrl> &urls, const QUrl &destination, bool move, const QString &onConflict,
                              const QJSValue &callback = QJSValue());
    Q_INVOKABLE qint64 trashSize() const;
    Q_INVOKABLE void emptyTrash(const QJSValue &callback = QJSValue());

    Q_INVOKABLE bool isArchive(const QUrl &url) const;
    Q_INVOKABLE void compress(const QList<QUrl> &urls, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void extract(const QUrl &archive, const QJSValue &callback = QJSValue());

    Q_INVOKABLE QUrl standardFolder(const QString &name) const;
    Q_INVOKABLE QList<QUrl> siblings(const QUrl &url, const QString &mimePrefix) const;
    Q_INVOKABLE QString uniqueName(const QUrl &folder, const QString &baseName) const;

    Q_INVOKABLE void setWallpaper(const QUrl &image);
    Q_INVOKABLE void setLiveWallpaper(const QString &plugin = QStringLiteral("org.kernora.shapes"));
    Q_INVOKABLE QVariantList liveWallpapers() const;
    Q_INVOKABLE void setLockScreenWallpaper(const QUrl &image);
    Q_INVOKABLE void setLockScreenPlugin(const QString &plugin);
    Q_INVOKABLE void syncGreeterBackground(const QString &plugin, const QUrl &image = QUrl());
    Q_INVOKABLE QVariantList wallpapers() const;

private:
    void report(const QJSValue &callback, bool ok, const QString &message = QString());
};
