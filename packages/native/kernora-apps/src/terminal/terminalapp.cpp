// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "terminalapp.h"
#include "portcontrol.h"
#include "terminalwindow.h"

#include <QApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QFontDatabase>
#include <QLocale>
#include <QPalette>
#include <QProcess>
#include <QQmlEngine>
#include <QStandardPaths>
#include <QVariantMap>

#include <KConfigGroup>
#include <KLocalizedQmlContext>
#include <KLocalizedString>

#include <algorithm>

namespace
{
const QString systemFamily = QStringLiteral("DejaVu Sans Mono");
constexpr int defaultSize = 13;
const QString lightDefault = QStringLiteral("kt-p-standard_light");
const QString darkDefault = QStringLiteral("kt-p-standard_dark");
const QString slice = QStringLiteral("kernora-terminal.slice");
const QStringList shellFiles{QStringLiteral(".bashrc"), QStringLiteral(".profile"), QStringLiteral(".bash_logout")};

bool paletteDark()
{
    return QApplication::palette().color(QPalette::Window).lightness() < 128;
}

qint64 totalMemory()
{
    QFile file(QStringLiteral("/proc/meminfo"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return 0;
    }
    const QList<QByteArray> lines = file.readAll().split('\n');
    for (const QByteArray &line : lines) {
        const QList<QByteArray> fields = line.simplified().split(' ');
        if (fields.size() >= 2 && fields.first() == "MemTotal:") {
            return fields.at(1).toLongLong() / 1024;
        }
    }
    return 0;
}
}

TerminalApp::TerminalApp(QObject *parent)
    : QObject(parent)
    , m_config(KSharedConfig::openConfig(QStringLiteral("kernora-terminalrc"), KConfig::NoGlobals))
    , m_ports(new PortControl(this))
    , m_dark(paletteDark())
{
    m_shortcuts = {
        {QStringLiteral("newWindow"), i18nc("@action", "New window"), QKeySequence(QStringLiteral("Ctrl+Shift+N"))},
        {QStringLiteral("newTab"), i18nc("@action", "New tab"), QKeySequence(QStringLiteral("Ctrl+Shift+T"))},
        {QStringLiteral("closeTab"), i18nc("@action", "Close tab"), QKeySequence(QStringLiteral("Ctrl+Shift+W"))},
        {QStringLiteral("nextTab"), i18nc("@action", "Next tab"), QKeySequence(QStringLiteral("Ctrl+Tab"))},
        {QStringLiteral("previousTab"), i18nc("@action", "Previous tab"), QKeySequence(QStringLiteral("Ctrl+Shift+Tab"))},
        {QStringLiteral("settings"), i18nc("@action", "Open settings"), QKeySequence(QStringLiteral("Ctrl+Shift+I"))},
        {QStringLiteral("zoomIn"), i18nc("@action", "Increase font size"), QKeySequence(QStringLiteral("Ctrl+="))},
        {QStringLiteral("zoomOut"), i18nc("@action", "Decrease font size"), QKeySequence(QStringLiteral("Ctrl+-"))},
        {QStringLiteral("zoomReset"), i18nc("@action", "Reset font size"), QKeySequence(QStringLiteral("Ctrl+0"))},
        {QStringLiteral("copy"), i18nc("@action", "Copy"), QKeySequence(QStringLiteral("Ctrl+Shift+C")), false},
        {QStringLiteral("paste"), i18nc("@action", "Paste"), QKeySequence(QStringLiteral("Ctrl+Shift+V")), false},
        {QStringLiteral("fullScreen"), i18nc("@action", "Full screen"), QKeySequence(Qt::Key_F11), false},
    };

    QList<int> allowed;
    const QStringList stored = m_config->group(QStringLiteral("Ports")).readEntry("Allowed", QStringList());
    for (const QString &port : stored) {
        allowed.append(port.toInt());
    }
    m_ports->setAllowed(allowed);
    connect(m_ports, &PortControl::listeningChanged, this, &TerminalApp::portsChanged);
    connect(m_ports, &PortControl::allowRequested, this, [this](int port) {
        setPortAllowed(port, true);
    });

    qApp->installEventFilter(this);
    applyMemoryLimit();
    applyKeepAwake();
}

TerminalApp::~TerminalApp()
{
    m_ports->release();
    if (m_inhibitCookie) {
        QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.PowerManagement.Inhibit"),
                                                           QStringLiteral("/org/freedesktop/PowerManagement/Inhibit"),
                                                           QStringLiteral("org.freedesktop.PowerManagement.Inhibit"), QStringLiteral("UnInhibit"));
        call << m_inhibitCookie;
        QDBusConnection::sessionBus().call(call, QDBus::NoBlock);
    }
}

QQmlEngine *TerminalApp::engine()
{
    if (!m_engine) {
        m_engine = new QQmlEngine(this);
        KLocalization::setupLocalizedContext(m_engine);
    }
    return m_engine;
}

TerminalWindow *TerminalApp::newWindow(const QString &directory, const QStringList &command)
{
    auto *window = new TerminalWindow(this, directory, command);
    m_windows.append(window);
    connect(window, &TerminalWindow::shellsChanged, this, &TerminalApp::updateShells);
    connect(window, &QObject::destroyed, this, &TerminalApp::updateShells, Qt::QueuedConnection);
    window->show();
    window->raise();
    window->activateWindow();
    updateShells();
    return window;
}

void TerminalApp::updateShells()
{
    QList<int> pids;
    m_windows.removeAll(nullptr);
    for (const QPointer<TerminalWindow> &window : std::as_const(m_windows)) {
        if (window) {
            pids.append(window->shellPids());
        }
    }
    m_ports->setShells(pids);
}

bool TerminalApp::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == qApp && event->type() == QEvent::ApplicationPaletteChange) {
        const bool dark = paletteDark();
        if (dark != m_dark) {
            m_dark = dark;
            Q_EMIT appearanceChanged();
        }
    }
    return false;
}

QString TerminalApp::fontFamily() const
{
    return m_config->group(QStringLiteral("Appearance")).readEntry("Font", QString());
}

QString TerminalApp::effectiveFontFamily() const
{
    const QString family = fontFamily();
    return family.isEmpty() ? systemFamily : family;
}

void TerminalApp::setFontFamily(const QString &family)
{
    if (family == fontFamily()) {
        return;
    }
    KConfigGroup group = m_config->group(QStringLiteral("Appearance"));
    if (family.isEmpty()) {
        group.deleteEntry("Font");
    } else {
        group.writeEntry("Font", family);
    }
    group.sync();
    Q_EMIT appearanceChanged();
}

int TerminalApp::fontSize() const
{
    return std::clamp(m_config->group(QStringLiteral("Appearance")).readEntry("Size", defaultSize), 8, 48);
}

void TerminalApp::setFontSize(int size)
{
    size = std::clamp(size, 8, 48);
    if (size == fontSize()) {
        return;
    }
    KConfigGroup group = m_config->group(QStringLiteral("Appearance"));
    group.writeEntry("Size", size);
    group.sync();
    Q_EMIT appearanceChanged();
}

int TerminalApp::defaultFontSize() const
{
    return defaultSize;
}

QStringList TerminalApp::fontFamilies() const
{
    QStringList result;
    const QStringList families = QFontDatabase::families();
    for (const QString &family : families) {
        if (family.startsWith(QLatin1Char('.')) || family.contains(QLatin1String("CJK")) || !QFontDatabase::isFixedPitch(family)
            || QFontDatabase::isPrivateFamily(family) || family == systemFamily) {
            continue;
        }
        result.append(family);
    }
    result.removeDuplicates();
    std::sort(result.begin(), result.end(), [](const QString &a, const QString &b) {
        return QString::localeAwareCompare(a, b) < 0;
    });
    return result;
}

QVariantList TerminalApp::schemes() const
{
    return m_schemes.list();
}

QString TerminalApp::lightScheme() const
{
    const QString id = m_config->group(QStringLiteral("Appearance")).readEntry("LightScheme", lightDefault);
    return m_schemes.find(id) ? id : lightDefault;
}

void TerminalApp::setLightScheme(const QString &id)
{
    KConfigGroup group = m_config->group(QStringLiteral("Appearance"));
    group.writeEntry("LightScheme", id);
    group.sync();
    Q_EMIT appearanceChanged();
}

QString TerminalApp::darkScheme() const
{
    const QString id = m_config->group(QStringLiteral("Appearance")).readEntry("DarkScheme", darkDefault);
    return m_schemes.find(id) ? id : darkDefault;
}

void TerminalApp::setDarkScheme(const QString &id)
{
    KConfigGroup group = m_config->group(QStringLiteral("Appearance"));
    group.writeEntry("DarkScheme", id);
    group.sync();
    Q_EMIT appearanceChanged();
}

bool TerminalApp::systemDark() const
{
    return m_dark;
}

QString TerminalApp::activeScheme() const
{
    return m_dark ? darkScheme() : lightScheme();
}

QColor TerminalApp::activeBackground() const
{
    const ColorSchemes::Scheme *scheme = m_schemes.find(activeScheme());
    return scheme ? scheme->background : (m_dark ? QColor(Qt::black) : QColor(Qt::white));
}

QColor TerminalApp::activeForeground() const
{
    const ColorSchemes::Scheme *scheme = m_schemes.find(activeScheme());
    return scheme ? scheme->foreground : (m_dark ? QColor(Qt::white) : QColor(0x1f, 0x1f, 0x1f));
}

QString TerminalApp::schemeDirectory() const
{
    return m_schemes.directory();
}

QString TerminalApp::importSchemes()
{
    const QStringList files = QFileDialog::getOpenFileNames(nullptr, i18nc("@title:window", "Color schemes"), QDir::homePath(),
                                                            i18nc("file filter", "Alacritty color schemes (*.toml *.yml *.yaml)"));
    if (files.isEmpty()) {
        return {};
    }
    QString failed;
    const QStringList added = m_schemes.import(files, &failed);
    Q_EMIT schemesChanged();
    if (added.isEmpty()) {
        return i18nc("@info", "“%1” is not a color scheme in Alacritty format.", failed);
    }
    return i18ncp("@info", "Added %2", "Added %1 color schemes", added.size(), added.join(QStringLiteral(", ")));
}

const TerminalApp::Shortcut *TerminalApp::shortcut(const QString &id) const
{
    for (const Shortcut &item : m_shortcuts) {
        if (item.id == id) {
            return &item;
        }
    }
    return nullptr;
}

static QKeySequence storedKeys(const KConfigGroup &group, const QString &id, const QKeySequence &defaults)
{
    const QString stored = group.readEntry(id, QString());
    if (stored.isEmpty()) {
        return defaults;
    }
    const QKeySequence sequence = QKeySequence::fromString(stored, QKeySequence::PortableText);
    return sequence.isEmpty() ? defaults : sequence;
}

QKeySequence TerminalApp::keys(const QString &id) const
{
    const Shortcut *item = shortcut(id);
    if (!item) {
        return {};
    }
    if (!item->listed) {
        return item->defaults;
    }
    const KConfigGroup group = m_config->group(QStringLiteral("Shortcuts"));
    if (!group.readEntry(id + QStringLiteral("Enabled"), true)) {
        return {};
    }
    return storedKeys(group, id, item->defaults);
}

static QString keyName(int key)
{
    switch (key) {
    case Qt::Key_Tab:
        return QStringLiteral("TAB");
    case Qt::Key_Equal:
        return QStringLiteral("EQUALS");
    case Qt::Key_Minus:
        return QStringLiteral("MINUS");
    case Qt::Key_Plus:
        return QStringLiteral("PLUS");
    case Qt::Key_Space:
        return QStringLiteral("SPACE");
    case Qt::Key_Return:
    case Qt::Key_Enter:
        return QStringLiteral("ENTER");
    case Qt::Key_Comma:
        return QStringLiteral("COMMA");
    case Qt::Key_Period:
        return QStringLiteral("PERIOD");
    case Qt::Key_Slash:
        return QStringLiteral("SLASH");
    case Qt::Key_Backslash:
        return QStringLiteral("BACKSLASH");
    case Qt::Key_Semicolon:
        return QStringLiteral("SEMICOLON");
    case Qt::Key_Apostrophe:
        return QStringLiteral("APOSTROPHE");
    case Qt::Key_BracketLeft:
        return QStringLiteral("LEFT_BRACKET");
    case Qt::Key_BracketRight:
        return QStringLiteral("RIGHT_BRACKET");
    case Qt::Key_QuoteLeft:
        return QStringLiteral("GRAVE");
    case Qt::Key_Escape:
        return QStringLiteral("ESCAPE");
    case Qt::Key_Backspace:
        return QStringLiteral("DEL");
    case Qt::Key_Delete:
        return QStringLiteral("FORWARD_DEL");
    case Qt::Key_Insert:
        return QStringLiteral("INSERT");
    case Qt::Key_Home:
        return QStringLiteral("MOVE_HOME");
    case Qt::Key_End:
        return QStringLiteral("MOVE_END");
    case Qt::Key_PageUp:
        return QStringLiteral("PAGE_UP");
    case Qt::Key_PageDown:
        return QStringLiteral("PAGE_DOWN");
    case Qt::Key_Up:
        return QStringLiteral("DPAD_UP");
    case Qt::Key_Down:
        return QStringLiteral("DPAD_DOWN");
    case Qt::Key_Left:
        return QStringLiteral("DPAD_LEFT");
    case Qt::Key_Right:
        return QStringLiteral("DPAD_RIGHT");
    default:
        return QKeySequence(key).toString(QKeySequence::PortableText).toUpper();
    }
}

QString TerminalApp::describe(const QKeySequence &sequence) const
{
    if (sequence.isEmpty()) {
        return {};
    }
    const QKeyCombination combination = sequence[0];
    QStringList parts;
    const Qt::KeyboardModifiers modifiers = combination.keyboardModifiers();
    if (modifiers & Qt::ControlModifier) {
        parts << QStringLiteral("Ctrl");
    }
    if (modifiers & Qt::AltModifier) {
        parts << QStringLiteral("Alt");
    }
    if (modifiers & Qt::ShiftModifier) {
        parts << QStringLiteral("Shift");
    }
    if (modifiers & Qt::MetaModifier) {
        parts << QStringLiteral("Meta");
    }
    parts << keyName(combination.key());
    return parts.join(QStringLiteral(" + "));
}

QVariantList TerminalApp::shortcuts() const
{
    QVariantList result;
    const KConfigGroup group = m_config->group(QStringLiteral("Shortcuts"));
    for (const Shortcut &item : m_shortcuts) {
        if (!item.listed) {
            continue;
        }
        const QKeySequence sequence = storedKeys(group, item.id, item.defaults);
        result.append(QVariantMap{
            {QStringLiteral("id"), item.id},
            {QStringLiteral("title"), item.title},
            {QStringLiteral("keys"), describe(sequence)},
            {QStringLiteral("enabled"), group.readEntry(item.id + QStringLiteral("Enabled"), true)},
            {QStringLiteral("changed"), sequence != item.defaults},
        });
    }
    return result;
}

void TerminalApp::setShortcutEnabled(const QString &id, bool enabled)
{
    if (!shortcut(id)) {
        return;
    }
    KConfigGroup group = m_config->group(QStringLiteral("Shortcuts"));
    if (enabled) {
        group.deleteEntry(id + QStringLiteral("Enabled"));
    } else {
        group.writeEntry(id + QStringLiteral("Enabled"), false);
    }
    group.sync();
    Q_EMIT shortcutsChanged();
}

static QKeySequence combine(int key, int modifiers)
{
    Qt::KeyboardModifiers mods = Qt::KeyboardModifiers(modifiers) & (Qt::ControlModifier | Qt::AltModifier | Qt::ShiftModifier | Qt::MetaModifier);
    if (key == Qt::Key_Backtab) {
        key = Qt::Key_Tab;
        mods |= Qt::ShiftModifier;
    }
    return QKeySequence(QKeyCombination(mods, Qt::Key(key)));
}

void TerminalApp::setShortcutKeys(const QString &id, int key, int modifiers)
{
    const Shortcut *item = shortcut(id);
    if (!item || !item->listed) {
        return;
    }
    const QKeySequence sequence = combine(key, modifiers);
    KConfigGroup group = m_config->group(QStringLiteral("Shortcuts"));
    if (sequence == item->defaults) {
        group.deleteEntry(id);
    } else {
        group.writeEntry(id, sequence.toString(QKeySequence::PortableText));
    }
    group.deleteEntry(id + QStringLiteral("Enabled"));
    group.sync();
    Q_EMIT shortcutsChanged();
}

void TerminalApp::resetShortcut(const QString &id)
{
    KConfigGroup group = m_config->group(QStringLiteral("Shortcuts"));
    group.deleteEntry(id);
    group.deleteEntry(id + QStringLiteral("Enabled"));
    group.sync();
    Q_EMIT shortcutsChanged();
}

QString TerminalApp::keyText(int key, int modifiers) const
{
    return describe(combine(key, modifiers));
}

QString TerminalApp::conflictFor(const QString &id, int key, int modifiers) const
{
    const QKeySequence sequence = combine(key, modifiers);
    for (const Shortcut &item : m_shortcuts) {
        if (item.id != id && keys(item.id) == sequence) {
            return item.title;
        }
    }
    return {};
}

int TerminalApp::memoryLimit() const
{
    return std::max(0, m_config->group(QStringLiteral("Advanced")).readEntry("MemoryLimit", 0));
}

void TerminalApp::setMemoryLimit(int megabytes)
{
    megabytes = std::max(0, megabytes);
    KConfigGroup group = m_config->group(QStringLiteral("Advanced"));
    group.writeEntry("MemoryLimit", megabytes);
    group.sync();
    applyMemoryLimit();
    Q_EMIT advancedChanged();
}

QString TerminalApp::memoryLabel(int megabytes) const
{
    if (megabytes <= 0) {
        return i18nc("@item memory limit", "No limit");
    }
    return i18nc("@item memory size in gigabytes", "%1 GB", QLocale().toString(megabytes / 1024.0, 'f', 1));
}

QVariantList TerminalApp::memoryChoices() const
{
    QVariantList result{QVariantMap{{QStringLiteral("value"), 0}, {QStringLiteral("label"), memoryLabel(0)}}};
    const qint64 total = totalMemory();
    for (int megabytes = 1024; megabytes < total; megabytes *= 2) {
        result.append(QVariantMap{{QStringLiteral("value"), megabytes}, {QStringLiteral("label"), memoryLabel(megabytes)}});
    }
    return result;
}

void TerminalApp::applyMemoryLimit() const
{
    const int limit = memoryLimit();
    const QString value = limit > 0 ? QStringLiteral("%1M").arg(limit) : QStringLiteral("infinity");
    QProcess::startDetached(QStringLiteral("systemctl"), {QStringLiteral("--user"), QStringLiteral("set-property"), QStringLiteral("--runtime"), slice,
                                                          QStringLiteral("MemoryMax=") + value, QStringLiteral("MemorySwapMax=") + (limit > 0 ? QStringLiteral("0") : value)});
}

QStringList TerminalApp::shellCommand(const QString &program, const QStringList &arguments) const
{
    const QString run = QStandardPaths::findExecutable(QStringLiteral("systemd-run"));
    if (run.isEmpty() || qEnvironmentVariableIsSet("KERNORA_TERMINAL_NO_SCOPE")) {
        return QStringList{program} + arguments;
    }
    return QStringList{run, QStringLiteral("--user"), QStringLiteral("--scope"), QStringLiteral("--quiet"), QStringLiteral("--collect"),
                       QStringLiteral("--slice=") + slice, QStringLiteral("--description=") + i18nc("@info systemd unit description", "Terminal tab"),
                       QStringLiteral("--")}
        + QStringList{program} + arguments;
}

bool TerminalApp::keepAwake() const
{
    return m_config->group(QStringLiteral("Advanced")).readEntry("KeepAwake", false);
}

void TerminalApp::setKeepAwake(bool on)
{
    KConfigGroup group = m_config->group(QStringLiteral("Advanced"));
    group.writeEntry("KeepAwake", on);
    group.sync();
    applyKeepAwake();
    Q_EMIT advancedChanged();
}

void TerminalApp::applyKeepAwake()
{
    const QString service = QStringLiteral("org.freedesktop.PowerManagement.Inhibit");
    const QString path = QStringLiteral("/org/freedesktop/PowerManagement/Inhibit");
    if (keepAwake() && !m_inhibitCookie) {
        QDBusMessage call = QDBusMessage::createMethodCall(service, path, service, QStringLiteral("Inhibit"));
        call << QStringLiteral("kernora-terminal") << i18nc("@info sleep inhibition reason", "Terminal keeps the computer awake");
        const QDBusReply<uint> reply = QDBusConnection::sessionBus().call(call);
        if (reply.isValid()) {
            m_inhibitCookie = reply.value();
        }
    } else if (!keepAwake() && m_inhibitCookie) {
        QDBusMessage call = QDBusMessage::createMethodCall(service, path, service, QStringLiteral("UnInhibit"));
        call << m_inhibitCookie;
        QDBusConnection::sessionBus().call(call, QDBus::NoBlock);
        m_inhibitCookie = 0;
    }
}

QVariantList TerminalApp::listeningPorts() const
{
    return m_ports->listening();
}

QVariantList TerminalApp::allowedPorts() const
{
    QVariantList result;
    const QList<int> ports = m_ports->allowed();
    for (const int port : ports) {
        result.append(port);
    }
    return result;
}

bool TerminalApp::portsFailed() const
{
    return m_ports->failed();
}

void TerminalApp::storeAllowed(const QList<int> &ports)
{
    QStringList stored;
    for (const int port : ports) {
        stored.append(QString::number(port));
    }
    KConfigGroup group = m_config->group(QStringLiteral("Ports"));
    group.writeEntry("Allowed", stored);
    group.sync();
    m_ports->setAllowed(ports);
}

void TerminalApp::setPortAllowed(int port, bool allowed)
{
    QList<int> ports = m_ports->allowed();
    if (allowed && !ports.contains(port)) {
        ports.append(port);
    } else if (!allowed) {
        ports.removeAll(port);
    }
    std::sort(ports.begin(), ports.end());
    storeAllowed(ports);
}

QString TerminalApp::addAllowedPort(const QString &text)
{
    bool ok = false;
    const int port = text.trimmed().toInt(&ok);
    if (!ok) {
        return i18nc("@info", "Please enter a number");
    }
    if (port < 1 || port > 65535) {
        return i18nc("@info", "Invalid port number");
    }
    if (m_ports->allowed().contains(port)) {
        return i18nc("@info", "Port already exists");
    }
    setPortAllowed(port, true);
    return {};
}

void TerminalApp::removeAllowedPort(int port)
{
    setPortAllowed(port, false);
}

QStringList TerminalApp::sharedFolders() const
{
    return m_config->group(QStringLiteral("SharedFolders")).readEntry("Folders", QStringList());
}

void TerminalApp::syncShared(const QStringList &folders, const QStringList &previous)
{
    auto *process = new QProcess(this);
    connect(process, &QProcess::finished, this, [this, process, folders, previous](int code, QProcess::ExitStatus status) {
        process->deleteLater();
        if (status != QProcess::NormalExit || code != 0) {
            KConfigGroup group = m_config->group(QStringLiteral("SharedFolders"));
            group.writeEntry("Folders", previous);
            group.sync();
            Q_EMIT sharedChanged();
            Q_EMIT message(i18nc("@info", "The shared folders could not be changed."));
        }
    });
    process->start(QStringLiteral("pkexec"), QStringList{QStringLiteral("/usr/libexec/kernora-terminal-share")} + folders);
    KConfigGroup group = m_config->group(QStringLiteral("SharedFolders"));
    group.writeEntry("Folders", folders);
    group.sync();
    Q_EMIT sharedChanged();
}

void TerminalApp::addSharedFolder()
{
    const QString folder = QFileDialog::getExistingDirectory(nullptr, i18nc("@title:window", "Share a folder"), QDir::homePath());
    if (folder.isEmpty()) {
        return;
    }
    const QStringList previous = sharedFolders();
    if (previous.contains(folder)) {
        return;
    }
    syncShared(previous + QStringList{folder}, previous);
}

void TerminalApp::removeSharedFolder(const QString &folder)
{
    const QStringList previous = sharedFolders();
    QStringList folders = previous;
    folders.removeAll(folder);
    syncShared(folders, previous);
}

QString TerminalApp::backupPath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/kernora-terminal/backup");
}

bool TerminalApp::backupExists() const
{
    return QFileInfo(backupPath()).isDir();
}

QString TerminalApp::resetToInitial(bool backup)
{
    const QString home = QDir::homePath();
    const QString config = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/kernora-terminalrc");
    if (backup) {
        QDir(backupPath()).removeRecursively();
        if (!QDir().mkpath(backupPath())) {
            return i18nc("@info", "Failed to recover due to a backup error");
        }
        for (const QString &name : shellFiles + QStringList{QStringLiteral(".bash_history")}) {
            if (QFile::exists(home + QLatin1Char('/') + name) && !QFile::copy(home + QLatin1Char('/') + name, backupPath() + QLatin1Char('/') + name)) {
                return i18nc("@info", "Failed to recover due to a backup error");
            }
        }
        if (QFile::exists(config) && !QFile::copy(config, backupPath() + QStringLiteral("/kernora-terminalrc"))) {
            return i18nc("@info", "Failed to recover due to a backup error");
        }
        Q_EMIT backupChanged();
    }
    bool ok = true;
    for (const QString &name : shellFiles) {
        const QString target = home + QLatin1Char('/') + name;
        const QString source = QStringLiteral("/etc/skel/") + name;
        QFile::remove(target);
        if (QFile::exists(source)) {
            ok = QFile::copy(source, target) && ok;
        }
    }
    QFile::remove(home + QStringLiteral("/.bash_history"));
    const QStringList previousShared = sharedFolders();
    m_config->markAsClean();
    QFile::remove(config);
    m_config->reparseConfiguration();
    if (!previousShared.isEmpty()) {
        QProcess::startDetached(QStringLiteral("pkexec"), {QStringLiteral("/usr/libexec/kernora-terminal-share")});
    }
    m_ports->setAllowed({});
    applyMemoryLimit();
    applyKeepAwake();
    Q_EMIT appearanceChanged();
    Q_EMIT shortcutsChanged();
    Q_EMIT advancedChanged();
    Q_EMIT portsChanged();
    Q_EMIT sharedChanged();
    return ok ? QString() : i18nc("@info", "Recovery failed");
}

QString TerminalApp::removeBackup()
{
    if (!QDir(backupPath()).removeRecursively()) {
        return i18nc("@info", "Failed to remove backup data");
    }
    Q_EMIT backupChanged();
    return {};
}
