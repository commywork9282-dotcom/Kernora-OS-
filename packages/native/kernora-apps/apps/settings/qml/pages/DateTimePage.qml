/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Date & time")

    readonly property string service: "org.freedesktop.timedate1"
    readonly property string path: "/org/freedesktop/timedate1"

    property string timezone: ""
    property bool ntp: false
    property bool canNtp: false
    property var zones: []
    property date now: new Date()

    function load(): void {
        DBus.getAllProperties("system", service, path, service, (ok, props) => {
            if (!ok) {
                return;
            }
            page.timezone = props.Timezone || "";
            page.ntp = !!props.NTP;
            page.canNtp = !!props.CanNTP;
        });
    }
    Component.onCompleted: {
        load();
        DBus.call("system", service, path, service, "ListTimezones", [], (ok, result) => {
            if (ok) {
                page.zones = result;
            }
        });
    }
    Timer {
        interval: 1000
        repeat: true
        running: page.visible
        onTriggered: page.now = new Date()
    }

    function zoneLabel(zone: string): string {
        const parts = zone.split("/");
        const city = parts[parts.length - 1].replace(/_/g, " ");
        return parts.length > 1 ? city + " (" + parts.slice(0, -1).join(" / ").replace(/_/g, " ") + ")" : city;
    }

    Rectangle {
        width: parent.width
        implicitHeight: clock.implicitHeight + 48
        radius: M3.classic ? M3.cornerCard : 28
        color: M3.primaryContainer

        ColumnLayout {
            id: clock
            anchors.centerIn: parent
            spacing: 4
            MText {
                Layout.alignment: Qt.AlignHCenter
                role: "displayMedium"
                text: page.now.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
                color: M3.primaryContainerContent
            }
            MText {
                Layout.alignment: Qt.AlignHCenter
                role: "titleMedium"
                text: page.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                color: M3.primaryContainerContent
            }
        }
    }

    Group {
        ListItem {
            title: i18n("Set the time automatically")
            subtitle: i18n("From time servers on the internet")
            visible: page.canNtp
            icon: "preferences-system-time"
            accent: 3
            checkable: true
            checked: page.ntp
            onToggled: on => DBus.call("system", page.service, page.path, page.service, "SetNTP",
                                       [{ type: "b", value: on }, { type: "b", value: true }],
                                       ok => page.load(), true)
        }
        ChoiceItem {
            title: i18n("Time zone")
            icon: "globe"
            accent: 3
            dialogTitle: i18n("Choose a time zone")
            options: page.zones.map(z => ({ value: z, label: page.zoneLabel(z) }))
            currentValue: page.timezone
            subtitle: page.zoneLabel(page.timezone)
            onSelected: value => DBus.call("system", page.service, page.path, page.service, "SetTimezone",
                                           [{ type: "s", value: value }, { type: "b", value: true }],
                                           ok => page.load(), true)
        }
        ListItem {
            title: i18n("Set date and time")
            visible: !page.ntp
            icon: "document-edit"
            iconStyle: "plain"
            chevron: true
            onClicked: setDialog.open()
        }
    }

    Group {
        ListItem {
            title: i18n("Time and date format")
            subtitle: i18n("Follows your region")
            icon: "preferences-desktop-locale"
            iconStyle: "plain"
            chevron: true
            onClicked: page.open("LanguagePage.qml", {})
        }
    }

    Dialog {
        id: setDialog
        title: i18n("Set date and time")
        acceptText: i18n("Set")
        acceptEnabled: !isNaN(parsed.getTime())

        readonly property date parsed: new Date(dateField.text + "T" + timeField.text)

        onOpened: {
            const d = new Date();
            const pad = n => String(n).padStart(2, "0");
            dateField.text = d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
            timeField.text = pad(d.getHours()) + ":" + pad(d.getMinutes());
        }
        onAccepted: {
            const usec = parsed.getTime() * 1000;
            DBus.call("system", page.service, page.path, page.service, "SetTime",
                      [{ type: "x", value: usec }, { type: "b", value: false }, { type: "b", value: true }],
                      ok => { if (!ok) page.notify(i18n("The time could not be set.")); }, true);
        }

        InputField {
            id: dateField
            Layout.fillWidth: true
            label: i18n("Date (YYYY-MM-DD)")
        }
        InputField {
            id: timeField
            Layout.fillWidth: true
            label: i18n("Time (HH:MM)")
        }
    }
}
