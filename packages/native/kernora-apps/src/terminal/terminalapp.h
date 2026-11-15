// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QKeySequence>
#include <QList>
#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QVariantList>

#include <KSharedConfig>

class QQmlEngine;
class TerminalWindow;

class TerminalApp : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString fontFamily READ fontFamily WRITE setFontFamily NOTIFY appearanceChanged)
    Q_PROPERTY(int fontSize READ fontSize WRITE setFontSize NOTIFY appearanceChanged)
    Q_PROPERTY(bool lightField READ lightField WRITE setLightField NOTIFY appearanceChanged)
    Q_PROPERTY(QString cursorShape READ cursorShape WRITE setCursorShape NOTIFY appearanceChanged)
    Q_PROPERTY(QStringList fontFamilies READ fontFamilies CONSTANT)
    Q_PROPERTY(QVariantList shortcuts READ shortcuts NOTIFY shortcutsChanged)
    Q_PROPERTY(int defaultFontSize READ defaultFontSize CONSTANT)
    Q_PROPERTY(QString prompt READ prompt CONSTANT)

public:
    explicit TerminalApp(QObject *parent = nullptr);
    ~TerminalApp() override;

    QQmlEngine *engine();
    TerminalWindow *newWindow(const QString &directory = {}, const QStringList &command = {});

    QString fontFamily() const;
    void setFontFamily(const QString &family);
    int fontSize() const;
    void setFontSize(int size);
    int defaultFontSize() const;
    bool lightField() const;
    void setLightField(bool light);
    QString cursorShape() const;
    void setCursorShape(const QString &shape);
    QStringList fontFamilies() const;
    QString prompt() const;

    QVariantList shortcuts() const;
    QKeySequence keys(const QString &id) const;
    Q_INVOKABLE void setShortcutEnabled(const QString &id, bool enabled);
    Q_INVOKABLE void setShortcutKeys(const QString &id, int key, int modifiers);
    Q_INVOKABLE void resetShortcut(const QString &id);
    Q_INVOKABLE QString keyText(int key, int modifiers) const;
    Q_INVOKABLE QString conflictFor(const QString &id, int key, int modifiers) const;

Q_SIGNALS:
    void appearanceChanged();
    void shortcutsChanged();

private:
    struct Shortcut {
        QString id;
        QString title;
        QKeySequence defaults;
    };
    const Shortcut *shortcut(const QString &id) const;
    QString describe(const QKeySequence &sequence) const;

    KSharedConfigPtr m_config;
    QQmlEngine *m_engine = nullptr;
    QList<Shortcut> m_shortcuts;
    QList<QPointer<TerminalWindow>> m_windows;
};
