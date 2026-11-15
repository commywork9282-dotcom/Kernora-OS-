// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QList>
#include <QPointer>
#include <QVariantList>
#include <QWidget>

class QAction;
class QQuickWidget;
class QStackedWidget;
class QTermWidget;
class QTimer;
class TerminalApp;
class WindowShadow;

class TerminalWindow : public QWidget
{
    Q_OBJECT
    Q_PROPERTY(QVariantList tabs READ tabs NOTIFY tabsChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(bool active READ active NOTIFY stateChanged)
    Q_PROPERTY(bool maximized READ maximized NOTIFY stateChanged)
    Q_PROPERTY(bool lightField READ lightField NOTIFY appearanceChanged)
    Q_PROPERTY(QObject *settings READ settings CONSTANT)

public:
    TerminalWindow(TerminalApp *app, const QString &directory, const QStringList &command);
    ~TerminalWindow() override;

    QVariantList tabs() const;
    int currentIndex() const;
    bool active() const;
    bool maximized() const;
    bool lightField() const;
    QObject *settings() const;

    Q_INVOKABLE void newTab();
    Q_INVOKABLE void closeTab(int index);
    Q_INVOKABLE void activateTab(int index);
    Q_INVOKABLE void openSettings();
    Q_INVOKABLE void showWindowMenu(qreal x, qreal y);
    Q_INVOKABLE void showAppMenu(qreal x, qreal y);
    Q_INVOKABLE void minimize();
    Q_INVOKABLE void toggleMaximize();
    Q_INVOKABLE void toggleFullScreen();
    Q_INVOKABLE void startMove();
    Q_INVOKABLE void focusTerminal();

Q_SIGNALS:
    void tabsChanged();
    void currentIndexChanged();
    void stateChanged();
    void appearanceChanged();

private Q_SLOTS:
    void contextRequested(const QPoint &position);

protected:
    bool event(QEvent *event) override;
    bool eventFilter(QObject *watched, QEvent *event) override;
    void changeEvent(QEvent *event) override;
    void showEvent(QShowEvent *event) override;

private:
    struct Tab {
        QWidget *page = nullptr;
        QTermWidget *terminal = nullptr;
        QString title;
    };

    void addTerminal(const QString &directory, const QStringList &command);
    void applyAppearance(QTermWidget *terminal);
    void applyAppearance();
    void rebuildShortcuts();
    void refreshTitles();
    void removeTab(QWidget *page);
    void showTerminalMenu(QTermWidget *terminal, QWidget *display, const QPoint &position);
    void setCurrent(int index);
    void zoom(int step);
    QTermWidget *currentTerminal() const;
    Qt::Edges edgesAt(const QPoint &position) const;
    void setEdgeCursor(Qt::Edges edges);

    TerminalApp *m_app;
    QQuickWidget *m_header;
    QStackedWidget *m_stack;
    QQuickWidget *m_settingsPage = nullptr;
    WindowShadow *m_shadow;
    QTimer *m_titleTimer;
    QList<Tab> m_tabs;
    QList<QAction *> m_actions;
    int m_current = -1;
    int m_zoom = 0;
    Qt::Edges m_cursorEdges;
    bool m_overrideCursor = false;
};
