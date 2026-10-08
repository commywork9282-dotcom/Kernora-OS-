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
    Q_PROPERTY(QVariantMap formats READ formats NOTIFY changed)
    Q_PROPERTY(QString keyboardModel READ keyboardModel NOTIFY keyboardChanged)
    Q_PROPERTY(QStringList keyboardOptions READ keyboardOptions NOTIFY keyboardChanged)

public:
    explicit Locales(QObject *parent = nullptr);

    QString language() const;
    QString region() const;
    bool busy() const { return m_busy; }
    QVariantMap formats() const;
    QString keyboardModel() const;
    QStringList keyboardOptions() const;

    Q_INVOKABLE QVariantList languages() const;
    Q_INVOKABLE QVariantList regions() const;
    Q_INVOKABLE QString languageName(const QString &code) const;
    Q_INVOKABLE QString regionName(const QString &locale) const;
    Q_INVOKABLE void setLanguage(const QString &code);
    Q_INVOKABLE void setRegion(const QString &locale);
    Q_INVOKABLE QVariantMap formatSamples(const QString &locale) const;
    Q_INVOKABLE QString formatSample(const QString &category, const QString &locale) const;
    Q_INVOKABLE void setFormat(const QString &category, const QString &locale);

    Q_INVOKABLE QVariantList keyboardLayouts() const;
    Q_INVOKABLE QVariantList currentLayouts() const;
    Q_INVOKABLE void setLayouts(const QVariantList &layouts);
    Q_INVOKABLE QString layoutSwitchOption() const;
    Q_INVOKABLE void setLayoutSwitchOption(const QString &option);
    Q_INVOKABLE QVariantList keyboardModels() const;
    Q_INVOKABLE void setKeyboardModel(const QString &model);
    Q_INVOKABLE QVariantList keyboardOptionGroups() const;
    Q_INVOKABLE void setKeyboardOption(const QString &option, bool on);
    Q_INVOKABLE void setKeyboardGroupChoice(const QString &group, const QString &option);
    Q_INVOKABLE QString shortcutText(const QVariantList &keys) const;

Q_SIGNALS:
    void changed();
    void keyboardChanged();
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
    void readKeyboardRules() const;
    void writeKeyboardOptions(const QStringList &options);

    bool m_busy = false;
    bool m_listening = false;
    std::function<void()> m_pending;
    mutable QVariantList m_layoutCache;
    mutable QVariantList m_modelCache;
    mutable QVariantList m_optionGroupCache;
};
