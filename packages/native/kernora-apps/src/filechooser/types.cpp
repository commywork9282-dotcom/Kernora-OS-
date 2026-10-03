// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "types.h"

#include <QDBusMetaType>

QDBusArgument &operator<<(QDBusArgument &argument, const Portal::FilterCondition &value)
{
    argument.beginStructure();
    argument << value.type << value.pattern;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, Portal::FilterCondition &value)
{
    argument.beginStructure();
    argument >> value.type >> value.pattern;
    argument.endStructure();
    return argument;
}

QDBusArgument &operator<<(QDBusArgument &argument, const Portal::Filter &value)
{
    argument.beginStructure();
    argument << value.name << value.conditions;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, Portal::Filter &value)
{
    argument.beginStructure();
    argument >> value.name >> value.conditions;
    argument.endStructure();
    return argument;
}

QDBusArgument &operator<<(QDBusArgument &argument, const Portal::ChoiceOption &value)
{
    argument.beginStructure();
    argument << value.id << value.label;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, Portal::ChoiceOption &value)
{
    argument.beginStructure();
    argument >> value.id >> value.label;
    argument.endStructure();
    return argument;
}

QDBusArgument &operator<<(QDBusArgument &argument, const Portal::Choice &value)
{
    argument.beginStructure();
    argument << value.id << value.label << value.options << value.selected;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, Portal::Choice &value)
{
    argument.beginStructure();
    argument >> value.id >> value.label >> value.options >> value.selected;
    argument.endStructure();
    return argument;
}

QDBusArgument &operator<<(QDBusArgument &argument, const Portal::ChoiceResult &value)
{
    argument.beginStructure();
    argument << value.id << value.value;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, Portal::ChoiceResult &value)
{
    argument.beginStructure();
    argument >> value.id >> value.value;
    argument.endStructure();
    return argument;
}

void Portal::registerTypes()
{
    qDBusRegisterMetaType<FilterCondition>();
    qDBusRegisterMetaType<QList<FilterCondition>>();
    qDBusRegisterMetaType<Filter>();
    qDBusRegisterMetaType<Filters>();
    qDBusRegisterMetaType<ChoiceOption>();
    qDBusRegisterMetaType<QList<ChoiceOption>>();
    qDBusRegisterMetaType<Choice>();
    qDBusRegisterMetaType<Choices>();
    qDBusRegisterMetaType<ChoiceResult>();
    qDBusRegisterMetaType<ChoiceResults>();
}
