// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QDBusArgument>
#include <QList>
#include <QMetaType>
#include <QString>

namespace Portal
{
struct FilterCondition {
    uint type = 0;
    QString pattern;
};

struct Filter {
    QString name;
    QList<FilterCondition> conditions;
};

struct ChoiceOption {
    QString id;
    QString label;
};

struct Choice {
    QString id;
    QString label;
    QList<ChoiceOption> options;
    QString selected;
};

struct ChoiceResult {
    QString id;
    QString value;
};

using Filters = QList<Filter>;
using Choices = QList<Choice>;
using ChoiceResults = QList<ChoiceResult>;

void registerTypes();
}

Q_DECLARE_METATYPE(Portal::FilterCondition)
Q_DECLARE_METATYPE(Portal::Filter)
Q_DECLARE_METATYPE(Portal::ChoiceOption)
Q_DECLARE_METATYPE(Portal::Choice)
Q_DECLARE_METATYPE(Portal::ChoiceResult)

QDBusArgument &operator<<(QDBusArgument &argument, const Portal::FilterCondition &value);
const QDBusArgument &operator>>(const QDBusArgument &argument, Portal::FilterCondition &value);
QDBusArgument &operator<<(QDBusArgument &argument, const Portal::Filter &value);
const QDBusArgument &operator>>(const QDBusArgument &argument, Portal::Filter &value);
QDBusArgument &operator<<(QDBusArgument &argument, const Portal::ChoiceOption &value);
const QDBusArgument &operator>>(const QDBusArgument &argument, Portal::ChoiceOption &value);
QDBusArgument &operator<<(QDBusArgument &argument, const Portal::Choice &value);
const QDBusArgument &operator>>(const QDBusArgument &argument, Portal::Choice &value);
QDBusArgument &operator<<(QDBusArgument &argument, const Portal::ChoiceResult &value);
const QDBusArgument &operator>>(const QDBusArgument &argument, Portal::ChoiceResult &value);
