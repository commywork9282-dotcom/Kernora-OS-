// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "locales.h"

#include <QCollator>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QKeySequence>
#include <QLocale>
#include <QProcess>
#include <QXmlStreamReader>

#include <KConfigGroup>
#include <KLocalizedString>
#include <KSharedConfig>

#include <functional>

static KSharedConfig::Ptr localeConfig()
{
    return KSharedConfig::openConfig(QStringLiteral("plasma-localerc"));
}

Locales::Locales(QObject *parent)
    : QObject(parent)
{
}

QString Locales::language() const
{
    const KConfigGroup translations(localeConfig(), QStringLiteral("Translations"));
    QString language = translations.readEntry("LANGUAGE", QString()).section(QLatin1Char(':'), 0, 0);
    if (language.isEmpty()) {
        language = QLocale().name().section(QLatin1Char('_'), 0, 0);
        if (language == QLatin1String("C")) {
            language = QStringLiteral("en_US");
        }
    }
    const auto translated = [](const QString &code) {
        return QFile::exists(QStringLiteral("/usr/share/locale/%1/LC_MESSAGES/plasmashell.mo").arg(code));
    };
    if (language != QLatin1String("en_US") && !translated(language) && translated(language.section(QLatin1Char('_'), 0, 0))) {
        language = language.section(QLatin1Char('_'), 0, 0);
    }
    return language;
}

QString Locales::region() const
{
    const KConfigGroup formats(localeConfig(), QStringLiteral("Formats"));
    QString lang = formats.readEntry("LANG", QString());
    if (lang.isEmpty()) {
        lang = qEnvironmentVariable("LANG");
    }
    lang = lang.section(QLatin1Char('.'), 0, 0);
    return lang.isEmpty() || lang == QLatin1String("C") ? QStringLiteral("en_US") : lang;
}

QString Locales::languageName(const QString &code) const
{
    if (code == QLatin1String("en_US") || code == QLatin1String("en")) {
        return QStringLiteral("English (United States)");
    }
    const QLocale locale(code);
    QString name = locale.nativeLanguageName();
    if (code.contains(QLatin1Char('_')) && !locale.nativeTerritoryName().isEmpty()) {
        name += QStringLiteral(" (%1)").arg(locale.nativeTerritoryName());
    }
    return name.isEmpty() ? code : name.left(1).toUpper() + name.mid(1);
}

QString Locales::regionName(const QString &name) const
{
    const QLocale locale(name);
    const QString territory = locale.nativeTerritoryName();
    const QString language = locale.nativeLanguageName();
    if (territory.isEmpty()) {
        return name;
    }
    return QStringLiteral("%1 — %2").arg(territory.left(1).toUpper() + territory.mid(1), language);
}

QVariantList Locales::languages() const
{
    QStringList codes{QStringLiteral("en_US")};
    const QDir locale(QStringLiteral("/usr/share/locale"));
    for (const QString &code : locale.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (QFile::exists(locale.filePath(code + QStringLiteral("/LC_MESSAGES/plasmashell.mo")))) {
            codes.append(code);
        }
    }
    QVariantList list;
    for (const QString &code : std::as_const(codes)) {
        list.append(QVariantMap{{QStringLiteral("code"), code},
                                {QStringLiteral("name"), languageName(code)},
                                {QStringLiteral("englishName"), QLocale::languageToString(QLocale(code).language())}});
    }
    QCollator collator;
    std::sort(list.begin(), list.end(), [&collator](const QVariant &a, const QVariant &b) {
        return collator.compare(a.toMap().value(QStringLiteral("name")).toString(), b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    return list;
}

QVariantList Locales::regions() const
{
    QFile supported(QStringLiteral("/usr/share/i18n/SUPPORTED"));
    QStringList names;
    if (supported.open(QIODevice::ReadOnly)) {
        while (!supported.atEnd()) {
            const QString line = QString::fromLatin1(supported.readLine()).trimmed();
            if (!line.contains(QLatin1String("UTF-8")) || line.contains(QLatin1Char('@'))) {
                continue;
            }
            const QString name = line.section(QLatin1Char('.'), 0, 0).section(QLatin1Char(' '), 0, 0);
            if (name.contains(QLatin1Char('_')) && !names.contains(name)) {
                names.append(name);
            }
        }
    }
    if (names.isEmpty()) {
        names = {QStringLiteral("en_US"), QStringLiteral("ru_RU")};
    }
    QVariantList list;
    for (const QString &name : std::as_const(names)) {
        list.append(QVariantMap{{QStringLiteral("locale"), name}, {QStringLiteral("name"), regionName(name)}});
    }
    QCollator collator;
    std::sort(list.begin(), list.end(), [&collator](const QVariant &a, const QVariant &b) {
        return collator.compare(a.toMap().value(QStringLiteral("name")).toString(), b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    return list;
}

QVariantMap Locales::formatSamples(const QString &name) const
{
    const QLocale locale(name);
    const QDateTime now = QDateTime::currentDateTime();
    return {{QStringLiteral("date"), locale.toString(now.date(), QLocale::LongFormat)},
            {QStringLiteral("time"), locale.toString(now.time(), QLocale::ShortFormat)},
            {QStringLiteral("number"), locale.toString(1234567.89, 'f', 2)},
            {QStringLiteral("currency"), locale.toCurrencyString(1234.5)}};
}

static const QStringList formatCategories = {
    QStringLiteral("LC_NUMERIC"),
    QStringLiteral("LC_TIME"),
    QStringLiteral("LC_MONETARY"),
    QStringLiteral("LC_MEASUREMENT"),
    QStringLiteral("LC_PAPER"),
};

QVariantMap Locales::formats() const
{
    const KConfigGroup formats(localeConfig(), QStringLiteral("Formats"));
    QVariantMap map;
    for (const QString &category : formatCategories) {
        map.insert(category, formats.readEntry(category, QString()).section(QLatin1Char('.'), 0, 0));
    }
    return map;
}

QString Locales::formatSample(const QString &category, const QString &name) const
{
    const QLocale locale(name);
    if (category == QLatin1String("LC_NUMERIC")) {
        return locale.toString(1234567.89, 'f', 2);
    }
    if (category == QLatin1String("LC_TIME")) {
        const QDateTime now = QDateTime::currentDateTime();
        return locale.toString(now.date(), QLocale::ShortFormat) + QStringLiteral(", ") + locale.toString(now.time(), QLocale::ShortFormat);
    }
    if (category == QLatin1String("LC_MONETARY")) {
        return locale.toCurrencyString(1234.5);
    }
    if (category == QLatin1String("LC_MEASUREMENT")) {
        return locale.measurementSystem() == QLocale::MetricSystem ? i18n("Metric: metres, kilograms, °C") : i18n("Imperial: feet, pounds, °F");
    }
    if (category == QLatin1String("LC_PAPER")) {
        static const QStringList letter = {QStringLiteral("BZ"), QStringLiteral("CA"), QStringLiteral("CL"), QStringLiteral("CO"),
                                           QStringLiteral("CR"), QStringLiteral("GT"), QStringLiteral("MX"), QStringLiteral("NI"),
                                           QStringLiteral("PA"), QStringLiteral("PH"), QStringLiteral("PR"), QStringLiteral("SV"),
                                           QStringLiteral("US"), QStringLiteral("VE")};
        return letter.contains(name.section(QLatin1Char('_'), 1, 1).left(2)) ? i18n("Letter") : i18n("A4");
    }
    return {};
}

void Locales::setFormat(const QString &category, const QString &locale)
{
    if (!formatCategories.contains(category)) {
        return;
    }
    const auto write = [this, category, locale]() {
        KConfigGroup formats(localeConfig(), QStringLiteral("Formats"));
        if (locale.isEmpty()) {
            formats.deleteEntry(category, KConfig::Notify);
        } else {
            formats.writeEntry(category, QString(locale + QStringLiteral(".UTF-8")), KConfig::Notify);
        }
        localeConfig()->sync();
        Q_EMIT changed();
        Q_EMIT needsRelogin();
    };
    if (locale.isEmpty()) {
        write();
    } else {
        ensureGenerated(locale, write);
    }
}

QStringList Locales::generatedLocales()
{
    QProcess process;
    process.start(QStringLiteral("locale"), {QStringLiteral("-a")});
    process.waitForFinished(3000);
    QStringList names;
    for (const QString &line : QString::fromLatin1(process.readAllStandardOutput()).split(QLatin1Char('\n'))) {
        names.append(line.section(QLatin1Char('.'), 0, 0));
    }
    return names;
}

void Locales::ensureGenerated(const QString &locale, std::function<void()> then)
{
    if (generatedLocales().contains(locale)) {
        then();
        return;
    }
    if (m_busy) {
        return;
    }
    static const QString service = QStringLiteral("org.kde.localegenhelper");
    static const QString path = QStringLiteral("/LocaleGenHelper");
    static const QString interface = QStringLiteral("org.kde.localegenhelper.LocaleGenHelper");
    if (!m_listening) {
        auto system = QDBusConnection::systemBus();
        system.connect(service, path, interface, QStringLiteral("success"), this, SLOT(onGenerated()));
        system.connect(service, path, interface, QStringLiteral("error"), this, SLOT(onGenerationFailed(QString)));
        m_listening = true;
    }
    m_pending = std::move(then);
    m_busy = true;
    Q_EMIT busyChanged();
    QDBusMessage call = QDBusMessage::createMethodCall(service, path, interface, QStringLiteral("enableLocales"));
    call.setArguments({QStringList{locale + QStringLiteral(".UTF-8")}});
    call.setInteractiveAuthorizationAllowed(true);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(call, 10 * 60 * 1000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *self) {
        self->deleteLater();
        if (self->isError()) {
            onGenerationFailed(self->error().message());
        }
    });
}

void Locales::onGenerated()
{
    if (!m_busy) {
        return;
    }
    m_busy = false;
    Q_EMIT busyChanged();
    if (m_pending) {
        auto then = std::move(m_pending);
        m_pending = nullptr;
        then();
    }
}

void Locales::onGenerationFailed(const QString &message)
{
    if (!m_busy) {
        return;
    }
    m_busy = false;
    m_pending = nullptr;
    Q_EMIT busyChanged();
    Q_EMIT failed(message);
}

void Locales::setLanguage(const QString &code)
{
    const QString locale = code.contains(QLatin1Char('_')) ? code : QLocale(code).name();
    ensureGenerated(locale, [this, code, locale]() {
        KConfigGroup translations(localeConfig(), QStringLiteral("Translations"));
        translations.writeEntry("LANGUAGE", code == QLatin1String("en_US") ? QStringLiteral("en_US") : QString(code + QStringLiteral(":en_US")),
                                KConfig::Notify);
        KConfigGroup formats(localeConfig(), QStringLiteral("Formats"));
        if (!formats.hasKey("LANG")) {
            formats.writeEntry("LANG", QString(locale + QStringLiteral(".UTF-8")), KConfig::Notify);
        }
        localeConfig()->sync();
        Q_EMIT changed();
        Q_EMIT needsRelogin();
    });
}

void Locales::setRegion(const QString &locale)
{
    ensureGenerated(locale, [this, locale]() {
        KConfigGroup formats(localeConfig(), QStringLiteral("Formats"));
        formats.writeEntry("LANG", QString(locale + QStringLiteral(".UTF-8")), KConfig::Notify);
        localeConfig()->sync();
        Q_EMIT changed();
        Q_EMIT needsRelogin();
    });
}

QVariantList Locales::keyboardLayouts() const
{
    if (!m_layoutCache.isEmpty()) {
        return m_layoutCache;
    }
    QFile file(QStringLiteral("/usr/share/X11/xkb/rules/evdev.xml"));
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    QXmlStreamReader xml(&file);
    QString layout;
    QString layoutName;
    bool inVariant = false;
    QString variant;
    QVariantList list;
    QStringList path;
    while (!xml.atEnd()) {
        xml.readNext();
        if (xml.isStartElement()) {
            path.append(xml.name().toString());
            if (xml.name() == QLatin1String("variant")) {
                inVariant = true;
                variant.clear();
            }
        } else if (xml.isEndElement()) {
            if (xml.name() == QLatin1String("variant")) {
                inVariant = false;
            }
            path.removeLast();
        } else if (xml.isCharacters() && !xml.isWhitespace() && path.size() >= 2) {
            const QString element = path.last();
            const QString parent = path.at(path.size() - 2);
            if (parent != QLatin1String("configItem")) {
                continue;
            }
            const QString text = xml.text().toString();
            if (!inVariant && path.contains(QLatin1String("layout")) && !path.contains(QLatin1String("variantList"))) {
                if (element == QLatin1String("name")) {
                    layout = text;
                } else if (element == QLatin1String("description")) {
                    layoutName = text;
                    list.append(QVariantMap{{QStringLiteral("layout"), layout},
                                            {QStringLiteral("variant"), QString()},
                                            {QStringLiteral("name"), i18nd("xkeyboard-config", layoutName.toUtf8().constData())}});
                }
            } else if (inVariant) {
                if (element == QLatin1String("name")) {
                    variant = text;
                } else if (element == QLatin1String("description")) {
                    list.append(QVariantMap{{QStringLiteral("layout"), layout},
                                            {QStringLiteral("variant"), variant},
                                            {QStringLiteral("name"), i18nd("xkeyboard-config", text.toUtf8().constData())}});
                }
            }
        }
    }
    QCollator collator;
    std::sort(list.begin(), list.end(), [&collator](const QVariant &a, const QVariant &b) {
        return collator.compare(a.toMap().value(QStringLiteral("name")).toString(), b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    m_layoutCache = list;
    return list;
}

QVariantList Locales::currentLayouts() const
{
    const KConfigGroup group(KSharedConfig::openConfig(QStringLiteral("kxkbrc")), QStringLiteral("Layout"));
    QStringList layouts = group.readEntry("LayoutList", QString()).split(QLatin1Char(','), Qt::SkipEmptyParts);
    const QStringList variants = group.readEntry("VariantList", QString()).split(QLatin1Char(','));
    if (layouts.isEmpty()) {
        layouts = {QStringLiteral("us")};
    }
    const QVariantList known = keyboardLayouts();
    QVariantList list;
    for (int i = 0; i < layouts.size(); ++i) {
        const QString variant = variants.value(i).trimmed();
        QString name = layouts.at(i);
        for (const QVariant &entry : known) {
            const QVariantMap map = entry.toMap();
            if (map.value(QStringLiteral("layout")) == layouts.at(i) && map.value(QStringLiteral("variant")).toString() == variant) {
                name = map.value(QStringLiteral("name")).toString();
                break;
            }
        }
        list.append(QVariantMap{{QStringLiteral("layout"), layouts.at(i)},
                                {QStringLiteral("variant"), variant},
                                {QStringLiteral("name"), name}});
    }
    return list;
}

void Locales::setLayouts(const QVariantList &layouts)
{
    QStringList names;
    QStringList variants;
    for (const QVariant &entry : layouts) {
        const QVariantMap map = entry.toMap();
        names.append(map.value(QStringLiteral("layout")).toString());
        variants.append(map.value(QStringLiteral("variant")).toString());
    }
    auto config = KSharedConfig::openConfig(QStringLiteral("kxkbrc"));
    KConfigGroup group(config, QStringLiteral("Layout"));
    group.writeEntry("Use", true);
    group.writeEntry("LayoutList", names.join(QLatin1Char(',')));
    group.writeEntry("VariantList", variants.join(QLatin1Char(',')));
    group.writeEntry("DisplayNames", QString(QLatin1Char(',')).repeated(qMax(0, int(names.size()) - 1)));
    config->sync();
    reloadKeyboard();
    Q_EMIT changed();
}

QString Locales::layoutSwitchOption() const
{
    const KConfigGroup group(KSharedConfig::openConfig(QStringLiteral("kxkbrc")), QStringLiteral("Layout"));
    const QStringList options = group.readEntry("Options", QString()).split(QLatin1Char(','), Qt::SkipEmptyParts);
    for (const QString &option : options) {
        if (option.startsWith(QLatin1String("grp:"))) {
            return option;
        }
    }
    return QString();
}

void Locales::setLayoutSwitchOption(const QString &option)
{
    auto config = KSharedConfig::openConfig(QStringLiteral("kxkbrc"));
    KConfigGroup group(config, QStringLiteral("Layout"));
    QStringList options = group.readEntry("Options", QString()).split(QLatin1Char(','), Qt::SkipEmptyParts);
    options.erase(std::remove_if(options.begin(), options.end(), [](const QString &o) { return o.startsWith(QLatin1String("grp:")); }),
                  options.end());
    if (!option.isEmpty()) {
        options.append(option);
    }
    group.writeEntry("Options", options.join(QLatin1Char(',')));
    group.writeEntry("ResetOldOptions", true);
    config->sync();
    reloadKeyboard();
    Q_EMIT keyboardChanged();
}

void Locales::readKeyboardRules() const
{
    if (!m_modelCache.isEmpty()) {
        return;
    }
    QFile file(QStringLiteral("/usr/share/X11/xkb/rules/evdev.xml"));
    if (!file.open(QIODevice::ReadOnly)) {
        return;
    }
    QXmlStreamReader xml(&file);
    QStringList path;
    QString name;
    QString groupName;
    QVariantMap group;
    QVariantList options;
    while (!xml.atEnd()) {
        xml.readNext();
        if (xml.isStartElement()) {
            path.append(xml.name().toString());
            if (xml.name() == QLatin1String("group")) {
                group = {{QStringLiteral("multiple"), xml.attributes().value(QStringLiteral("allowMultipleSelection")) == QLatin1String("true")}};
                options.clear();
            }
        } else if (xml.isEndElement()) {
            if (xml.name() == QLatin1String("group")) {
                group.insert(QStringLiteral("options"), options);
                if (group.value(QStringLiteral("id")).toString() != QLatin1String("grp")) {
                    m_optionGroupCache.append(group);
                }
            }
            path.removeLast();
        } else if (xml.isCharacters() && !xml.isWhitespace() && path.size() >= 2 && path.at(path.size() - 2) == QLatin1String("configItem")) {
            const QString element = path.last();
            const QString text = xml.text().toString();
            const QString owner = path.size() >= 3 ? path.at(path.size() - 3) : QString();
            if (element == QLatin1String("name")) {
                name = text;
            } else if (element == QLatin1String("description")) {
                const QString label = i18nd("xkeyboard-config", text.toUtf8().constData());
                if (owner == QLatin1String("model")) {
                    m_modelCache.append(QVariantMap{{QStringLiteral("id"), name}, {QStringLiteral("name"), label}});
                } else if (owner == QLatin1String("group")) {
                    group.insert(QStringLiteral("id"), name);
                    group.insert(QStringLiteral("name"), label);
                } else if (owner == QLatin1String("option")) {
                    options.append(QVariantMap{{QStringLiteral("id"), name}, {QStringLiteral("name"), label}});
                }
            }
        }
    }
    QCollator collator;
    const auto byName = [&collator](const QVariant &a, const QVariant &b) {
        return collator.compare(a.toMap().value(QStringLiteral("name")).toString(), b.toMap().value(QStringLiteral("name")).toString()) < 0;
    };
    std::sort(m_modelCache.begin(), m_modelCache.end(), byName);
    std::sort(m_optionGroupCache.begin(), m_optionGroupCache.end(), byName);
}

QVariantList Locales::keyboardModels() const
{
    readKeyboardRules();
    return m_modelCache;
}

QVariantList Locales::keyboardOptionGroups() const
{
    readKeyboardRules();
    return m_optionGroupCache;
}

QString Locales::keyboardModel() const
{
    const KConfigGroup group(KSharedConfig::openConfig(QStringLiteral("kxkbrc")), QStringLiteral("Layout"));
    return group.readEntry("Model", QStringLiteral("pc104"));
}

void Locales::setKeyboardModel(const QString &model)
{
    auto config = KSharedConfig::openConfig(QStringLiteral("kxkbrc"));
    KConfigGroup group(config, QStringLiteral("Layout"));
    group.writeEntry("Model", model);
    config->sync();
    reloadKeyboard();
    Q_EMIT keyboardChanged();
}

QStringList Locales::keyboardOptions() const
{
    const KConfigGroup group(KSharedConfig::openConfig(QStringLiteral("kxkbrc")), QStringLiteral("Layout"));
    return group.readEntry("Options", QString()).split(QLatin1Char(','), Qt::SkipEmptyParts);
}

void Locales::writeKeyboardOptions(const QStringList &options)
{
    auto config = KSharedConfig::openConfig(QStringLiteral("kxkbrc"));
    KConfigGroup group(config, QStringLiteral("Layout"));
    group.writeEntry("Options", options.join(QLatin1Char(',')));
    group.writeEntry("ResetOldOptions", true);
    config->sync();
    reloadKeyboard();
    Q_EMIT keyboardChanged();
}

void Locales::setKeyboardOption(const QString &option, bool on)
{
    QStringList options = keyboardOptions();
    options.removeAll(option);
    if (on) {
        options.append(option);
    }
    writeKeyboardOptions(options);
}

void Locales::setKeyboardGroupChoice(const QString &groupId, const QString &option)
{
    readKeyboardRules();
    QStringList members;
    for (const QVariant &entry : std::as_const(m_optionGroupCache)) {
        const QVariantMap group = entry.toMap();
        if (group.value(QStringLiteral("id")).toString() == groupId) {
            for (const QVariant &item : group.value(QStringLiteral("options")).toList()) {
                members.append(item.toMap().value(QStringLiteral("id")).toString());
            }
        }
    }
    QStringList options = keyboardOptions();
    options.erase(std::remove_if(options.begin(), options.end(), [&members](const QString &o) { return members.contains(o); }), options.end());
    if (!option.isEmpty()) {
        options.append(option);
    }
    writeKeyboardOptions(options);
}

void Locales::reloadKeyboard()
{
    QDBusMessage message = QDBusMessage::createSignal(QStringLiteral("/Layouts"), QStringLiteral("org.kde.keyboard"),
                                                      QStringLiteral("reloadConfig"));
    QDBusConnection::sessionBus().send(message);
}

QString Locales::shortcutText(const QVariantList &keys) const
{
    QStringList texts;
    for (const QVariant &key : keys) {
        const int value = key.toInt();
        if (value != 0) {
            texts.append(QKeySequence(value).toString(QKeySequence::NativeText));
        }
    }
    return texts.join(QStringLiteral(", "));
}
