// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QJSValue>
#include <QObject>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class Screenshot : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Screenshot(QObject *parent = nullptr);

    Q_INVOKABLE void captureWorkspace(bool cursor, const QJSValue &callback);
    Q_INVOKABLE void captureActiveWindow(bool cursor, const QJSValue &callback);
    Q_INVOKABLE void captureActiveScreen(bool cursor, const QJSValue &callback);
    Q_INVOKABLE bool discard(const QUrl &image);
    Q_INVOKABLE void captureInteractive(int kind, bool cursor, const QJSValue &callback);
    Q_INVOKABLE QUrl crop(const QUrl &image, int x, int y, int width, int height);
    Q_INVOKABLE QUrl save(const QUrl &image);
    Q_INVOKABLE void copyToClipboard(const QUrl &image);

private:
    void capture(const QString &method, const QVariantList &arguments, const QJSValue &callback);
    void deliver(const QJSValue &callback, bool ok, const QVariant &first, int width = 0, int height = 0);
    QString temporaryFile() const;

    int m_counter = 0;
};
