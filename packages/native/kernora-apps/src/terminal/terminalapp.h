// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "colorschemes.h"

#include <QColor>
#include <QKeySequence>
#include <QList>
#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QVariantList>

#include <KSharedConfig>

class PortControl;
class QQmlEngine;
class TerminalWindow;

class TerminalApp : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString fontFamily READ fontFamily WRITE setFontFamily NOTIFY appearanceChanged)
    Q_PROPERTY(QString effectiveFontFamily READ effectiveFontFamily NOTIFY appearanceChanged)
    Q_PROPERTY(int fontSize READ fontSize WRITE setFontSize NOTIFY appearanceChanged)
    Q_PROPERTY(int defaultFontSize READ defaultFontSize CONSTANT)
    Q_PROPERTY(QStringList fontFamilies READ fontFamilies CONSTANT)
    Q_PROPERTY(QVariantList schemes READ schemes NOTIFY schemesChanged)
    Q_PROPERTY(QString lightScheme READ lightScheme WRITE setLightScheme NOTIFY appearanceChanged)
    Q_PROPERTY(QString darkScheme READ darkScheme WRITE setDarkScheme NOTIFY appearanceChanged)
    Q_PROPERTY(bool systemDark READ systemDark NOTIFY appearanceChanged)
    Q_PROPERTY(QVariantList shortcuts READ shortcuts NOTIFY shortcutsChanged)
    Q_PROPERTY(int memoryLimit READ memoryLimit WRITE setMemoryLimit NOTIFY advancedChanged)
    Q_PROPERTY(QVariantList memoryChoices READ memoryChoices CONSTANT)
    Q_PROPERTY(bool keepAwake READ keepAwake WRITE setKeepAwake NOTIFY advancedChanged)
    Q_PROPERTY(QVariantList listeningPorts READ listeningPorts NOTIFY portsChanged)
    Q_PROPERTY(QVariantList allowedPorts READ allowedPorts NOTIFY portsChanged)
    Q_PROPERTY(bool portsFailed READ portsFailed NOTIFY portsChanged)
    Q_PROPERTY(QStringList sharedFolders READ sharedFolders NOTIFY sharedChanged)
    Q_PROPERTY(QString backupPath READ backupPath CONSTANT)
    Q_PROPERTY(bool backupExists READ backupExists NOTIFY backupChanged)

public:
    explicit TerminalApp(QObject *parent = nullptr);
    ~TerminalApp() override;

    QQmlEngine *engine();
    TerminalWindow *newWindow(const QString &directory = {}, const QStringList &command = {});

    QString fontFamily() const;
    QString effectiveFontFamily() const;
    void setFontFamily(const QString &family);
    int fontSize() const;
    void setFontSize(int size);
    int defaultFontSize() const;
    QStringList fontFamilies() const;

    QVariantList schemes() const;
    QString lightScheme() const;
    void setLightScheme(const QString &id);
    QString darkScheme() const;
    void setDarkScheme(const QString &id);
    bool systemDark() const;
    QString activeScheme() const;
    QColor activeBackground() const;
    QColor activeForeground() const;
    QString schemeDirectory() const;
    Q_INVOKABLE QString importSchemes();

    QVariantList shortcuts() const;
    QKeySequence keys(const QString &id) const;
    Q_INVOKABLE void setShortcutEnabled(const QString &id, bool enabled);
    Q_INVOKABLE void setShortcutKeys(const QString &id, int key, int modifiers);
    Q_INVOKABLE void resetShortcut(const QString &id);
    Q_INVOKABLE QString keyText(int key, int modifiers) const;
    Q_INVOKABLE QString conflictFor(const QString &id, int key, int modifiers) const;

    int memoryLimit() const;
    void setMemoryLimit(int megabytes);
    QVariantList memoryChoices() const;
    Q_INVOKABLE QString memoryLabel(int megabytes) const;
    bool keepAwake() const;
    void setKeepAwake(bool on);
    QStringList shellCommand(const QString &program, const QStringList &arguments) const;

    QVariantList listeningPorts() const;
    QVariantList allowedPorts() const;
    bool portsFailed() const;
    Q_INVOKABLE void setPortAllowed(int port, bool allowed);
    Q_INVOKABLE QString addAllowedPort(const QString &text);
    Q_INVOKABLE void removeAllowedPort(int port);

    QStringList sharedFolders() const;
    Q_INVOKABLE void addSharedFolder();
    Q_INVOKABLE void removeSharedFolder(const QString &folder);

    QString backupPath() const;
    bool backupExists() const;
    Q_INVOKABLE QString resetToInitial(bool backup);
    Q_INVOKABLE QString removeBackup();

    void updateShells();

Q_SIGNALS:
    void appearanceChanged();
    void schemesChanged();
    void shortcutsChanged();
    void advancedChanged();
    void portsChanged();
    void sharedChanged();
    void backupChanged();
    void message(const QString &text);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    struct Shortcut {
        QString id;
        QString title;
        QKeySequence defaults;
        bool listed = true;
    };
    const Shortcut *shortcut(const QString &id) const;
    QString describe(const QKeySequence &sequence) const;
    void applyMemoryLimit() const;
    void applyKeepAwake();
    void syncShared(const QStringList &folders, const QStringList &previous);
    void storeAllowed(const QList<int> &ports);

    KSharedConfigPtr m_config;
    QQmlEngine *m_engine = nullptr;
    ColorSchemes m_schemes;
    PortControl *m_ports;
    QList<Shortcut> m_shortcuts;
    QList<QPointer<TerminalWindow>> m_windows;
    uint m_inhibitCookie = 0;
    bool m_dark = true;
};
