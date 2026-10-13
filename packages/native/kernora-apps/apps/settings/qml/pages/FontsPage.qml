/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Fonts")

    ConfigEntry {
        id: interfaceFont
        file: "kdeglobals"
        group: "General"
        key: "font"
        defaultValue: "Google Sans Flex,10.5,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    }
    ConfigEntry {
        id: codeFont
        file: "kdeglobals"
        group: "General"
        key: "fixed"
        defaultValue: "Hack,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    }

    readonly property string family: String(interfaceFont.value).split(",")[0] || "Google Sans Flex"
    readonly property real size: {
        const value = parseFloat(String(interfaceFont.value).split(",")[1]);
        return isNaN(value) ? 10.5 : value;
    }
    readonly property string codeFamily: String(codeFont.value).split(",")[0] || "Hack"
    readonly property real codeSize: {
        const value = parseFloat(String(codeFont.value).split(",")[1]);
        return isNaN(value) ? 10 : value;
    }

    function fontString(family: string, size: real, weight: int): string {
        return family + "," + size + ",-1,5," + weight + ",0,0,0,0,0,0,0,0,0,0,1";
    }

    function notifyChange(): void {
        DBus.emitSignal("session", "/KGlobalSettings", "org.kde.KGlobalSettings", "notifyChange",
                        [{ type: "i", value: 1 }, { type: "i", value: 0 }]);
        DBus.call("session", "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure", [], null);
    }

    function setInterface(family: string, size: real): void {
        const small = size - 1.5;
        Config.write("kdeglobals", "General", "font", fontString(family, size, 400), true);
        Config.write("kdeglobals", "General", "menuFont", fontString(family, size, 400), true);
        Config.write("kdeglobals", "General", "toolBarFont", fontString(family, small, 400), true);
        Config.write("kdeglobals", "General", "smallestReadableFont", fontString(family, small, 400), true);
        Config.write("kdeglobals", "WM", "activeFont", fontString(family, size, 500), true);
        interfaceFont.value = fontString(family, size, 400);
        notifyChange();
    }

    function setCode(family: string, size: real): void {
        Config.write("kdeglobals", "General", "fixed", fontString(family, size, 400), true);
        codeFont.value = fontString(family, size, 400);
        notifyChange();
    }

    Rectangle {
        width: parent.width
        implicitHeight: preview.implicitHeight + 48
        radius: M3.classic ? M3.cornerCard : 28
        color: M3.surfaceContainerHigh

        ColumnLayout {
            id: preview
            anchors.fill: parent
            anchors.margins: 24
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: i18n("The quick brown fox jumps over the lazy dog")
                font.family: page.family
                font.pointSize: page.size * 1.6
                color: M3.surfaceContent
                wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                text: i18n("Menus, buttons and the text in apps use this typeface.")
                font.family: page.family
                font.pointSize: page.size
                color: M3.surfaceVariantContent
                wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                text: "fn main() { println!(\"0O 1lI {}\", 42); }"
                font.family: page.codeFamily
                font.pointSize: page.codeSize
                color: M3.surfaceVariantContent
                elide: Text.ElideRight
            }
        }
    }

    Group {
        title: i18n("Interface")

        ChoiceItem {
            title: i18n("Typeface")
            subtitle: page.family
            icon: "preferences-desktop-font"
            iconStyle: "plain"
            options: Appearance.fontFamilies(false).map(f => ({ value: f, label: f }))
            currentValue: page.family
            onSelected: value => page.setInterface(value, page.size)
        }
        ChoiceItem {
            title: i18n("Size")
            icon: "format-font-size-more"
            iconStyle: "plain"
            options: [9, 9.5, 10, 10.5, 11, 12, 13.5, 15].map(s => ({ value: s, label: i18n("%1 pt", s) }))
            currentValue: page.size
            onSelected: value => page.setInterface(page.family, value)
        }
    }

    Group {
        title: i18n("Code and terminals")

        ChoiceItem {
            title: i18n("Typeface")
            subtitle: page.codeFamily
            icon: "utilities-terminal"
            iconStyle: "plain"
            options: Appearance.fontFamilies(true).map(f => ({ value: f, label: f }))
            currentValue: page.codeFamily
            onSelected: value => page.setCode(value, page.codeSize)
        }
        ChoiceItem {
            title: i18n("Size")
            icon: "format-font-size-more"
            iconStyle: "plain"
            options: [8, 9, 10, 11, 12, 14, 16].map(s => ({ value: s, label: i18n("%1 pt", s) }))
            currentValue: page.codeSize
            onSelected: value => page.setCode(page.codeFamily, value)
        }
    }

    Group {
        ListItem {
            title: i18n("Restore the Kernora fonts")
            icon: "edit-undo"
            iconStyle: "plain"
            visible: page.family !== "Google Sans Flex" || page.size !== 10.5 || page.codeFamily !== "Hack" || page.codeSize !== 10
            onClicked: {
                page.setInterface("Google Sans Flex", 10.5);
                page.setCode("Hack", 10);
            }
        }
    }
}
