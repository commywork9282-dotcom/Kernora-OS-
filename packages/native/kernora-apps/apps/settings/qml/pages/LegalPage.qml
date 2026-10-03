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

    title: i18n("Legal information")
    subtitle: i18n("Kernora OS is free software, made from the work of many open-source projects. Their authors and licences are listed here.")

    readonly property var components: Licenses.components()
    property var packages: []
    property bool showPackages: false
    readonly property var shownPackages: {
        const query = filter.text.trim().toLowerCase();
        return query.length === 0 ? packages : packages.filter(p => p.package.includes(query));
    }

    Group {
        title: i18n("Kernora OS")

        ListItem {
            title: i18n("Kernora OS")
            subtitle: i18n("The Kernora shell, apps and design: GNU General Public License 2.0 or later")
            icon: "kernora-logo"
            accent: 0
            chevron: true
            onClicked: page.open("LicensePage.qml", { name: "Kernora OS", path: "/usr/share/doc/kernora-desktop/copyright" })
        }
        ListItem {
            title: i18n("GNU General Public License 2.0")
            icon: "text-x-generic"
            iconStyle: "plain"
            chevron: true
            onClicked: page.open("LicensePage.qml", { name: "GNU GPL 2.0", path: "/usr/share/common-licenses/GPL-2" })
        }
    }

    Group {
        title: i18n("Built with")

        Repeater {
            model: page.components
            delegate: ListItem {
                required property var modelData
                title: modelData.name
                subtitle: modelData.licenses.length > 0 ? modelData.description + " · " + modelData.licenses : modelData.description
                icon: "text-x-generic"
                iconStyle: "plain"
                maximumSubtitleLines: 2
                chevron: true
                onClicked: page.open("LicensePage.qml", { name: modelData.name, path: modelData.copyright, homepage: modelData.homepage })
            }
        }
    }

    Group {
        title: i18n("All installed packages")

        ListItem {
            visible: !page.showPackages
            title: i18n("Show every package")
            subtitle: i18n("The copyright file of each of the installed packages")
            icon: "package-x-generic"
            iconStyle: "plain"
            chevron: true
            onClicked: {
                page.packages = Licenses.packages();
                page.showPackages = true;
            }
        }
    }

    SearchField {
        id: filter
        width: parent.width
        visible: page.showPackages
        placeholderText: i18np("Filter %1 package", "Filter %1 packages", page.packages.length)
    }

    ListView {
        width: parent.width
        visible: page.showPackages
        height: Math.min(contentHeight, 560)
        clip: true
        spacing: 2
        model: page.shownPackages
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
        delegate: ListItem {
            required property var modelData
            width: ListView.view.width
            title: modelData.package
            value: modelData.version
            chevron: true
            onClicked: page.open("LicensePage.qml", { name: modelData.package, path: modelData.copyright })
        }
    }
}
