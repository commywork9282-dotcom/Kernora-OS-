// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QObject>

#include <functional>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class Locales : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString language READ language NOTIFY changed)
    Q_PROPERTY(QString region READ region NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit Locales(QObject *parent = nullptr);

    QString language() const;
    QString region() const;
    bool busy() const { return m_busy; }

    Q_INVOKABLE QVariantList languages() const;
    Q_INVOKABLE QVariantList regions() const;
    Q_INVOKABLE QString languageName(const QString &code) const;
    Q_INVOKABLE QString regionName(const QString &locale) const;
    Q_INVOKABLE void setLanguage(const QString &code);
    Q_INVOKABLE void setRegion(const QString &locale);
    Q_INVOKABLE QVariantMap formatSamples(const QString &locale) const;

    Q_INVOKABLE QVariantList keyboardLayouts() const;
    Q_INVOKABLE QVariantList currentLayouts() const;
    Q_INVOKABLE void setLayouts(const QVariantList &layouts);
    Q_INVOKABLE QString layoutSwitchOption() const;
    Q_INVOKABLE void setLayoutSwitchOption(const QString &option);

Q_SIGNALS:
    void changed();
    void busyChanged();
    void failed(const QString &message);
    void needsRelogin();

private Q_SLOTS:
    void onGenerated();
    void onGenerationFailed(const QString &message);

private:
    void ensureGenerated(const QString &locale, std::function<void()> then);
    static QStringList generatedLocales();
    void reloadKeyboard();

    bool m_busy = false;
    bool m_listening = false;
    std::function<void()> m_pending;
    mutable QVariantList m_layoutCache;
};
