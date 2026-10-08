// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <KConfigWatcher>
#include <QJSValue>
#include <QObject>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

#include <memory>

class Appearance : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool dark READ dark NOTIFY darkChanged)
    Q_PROPERTY(QString generation READ generation NOTIFY generationChanged)
    Q_PROPERTY(QString colour READ colour NOTIFY colourChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit Appearance(QObject *parent = nullptr);

    bool dark() const;
    QString generation() const;
    QString colour() const;
    bool busy() const { return m_busy; }

    Q_INVOKABLE void setDark(bool dark, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void setGeneration(const QString &generation, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void apply(const QString &generation, bool dark, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void setColour(const QString &colour, const QJSValue &callback = QJSValue());
    Q_INVOKABLE QVariantList colours() const;
    Q_INVOKABLE QStringList fontFamilies(bool monospace) const;

Q_SIGNALS:
    void darkChanged();
    void generationChanged();
    void colourChanged();
    void busyChanged();

private:
    struct Switch;
    void writeTerminalColours(const QString &colour, bool dark) const;
    void applyTheme(const QString &colour, const QString &generation, bool dark, const QJSValue &callback);
    void runStep(const std::shared_ptr<Switch> &state, int index);

    KConfigWatcher::Ptr m_watcher;
    bool m_busy = false;
};
