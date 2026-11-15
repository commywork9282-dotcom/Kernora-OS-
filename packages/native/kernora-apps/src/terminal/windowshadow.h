// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QMargins>
#include <QObject>
#include <QPointer>

class KWindowShadow;
class QWindow;

class WindowShadow : public QObject
{
    Q_OBJECT

public:
    explicit WindowShadow(QObject *parent = nullptr);
    ~WindowShadow() override;

    static QMargins padding();
    void attach(QWindow *window);
    void setActive(bool active);
    void setVisible(bool visible);

private:
    void rebuild();

    QPointer<QWindow> m_window;
    KWindowShadow *m_shadow = nullptr;
    bool m_active = true;
    bool m_visible = true;
};
