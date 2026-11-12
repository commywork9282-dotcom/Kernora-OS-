// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMetaType>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

#include <KLocalizedQmlContext>
#include <KLocalizedString>

#include <algorithm>
#include <memory>

struct RemoteMatch {
    QString id;
    QString text;
    QString iconName;
    int categoryRelevance = 0;
    double relevance = 0;
    QVariantMap properties;
};
using RemoteMatches = QList<RemoteMatch>;

struct RemoteAction {
    QString id;
    QString text;
    QString iconName;
};
using RemoteActions = QList<RemoteAction>;

Q_DECLARE_METATYPE(RemoteMatch)
Q_DECLARE_METATYPE(RemoteMatches)
Q_DECLARE_METATYPE(RemoteAction)
Q_DECLARE_METATYPE(RemoteActions)

QDBusArgument &operator<<(QDBusArgument &argument, const RemoteMatch &match)
{
    argument.beginStructure();
    argument << match.id << match.text << match.iconName << match.categoryRelevance << match.relevance << match.properties;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, RemoteMatch &match)
{
    argument.beginStructure();
    argument >> match.id >> match.text >> match.iconName >> match.categoryRelevance >> match.relevance >> match.properties;
    argument.endStructure();
    return argument;
}

QDBusArgument &operator<<(QDBusArgument &argument, const RemoteAction &action)
{
    argument.beginStructure();
    argument << action.id << action.text << action.iconName;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, RemoteAction &action)
{
    argument.beginStructure();
    argument >> action.id >> action.text >> action.iconName;
    argument.endStructure();
    return argument;
}

struct Entry {
    QString title;
    QString section;
    QString category;
    QString page;
    QString icon;
    QString keywords;
    QString subtitle;
};

class Runner : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.krunner1")

public:
    Runner()
    {
        m_idle.setSingleShot(true);
        m_idle.setInterval(5 * 60 * 1000);
        connect(&m_idle, &QTimer::timeout, qApp, &QCoreApplication::quit);
        m_idle.start();
    }

public Q_SLOTS:
    Q_SCRIPTABLE RemoteActions Actions()
    {
        return {};
    }

    Q_SCRIPTABLE RemoteMatches Match(const QString &query)
    {
        m_idle.start();
        load();
        const QStringList words = normalised(query).split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
        if (words.isEmpty()) {
            return {};
        }
        struct Scored {
            int index;
            double score;
        };
        QList<Scored> scored;
        for (int i = 0; i < m_entries.size(); ++i) {
            const Entry &entry = m_entries.at(i);
            const QString title = normalised(entry.title);
            const QString rest = normalised(entry.section + QLatin1Char(' ') + entry.keywords);
            double score = 0;
            bool all = true;
            for (const QString &word : words) {
                if (title.startsWith(word)) {
                    score += 4;
                } else if (title.contains(word)) {
                    score += 3;
                } else if (rest.contains(word)) {
                    score += 1;
                } else {
                    all = false;
                    break;
                }
            }
            if (all) {
                scored.append({i, score - (entry.section.isEmpty() ? 0 : 0.5)});
            }
        }
        std::stable_sort(scored.begin(), scored.end(), [this](const Scored &a, const Scored &b) {
            if (a.score != b.score) {
                return a.score > b.score;
            }
            return m_entries.at(a.index).title.localeAwareCompare(m_entries.at(b.index).title) < 0;
        });
        RemoteMatches matches;
        const double best = 4.0 * words.size();
        for (const Scored &item : std::as_const(scored)) {
            if (matches.size() >= 8) {
                break;
            }
            const Entry &entry = m_entries.at(item.index);
            RemoteMatch match;
            match.id = QString::number(item.index);
            match.text = entry.title;
            match.iconName = entry.icon;
            match.categoryRelevance = normalised(entry.title).startsWith(words.first()) ? 70 : 50;
            match.relevance = std::clamp(item.score / best, 0.05, 1.0);
            match.properties.insert(QStringLiteral("subtext"), entry.subtitle);
            matches.append(match);
        }
        return matches;
    }

    Q_SCRIPTABLE void Run(const QString &matchId, const QString &actionId)
    {
        Q_UNUSED(actionId)
        m_idle.start();
        load();
        bool ok = false;
        const int index = matchId.toInt(&ok);
        if (!ok || index < 0 || index >= m_entries.size()) {
            return;
        }
        const Entry &entry = m_entries.at(index);
        if (entry.page.endsWith(QLatin1String(".desktop"))) {
            QProcess::startDetached(QStringLiteral("gtk-launch"), {entry.page});
            return;
        }
        const QString target = entry.page.isEmpty() ? entry.category : entry.category + QLatin1Char(':') + entry.page;
        QProcess::startDetached(QStringLiteral("kernora-settings"), {target});
    }

    Q_SCRIPTABLE void Teardown()
    {
        m_idle.start();
    }

private:
    static QString normalised(const QString &text)
    {
        QString result = text.toLower().trimmed();
        result.replace(QChar(0x0451), QChar(0x0435));
        return result;
    }

    void load()
    {
        if (m_loaded) {
            return;
        }
        m_loaded = true;
        const QString file = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                                    QStringLiteral("kernora/settings/components/Catalog.qml"));
        if (file.isEmpty()) {
            return;
        }
        m_engine = std::make_unique<QQmlEngine>();
        KLocalization::setupLocalizedContext(m_engine.get());
        QQmlComponent component(m_engine.get(), QUrl::fromLocalFile(file));
        std::unique_ptr<QObject> catalog(component.create());
        if (!catalog) {
            return;
        }
        QHash<QString, QString> subtitles;
        for (const QVariant &value : catalog->property("categories").toList()) {
            const QVariantMap category = value.toMap();
            subtitles.insert(category.value(QStringLiteral("id")).toString(), category.value(QStringLiteral("subtitle")).toString());
        }
        for (const QVariant &value : catalog->property("searchEntries").toList()) {
            const QVariantMap map = value.toMap();
            Entry entry;
            entry.title = map.value(QStringLiteral("title")).toString();
            entry.section = map.value(QStringLiteral("section")).toString();
            entry.category = map.value(QStringLiteral("category")).toString();
            entry.page = map.value(QStringLiteral("page")).toString();
            entry.icon = map.value(QStringLiteral("icon")).toString();
            entry.keywords = map.value(QStringLiteral("keywords")).toString();
            entry.subtitle = entry.section.isEmpty() ? subtitles.value(entry.category) : entry.section;
            if (!entry.title.isEmpty() && !entry.category.isEmpty()) {
                m_entries.append(entry);
            }
        }
    }

    QTimer m_idle;
    bool m_loaded = false;
    std::unique_ptr<QQmlEngine> m_engine;
    QList<Entry> m_entries;
};

int main(int argc, char **argv)
{
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("kernora-settings-runner"));
    KLocalizedString::setApplicationDomain("kernora-settings");

    qDBusRegisterMetaType<RemoteMatch>();
    qDBusRegisterMetaType<RemoteMatches>();
    qDBusRegisterMetaType<RemoteAction>();
    qDBusRegisterMetaType<RemoteActions>();

    Runner runner;
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerObject(QStringLiteral("/runner"), &runner, QDBusConnection::ExportScriptableSlots)) {
        return 1;
    }
    if (!bus.registerService(QStringLiteral("org.kernora.settings.runner"))) {
        return 0;
    }
    return app.exec();
}

#include "main.moc"
