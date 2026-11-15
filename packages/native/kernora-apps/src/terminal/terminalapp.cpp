// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "terminalapp.h"
#include "terminalwindow.h"

#include <QFontDatabase>
#include <QQmlEngine>
#include <QSysInfo>
#include <QVariantMap>

#include <pwd.h>
#include <unistd.h>

#include <KConfigGroup>
#include <KLocalizedQmlContext>
#include <KLocalizedString>

static const QString defaultFamily = QStringLiteral("DejaVu Sans Mono");
static constexpr int defaultSize = 10;

TerminalApp::TerminalApp(QObject *parent)
    : QObject(parent)
    , m_config(KSharedConfig::openConfig(QStringLiteral("kernora-terminalrc")))
{
    m_shortcuts = {
        {QStringLiteral("newWindow"), i18nc("@action", "New window"), QKeySequence(QStringLiteral("Ctrl+Shift+N"))},
        {QStringLiteral("newTab"), i18nc("@action", "New tab"), QKeySequence(QStringLiteral("Ctrl+Shift+T"))},
        {QStringLiteral("closeTab"), i18nc("@action", "Close tab"), QKeySequence(QStringLiteral("Ctrl+Shift+W"))},
        {QStringLiteral("nextTab"), i18nc("@action", "Next tab"), QKeySequence(QStringLiteral("Ctrl+Tab"))},
        {QStringLiteral("previousTab"), i18nc("@action", "Previous tab"), QKeySequence(QStringLiteral("Ctrl+Shift+Tab"))},
        {QStringLiteral("copy"), i18nc("@action", "Copy"), QKeySequence(QStringLiteral("Ctrl+Shift+C"))},
        {QStringLiteral("paste"), i18nc("@action", "Paste"), QKeySequence(QStringLiteral("Ctrl+Shift+V"))},
        {QStringLiteral("settings"), i18nc("@action", "Open settings"), QKeySequence(QStringLiteral("Ctrl+Shift+I"))},
        {QStringLiteral("fullScreen"), i18nc("@action", "Full screen"), QKeySequence(Qt::Key_F11)},
        {QStringLiteral("zoomIn"), i18nc("@action", "Increase font size"), QKeySequence(QStringLiteral("Ctrl+="))},
        {QStringLiteral("zoomOut"), i18nc("@action", "Decrease font size"), QKeySequence(QStringLiteral("Ctrl+-"))},
        {QStringLiteral("zoomReset"), i18nc("@action", "Reset font size"), QKeySequence(QStringLiteral("Ctrl+0"))},
    };
}

TerminalApp::~TerminalApp() = default;

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
    window->show();
    window->raise();
    window->activateWindow();
    return window;
}

QString TerminalApp::fontFamily() const
{
    const QString family = m_config->group(QStringLiteral("Appearance")).readEntry("Font", defaultFamily);
    return family.isEmpty() ? defaultFamily : family;
}

void TerminalApp::setFontFamily(const QString &family)
{
    if (family == fontFamily()) {
        return;
    }
    KConfigGroup group = m_config->group(QStringLiteral("Appearance"));
    group.writeEntry("Font", family);
    group.sync();
    Q_EMIT appearanceChanged();
}

int TerminalApp::fontSize() const
{
    return std::clamp(m_config->group(QStringLiteral("Appearance")).readEntry("Size", defaultSize), 6, 40);
}

void TerminalApp::setFontSize(int size)
{
    size = std::clamp(size, 6, 40);
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

bool TerminalApp::lightField() const
{
    return m_config->group(QStringLiteral("Appearance")).readEntry("Field", QStringLiteral("dark")) == QLatin1String("light");
}

void TerminalApp::setLightField(bool light)
{
    if (light == lightField()) {
        return;
    }
    KConfigGroup group = m_config->group(QStringLiteral("Appearance"));
    group.writeEntry("Field", light ? QStringLiteral("light") : QStringLiteral("dark"));
    group.sync();
    Q_EMIT appearanceChanged();
}

QString TerminalApp::cursorShape() const
{
    const QString shape = m_config->group(QStringLiteral("Appearance")).readEntry("Cursor", QStringLiteral("block"));
    return shape == QLatin1String("bar") || shape == QLatin1String("underline") ? shape : QStringLiteral("block");
}

void TerminalApp::setCursorShape(const QString &shape)
{
    if (shape == cursorShape()) {
        return;
    }
    KConfigGroup group = m_config->group(QStringLiteral("Appearance"));
    group.writeEntry("Cursor", shape);
    group.sync();
    Q_EMIT appearanceChanged();
}

QStringList TerminalApp::fontFamilies() const
{
    QStringList result;
    const QStringList families = QFontDatabase::families();
    for (const QString &family : families) {
        if (family.startsWith(QLatin1Char('.')) || family.contains(QLatin1String("CJK")) || !QFontDatabase::isFixedPitch(family)) {
            continue;
        }
        if (QFontDatabase::isPrivateFamily(family)) {
            continue;
        }
        result.append(family);
    }
    if (!result.contains(defaultFamily)) {
        result.prepend(defaultFamily);
    }
    result.removeDuplicates();
    std::sort(result.begin(), result.end(), [](const QString &a, const QString &b) {
        return QString::localeAwareCompare(a, b) < 0;
    });
    return result;
}

QString TerminalApp::prompt() const
{
    QString user = qEnvironmentVariable("USER");
    if (user.isEmpty()) {
        if (const passwd *entry = getpwuid(getuid()); entry && entry->pw_name) {
            user = QString::fromLocal8Bit(entry->pw_name);
        }
    }
    return user + QLatin1Char('@') + QSysInfo::machineHostName();
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
    const KConfigGroup group = m_config->group(QStringLiteral("Shortcuts"));
    if (!group.readEntry(id + QStringLiteral("Enabled"), true)) {
        return {};
    }
    return storedKeys(group, id, item->defaults);
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
    parts << QKeySequence(combination.key()).toString(QKeySequence::NativeText);
    return parts.join(QStringLiteral(" + "));
}

QVariantList TerminalApp::shortcuts() const
{
    QVariantList result;
    const KConfigGroup group = m_config->group(QStringLiteral("Shortcuts"));
    for (const Shortcut &item : m_shortcuts) {
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
    if (!item) {
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
    const KConfigGroup group = m_config->group(QStringLiteral("Shortcuts"));
    for (const Shortcut &item : m_shortcuts) {
        if (item.id != id && group.readEntry(item.id + QStringLiteral("Enabled"), true) && storedKeys(group, item.id, item.defaults) == sequence) {
            return item.title;
        }
    }
    return {};
}
