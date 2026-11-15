// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "terminalwindow.h"
#include "terminalapp.h"
#include "windowshadow.h"

#include <QAction>
#include <QApplication>
#include <QCursor>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMenu>
#include <QMetaMethod>
#include <QMouseEvent>
#include <QQuickItem>
#include <QQuickWidget>
#include <QScrollBar>
#include <QStackedWidget>
#include <QStyle>
#include <QStandardPaths>
#include <QTimer>
#include <QVBoxLayout>
#include <QWindow>

#include <KLocalizedString>

#include <qtermwidget.h>

#include <pwd.h>
#include <unistd.h>

namespace
{
constexpr int headerHeight = 40;
constexpr int edge = 6;

QString interfaceFile(const QString &name)
{
    const QString override = qEnvironmentVariable("KERNORA_QML_TERMINAL");
    if (!override.isEmpty()) {
        return QDir(override).filePath(name);
    }
    return QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("kernora/terminal/") + name);
}

QString defaultShell()
{
    const QString shell = qEnvironmentVariable("SHELL");
    if (!shell.isEmpty() && QFileInfo(shell).isExecutable()) {
        return shell;
    }
    if (const passwd *entry = getpwuid(getuid()); entry && entry->pw_shell && *entry->pw_shell) {
        return QString::fromLocal8Bit(entry->pw_shell);
    }
    return QStringLiteral("/bin/bash");
}

QString commandLine(int pid)
{
    QFile file(QStringLiteral("/proc/%1/cmdline").arg(pid));
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    QList<QByteArray> parts = file.readAll().split('\0');
    while (!parts.isEmpty() && parts.last().isEmpty()) {
        parts.removeLast();
    }
    if (parts.isEmpty()) {
        return {};
    }
    QStringList words;
    words << QFileInfo(QString::fromLocal8Bit(parts.first())).fileName();
    for (qsizetype i = 1; i < parts.size(); ++i) {
        words << QString::fromLocal8Bit(parts.at(i));
    }
    return words.join(QLatin1Char(' '));
}

const char *scrollStyle(bool light, bool visible)
{
    if (!visible) {
        return "QScrollBar:vertical { background: transparent; width: 10px; margin: 0; border: none; }"
               "QScrollBar::handle:vertical { background: transparent; border: none; }"
               "QScrollBar::add-line, QScrollBar::sub-line { height: 0; border: none; background: none; }"
               "QScrollBar::add-page, QScrollBar::sub-page { background: transparent; }";
    }
    return light ? "QScrollBar:vertical { background: transparent; width: 10px; margin: 4px 2px 4px 0; border: none; }"
                   "QScrollBar::handle:vertical { background: rgba(0, 0, 0, 0.30); border-radius: 3px; min-height: 32px; margin: 0 1px; border: none; }"
                   "QScrollBar::handle:vertical:hover { background: rgba(0, 0, 0, 0.45); }"
                   "QScrollBar::add-line, QScrollBar::sub-line { height: 0; border: none; background: none; }"
                   "QScrollBar::add-page, QScrollBar::sub-page { background: transparent; }"
                 : "QScrollBar:vertical { background: transparent; width: 10px; margin: 4px 2px 4px 0; border: none; }"
                   "QScrollBar::handle:vertical { background: rgba(255, 255, 255, 0.28); border-radius: 3px; min-height: 32px; margin: 0 1px; border: none; }"
                   "QScrollBar::handle:vertical:hover { background: rgba(255, 255, 255, 0.45); }"
                   "QScrollBar::add-line, QScrollBar::sub-line { height: 0; border: none; background: none; }"
                   "QScrollBar::add-page, QScrollBar::sub-page { background: transparent; }";
}
}

TerminalWindow::TerminalWindow(TerminalApp *app, const QString &directory, const QStringList &command)
    : QWidget(nullptr, Qt::Window | Qt::FramelessWindowHint)
    , m_app(app)
    , m_shadow(new WindowShadow(this))
    , m_titleTimer(new QTimer(this))
{
    setAttribute(Qt::WA_DeleteOnClose);
    setWindowTitle(i18nc("@title:window", "Terminal"));
    setMinimumSize(420, 240);
    resize(920, 580);

    static bool schemesAdded = false;
    if (!schemesAdded) {
        QTermWidget::addCustomColorSchemeDir(app->schemeDirectory());
        schemesAdded = true;
    }

    auto *layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);

    m_header = new QQuickWidget(app->engine(), this);
    m_header->setResizeMode(QQuickWidget::SizeRootObjectToView);
    m_header->setFixedHeight(headerHeight);
    m_header->setFocusPolicy(Qt::NoFocus);
    m_header->setSource(QUrl::fromLocalFile(interfaceFile(QStringLiteral("Header.qml"))));
    if (QQuickItem *root = m_header->rootObject()) {
        root->setProperty("terminal", QVariant::fromValue<QObject *>(this));
    } else {
        qWarning() << "kernora-terminal: the header could not be loaded" << m_header->errors();
    }
    layout->addWidget(m_header);

    m_stack = new QStackedWidget(this);
    m_stack->setAutoFillBackground(true);
    layout->addWidget(m_stack, 1);

    connect(app, &TerminalApp::appearanceChanged, this, qOverload<>(&TerminalWindow::applyAppearance));
    connect(app, &TerminalApp::shortcutsChanged, this, &TerminalWindow::rebuildShortcuts);
    m_titleTimer->setInterval(800);
    connect(m_titleTimer, &QTimer::timeout, this, &TerminalWindow::refreshTitles);
    m_titleTimer->start();

    qApp->installEventFilter(this);
    rebuildShortcuts();
    applyAppearance();
    addTerminal(directory, command);
}

TerminalWindow::~TerminalWindow()
{
    qApp->removeEventFilter(this);
    if (m_overrideCursor) {
        QGuiApplication::restoreOverrideCursor();
    }
}

QVariantList TerminalWindow::tabs() const
{
    QVariantList result;
    for (const Tab &tab : m_tabs) {
        result.append(QVariantMap{{QStringLiteral("title"), tab.title}, {QStringLiteral("settings"), tab.terminal == nullptr}});
    }
    return result;
}

int TerminalWindow::currentIndex() const
{
    return m_current;
}

bool TerminalWindow::active() const
{
    return isActiveWindow();
}

bool TerminalWindow::maximized() const
{
    return isMaximized() || isFullScreen();
}

QColor TerminalWindow::fieldColor() const
{
    return m_app->activeBackground();
}

QColor TerminalWindow::fieldInk() const
{
    return m_app->activeForeground();
}

QList<int> TerminalWindow::shellPids() const
{
    QList<int> result;
    for (const Tab &tab : m_tabs) {
        if (tab.terminal && tab.terminal->getShellPID() > 0) {
            result.append(tab.terminal->getShellPID());
        }
    }
    return result;
}

QObject *TerminalWindow::settings() const
{
    return m_app;
}

void TerminalWindow::addTerminal(const QString &directory, const QStringList &command)
{
    auto *terminal = new QTermWidget(0, m_stack);
    terminal->setEnvironment({QStringLiteral("TERM=xterm-256color"), QStringLiteral("COLORTERM=truecolor")});
    const QStringList launch = command.isEmpty() ? m_app->shellCommand(defaultShell(), {}) : m_app->shellCommand(command.first(), command.mid(1));
    terminal->setShellProgram(launch.first());
    terminal->setArgs(launch.mid(1));
    const QString start = directory.isEmpty() || !QFileInfo(directory).isDir() ? QDir::homePath() : directory;
    terminal->setWorkingDirectory(start);
    terminal->setHistorySize(20000);
    terminal->setScrollBarPosition(QTermWidget::ScrollBarRight);
    terminal->setMargin(4);
    terminal->setBlinkingCursor(false);
    terminal->setFlowControlEnabled(false);
    terminal->setMotionAfterPasting(2);
    terminal->setConfirmMultilinePaste(false);
    terminal->setTerminalSizeHint(false);
    applyAppearance(terminal);

    if (auto *scroll = terminal->findChild<QScrollBar *>()) {
        connect(scroll, &QScrollBar::rangeChanged, terminal, [this, scroll](int, int maximum) {
            scroll->setStyleSheet(QString::fromLatin1(scrollStyle(m_app->activeBackground().lightness() >= 128, maximum > 0)));
        });
    }

    for (QWidget *child : terminal->findChildren<QWidget *>()) {
        if (child->metaObject()->indexOfSignal("configureRequest(QPoint)") >= 0) {
            child->setProperty("kernoraDisplay", true);
            connect(child, SIGNAL(configureRequest(QPoint)), this, SLOT(contextRequested(QPoint)));
        }
    }

    connect(terminal, &QTermWidget::titleChanged, this, &TerminalWindow::refreshTitles);
    connect(terminal, &QTermWidget::urlActivated, this, [](const QUrl &url, bool) {
        QDesktopServices::openUrl(url);
    });
    connect(terminal, &QTermWidget::finished, this, [this, terminal]() {
        QTimer::singleShot(0, this, [this, page = QPointer<QWidget>(terminal)]() {
            if (page) {
                removeTab(page);
            }
        });
    });

    m_stack->addWidget(terminal);
    m_tabs.append({terminal, terminal, i18nc("@title:tab", "Terminal")});
    terminal->startShellProgram();
    Q_EMIT tabsChanged();
    QTimer::singleShot(500, this, &TerminalWindow::shellsChanged);
    setCurrent(m_tabs.size() - 1);
    refreshTitles();
}

void TerminalWindow::applyAppearance(QTermWidget *terminal)
{
    QFont font(m_app->effectiveFontFamily());
    font.setPixelSize(std::clamp(m_app->fontSize() + m_zoom, 8, 64));
    font.setStyleHint(QFont::TypeWriter);
    font.setFixedPitch(true);
    font.setKerning(false);
    terminal->setTerminalFont(font);
    const bool light = m_app->activeBackground().lightness() >= 128;
    terminal->setColorScheme(m_app->activeScheme());
    terminal->setKeyboardCursorShape(QTermWidget::KeyboardCursorShape::BlockCursor);
    if (auto *scroll = terminal->findChild<QScrollBar *>()) {
        scroll->setStyleSheet(QString::fromLatin1(scrollStyle(light, scroll->maximum() > 0)));
    }
}

void TerminalWindow::applyAppearance()
{
    QPalette palette = m_stack->palette();
    palette.setColor(QPalette::Window, m_app->activeBackground());
    m_stack->setPalette(palette);
    for (const Tab &tab : std::as_const(m_tabs)) {
        if (tab.terminal) {
            applyAppearance(tab.terminal);
        }
    }
    Q_EMIT appearanceChanged();
}

void TerminalWindow::zoom(int step)
{
    m_zoom = step == 0 ? 0 : std::clamp(m_zoom + step, 8 - m_app->fontSize(), 64 - m_app->fontSize());
    for (const Tab &tab : std::as_const(m_tabs)) {
        if (tab.terminal) {
            applyAppearance(tab.terminal);
        }
    }
}

void TerminalWindow::rebuildShortcuts()
{
    qDeleteAll(m_actions);
    m_actions.clear();
    const auto add = [this](const QString &id, const QString &text, const QString &icon, auto handler) {
        auto *action = new QAction(QIcon::fromTheme(icon), text, this);
        action->setObjectName(id);
        action->setShortcut(m_app->keys(id));
        action->setShortcutContext(Qt::WindowShortcut);
        connect(action, &QAction::triggered, this, handler);
        addAction(action);
        m_actions.append(action);
    };
    add(QStringLiteral("newWindow"), i18nc("@action", "New window"), QStringLiteral("window-new"), [this]() {
        QTermWidget *terminal = currentTerminal();
        m_app->newWindow(terminal ? terminal->workingDirectory() : QString());
    });
    add(QStringLiteral("newTab"), i18nc("@action", "New tab"), QStringLiteral("list-add"), [this]() { newTab(); });
    add(QStringLiteral("closeTab"), i18nc("@action", "Close tab"), QStringLiteral("window-close"), [this]() { closeTab(m_current); });
    add(QStringLiteral("nextTab"), i18nc("@action", "Next tab"), QString(), [this]() {
        if (!m_tabs.isEmpty()) {
            setCurrent((m_current + 1) % m_tabs.size());
        }
    });
    add(QStringLiteral("previousTab"), i18nc("@action", "Previous tab"), QString(), [this]() {
        if (!m_tabs.isEmpty()) {
            setCurrent((m_current - 1 + m_tabs.size()) % m_tabs.size());
        }
    });
    add(QStringLiteral("copy"), i18nc("@action", "Copy"), QStringLiteral("edit-copy"), [this]() {
        if (QTermWidget *terminal = currentTerminal()) {
            terminal->copyClipboard();
        }
    });
    add(QStringLiteral("paste"), i18nc("@action", "Paste"), QStringLiteral("edit-paste"), [this]() {
        if (QTermWidget *terminal = currentTerminal()) {
            terminal->pasteClipboard();
        }
    });
    add(QStringLiteral("settings"), i18nc("@action", "Settings"), QStringLiteral("configure"), [this]() { openSettings(); });
    add(QStringLiteral("fullScreen"), i18nc("@action", "Full screen"), QStringLiteral("view-fullscreen"), [this]() { toggleFullScreen(); });
    add(QStringLiteral("zoomIn"), i18nc("@action", "Increase font size"), QStringLiteral("zoom-in"), [this]() { zoom(1); });
    add(QStringLiteral("zoomOut"), i18nc("@action", "Decrease font size"), QStringLiteral("zoom-out"), [this]() { zoom(-1); });
    add(QStringLiteral("zoomReset"), i18nc("@action", "Reset font size"), QStringLiteral("zoom-original"), [this]() { zoom(0); });
}

static QAction *findAction(const QList<QAction *> &actions, const QString &id)
{
    for (QAction *action : actions) {
        if (action->objectName() == id) {
            return action;
        }
    }
    return nullptr;
}

void TerminalWindow::refreshTitles()
{
    bool changed = false;
    for (Tab &tab : m_tabs) {
        QString title;
        if (!tab.terminal) {
            title = i18nc("@title:tab", "Settings");
        } else {
            const int shell = tab.terminal->getShellPID();
            const int foreground = tab.terminal->getForegroundProcessId();
            if (foreground > 0 && shell > 0 && foreground != shell) {
                title = commandLine(foreground);
            }
            if (title.isEmpty()) {
                title = tab.terminal->title();
                if (title == QLatin1String("QTermWidget")) {
                    title.clear();
                }
            }
            if (title.isEmpty()) {
                title = i18nc("@title:tab", "Terminal");
            }
        }
        if (title != tab.title) {
            tab.title = title;
            changed = true;
        }
    }
    if (changed) {
        Q_EMIT tabsChanged();
    }
    const QString current = m_current >= 0 && m_current < m_tabs.size() ? m_tabs.at(m_current).title : QString();
    setWindowTitle(current.isEmpty() ? i18nc("@title:window", "Terminal") : current);
}

void TerminalWindow::setCurrent(int index)
{
    if (index < 0 || index >= m_tabs.size()) {
        return;
    }
    m_current = index;
    m_stack->setCurrentWidget(m_tabs.at(index).page);
    Q_EMIT currentIndexChanged();
    refreshTitles();
    focusTerminal();
}

QTermWidget *TerminalWindow::currentTerminal() const
{
    return m_current >= 0 && m_current < m_tabs.size() ? m_tabs.at(m_current).terminal : nullptr;
}

void TerminalWindow::focusTerminal()
{
    if (m_current < 0 || m_current >= m_tabs.size()) {
        return;
    }
    if (QWidget *page = m_tabs.at(m_current).page) {
        page->setFocus(Qt::OtherFocusReason);
    }
}

void TerminalWindow::newTab()
{
    QTermWidget *terminal = currentTerminal();
    QString directory = terminal ? terminal->workingDirectory() : QString();
    if (!terminal) {
        for (const Tab &tab : std::as_const(m_tabs)) {
            if (tab.terminal) {
                directory = tab.terminal->workingDirectory();
            }
        }
    }
    addTerminal(directory, {});
}

void TerminalWindow::closeTab(int index)
{
    if (index < 0 || index >= m_tabs.size()) {
        return;
    }
    removeTab(m_tabs.at(index).page);
}

void TerminalWindow::removeTab(QWidget *page)
{
    qsizetype index = -1;
    for (qsizetype i = 0; i < m_tabs.size(); ++i) {
        if (m_tabs.at(i).page == page) {
            index = i;
            break;
        }
    }
    if (index < 0) {
        return;
    }
    const bool wasCurrent = index == m_current;
    m_tabs.removeAt(index);
    if (page == m_settingsPage) {
        m_settingsPage = nullptr;
    }
    m_stack->removeWidget(page);
    page->deleteLater();
    Q_EMIT shellsChanged();
    if (m_tabs.isEmpty()) {
        m_current = -1;
        close();
        return;
    }
    if (wasCurrent) {
        m_current = std::min<int>(index, m_tabs.size() - 1);
    } else if (index < m_current) {
        --m_current;
    }
    Q_EMIT tabsChanged();
    setCurrent(m_current);
}

void TerminalWindow::activateTab(int index)
{
    setCurrent(index);
}

void TerminalWindow::openSettings()
{
    if (m_settingsPage) {
        for (qsizetype i = 0; i < m_tabs.size(); ++i) {
            if (m_tabs.at(i).page == m_settingsPage) {
                setCurrent(i);
                return;
            }
        }
    }
    m_settingsPage = new QQuickWidget(m_app->engine(), m_stack);
    m_settingsPage->setResizeMode(QQuickWidget::SizeRootObjectToView);
    m_settingsPage->setFocusPolicy(Qt::StrongFocus);
    m_settingsPage->setSource(QUrl::fromLocalFile(interfaceFile(QStringLiteral("Settings.qml"))));
    if (QQuickItem *root = m_settingsPage->rootObject()) {
        root->setProperty("terminal", QVariant::fromValue<QObject *>(this));
    } else {
        qWarning() << "kernora-terminal: settings could not be loaded" << m_settingsPage->errors();
    }
    m_stack->addWidget(m_settingsPage);
    m_tabs.append({m_settingsPage, nullptr, i18nc("@title:tab", "Settings")});
    Q_EMIT tabsChanged();
    setCurrent(m_tabs.size() - 1);
}

void TerminalWindow::showWindowMenu(qreal x, qreal y)
{
    auto *menu = new QMenu(this);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    menu->addAction(findAction(m_actions, QStringLiteral("newWindow")));
    menu->addSeparator();
    menu->addAction(QIcon::fromTheme(QStringLiteral("list-remove")), i18nc("@action", "Minimize"), this, &TerminalWindow::minimize);
    menu->addAction(QIcon::fromTheme(isMaximized() ? QStringLiteral("window-restore") : QStringLiteral("window-maximize")),
                    isMaximized() ? i18nc("@action", "Restore") : i18nc("@action", "Maximize"), this, &TerminalWindow::toggleMaximize);
    QAction *full = findAction(m_actions, QStringLiteral("fullScreen"));
    full->setCheckable(true);
    full->setChecked(isFullScreen());
    menu->addAction(full);
    menu->addSeparator();
    menu->addAction(QIcon::fromTheme(QStringLiteral("window-close")), i18nc("@action", "Close window"), this, &QWidget::close);
    connect(menu, &QMenu::aboutToHide, this, [this, full]() {
        full->setCheckable(false);
        QTimer::singleShot(0, this, &TerminalWindow::focusTerminal);
    });
    menu->popup(m_header->mapToGlobal(QPoint(qRound(x), qRound(y))));
}

void TerminalWindow::showAppMenu(qreal x, qreal y)
{
    auto *menu = new QMenu(this);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    QAction *tab = findAction(m_actions, QStringLiteral("newTab"));
    menu->addAction(tab);
    QAction *window = findAction(m_actions, QStringLiteral("newWindow"));
    menu->addAction(window);
    menu->addSeparator();
    menu->addAction(findAction(m_actions, QStringLiteral("settings")));
    connect(menu, &QMenu::aboutToHide, this, [this]() {
        QTimer::singleShot(0, this, &TerminalWindow::focusTerminal);
    });
    const QPoint anchor = m_header->mapToGlobal(QPoint(qRound(x), qRound(y)));
    const QList<int> shadow = menu->style()->property("menu_shadow").value<QList<int>>();
    const int sides = shadow.size() == 4 ? shadow.at(0) + shadow.at(2) : 0;
    menu->popup(anchor - QPoint(menu->sizeHint().width() - sides, 0));
}

void TerminalWindow::contextRequested(const QPoint &position)
{
    auto *display = qobject_cast<QWidget *>(sender());
    auto *terminal = display ? qobject_cast<QTermWidget *>(display->parentWidget()) : nullptr;
    if (terminal) {
        showTerminalMenu(terminal, display, position);
    }
}

void TerminalWindow::showTerminalMenu(QTermWidget *terminal, QWidget *display, const QPoint &position)
{
    auto *menu = new QMenu(this);
    menu->setAttribute(Qt::WA_DeleteOnClose);
    const QList<QAction *> links = terminal->filterActions(position);
    for (QAction *link : links) {
        menu->addAction(link);
    }
    if (!links.isEmpty()) {
        menu->addSeparator();
    }
    QAction *copy = findAction(m_actions, QStringLiteral("copy"));
    copy->setEnabled(!terminal->selectedText().isEmpty());
    menu->addAction(copy);
    QAction *paste = findAction(m_actions, QStringLiteral("paste"));
    menu->addAction(paste);
    menu->addSeparator();
    menu->addAction(findAction(m_actions, QStringLiteral("newTab")));
    menu->addAction(findAction(m_actions, QStringLiteral("settings")));
    connect(menu, &QMenu::aboutToHide, this, [this, copy]() {
        QTimer::singleShot(0, this, [this, copy]() {
            copy->setEnabled(true);
            focusTerminal();
        });
    });
    menu->popup(display->mapToGlobal(position));
}

void TerminalWindow::minimize()
{
    showMinimized();
}

void TerminalWindow::toggleMaximize()
{
    if (isFullScreen()) {
        showNormal();
        return;
    }
    isMaximized() ? showNormal() : showMaximized();
}

void TerminalWindow::toggleFullScreen()
{
    isFullScreen() ? showNormal() : showFullScreen();
}

void TerminalWindow::startMove()
{
    if (QWindow *handle = windowHandle()) {
        handle->startSystemMove();
    }
}

Qt::Edges TerminalWindow::edgesAt(const QPoint &position) const
{
    Qt::Edges edges;
    if (isMaximized() || isFullScreen()) {
        return edges;
    }
    if (position.x() < edge) {
        edges |= Qt::LeftEdge;
    } else if (position.x() >= width() - edge) {
        edges |= Qt::RightEdge;
    }
    if (position.y() < 4) {
        edges |= Qt::TopEdge;
    } else if (position.y() >= height() - edge) {
        edges |= Qt::BottomEdge;
    }
    return edges;
}

void TerminalWindow::setEdgeCursor(Qt::Edges edges)
{
    if (edges == m_cursorEdges) {
        return;
    }
    m_cursorEdges = edges;
    if (m_overrideCursor) {
        QGuiApplication::restoreOverrideCursor();
        m_overrideCursor = false;
    }
    if (!edges) {
        return;
    }
    Qt::CursorShape shape = Qt::SizeAllCursor;
    if ((edges & Qt::LeftEdge && edges & Qt::TopEdge) || (edges & Qt::RightEdge && edges & Qt::BottomEdge)) {
        shape = Qt::SizeFDiagCursor;
    } else if ((edges & Qt::RightEdge && edges & Qt::TopEdge) || (edges & Qt::LeftEdge && edges & Qt::BottomEdge)) {
        shape = Qt::SizeBDiagCursor;
    } else if (edges & (Qt::LeftEdge | Qt::RightEdge)) {
        shape = Qt::SizeHorCursor;
    } else {
        shape = Qt::SizeVerCursor;
    }
    QGuiApplication::setOverrideCursor(QCursor(shape));
    m_overrideCursor = true;
}

bool TerminalWindow::eventFilter(QObject *watched, QEvent *event)
{
    auto *widget = qobject_cast<QWidget *>(watched);
    if (!widget || widget->window() != this) {
        return false;
    }
    switch (event->type()) {
    case QEvent::MouseMove: {
        auto *mouse = static_cast<QMouseEvent *>(event);
        if (mouse->buttons() == Qt::NoButton) {
            setEdgeCursor(edgesAt(mapFromGlobal(mouse->globalPosition().toPoint())));
        }
        break;
    }
    case QEvent::MouseButtonPress: {
        auto *mouse = static_cast<QMouseEvent *>(event);
        const QPoint local = mapFromGlobal(mouse->globalPosition().toPoint());
        const Qt::Edges edges = edgesAt(local);
        if (mouse->button() == Qt::LeftButton && edges && windowHandle()) {
            setEdgeCursor({});
            windowHandle()->startSystemResize(edges);
            return true;
        }
        break;
    }
    case QEvent::Leave:
        if (widget == this) {
            setEdgeCursor({});
        }
        break;
    default:
        break;
    }
    return false;
}

bool TerminalWindow::event(QEvent *event)
{
    if (event->type() == QEvent::WindowActivate || event->type() == QEvent::WindowDeactivate) {
        m_shadow->setActive(isActiveWindow());
        Q_EMIT stateChanged();
    }
    return QWidget::event(event);
}

void TerminalWindow::changeEvent(QEvent *event)
{
    if (event->type() == QEvent::WindowStateChange) {
        m_shadow->setVisible(!(isMaximized() || isFullScreen()));
        setEdgeCursor({});
        Q_EMIT stateChanged();
    }
    QWidget::changeEvent(event);
}

void TerminalWindow::showEvent(QShowEvent *event)
{
    QWidget::showEvent(event);
    QTimer::singleShot(0, this, [this]() {
        m_shadow->attach(windowHandle());
    });
    focusTerminal();
}
