/*
    SPDX-FileCopyrightText: 2014 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2015 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.iconthemes as KIconThemes
import org.kde.config
import org.kde.kirigami as Kirigami
import org.kernora.m3
import org.kernora.ui as UI

Item {
    id: configIcons

    property bool isPopup: (Plasmoid.location !== PlasmaCore.Types.Floating)

    property string cfg_icon: Plasmoid.configuration.icon
    property bool cfg_useCustomIcon
    property int cfg_arrangement
    property int cfg_alignment
    property bool cfg_locked
    property int cfg_sortMode
    property bool cfg_sortDesc
    property bool cfg_sortDirsFirst
    property bool cfg_toolTips
    property bool cfg_selectionMarkers
    property bool cfg_renameInline
    property bool cfg_popups
    property bool cfg_previews
    property var cfg_previewPlugins
    property int cfg_viewMode
    property int cfg_iconSize
    property int cfg_labelWidth
    property int cfg_textLines

    readonly property bool lockedByKiosk: !KAuthorized.authorize("editable_desktop_icons")
    readonly property bool iconsMode: !isPopup || cfg_viewMode === 1

    implicitHeight: content.implicitHeight + 24

    function tr(text: string): string {
        return i18nd("kernora-ui", text);
    }
    function plain(text: string): string {
        return text.replace(/\s*[:：]\s*$/, "");
    }

    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: cfg_icon = iconName || "folder-symbolic";
    }

    ColumnLayout {
        id: content
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 20

        UI.Group {
            Layout.fillWidth: true
            visible: configIcons.isPopup
            title: configIcons.plain(i18n("Panel button:"))

            UI.ListItem {
                title: i18n("Use a custom icon")
                checkable: true
                checked: configIcons.cfg_useCustomIcon
                onToggled: checked => configIcons.cfg_useCustomIcon = checked
            }
            UI.ListItem {
                enabled: configIcons.cfg_useCustomIcon
                icon: configIcons.cfg_icon
                title: i18nc("@item:inmenu Open icon chooser dialog", "Choose…")
                onClicked: iconDialog.open()
                trailing: Component {
                    UI.IconButton {
                        iconName: "edit-clear"
                        text: i18nc("@item:inmenu Reset icon to default", "Clear Icon")
                        onClicked: configIcons.cfg_icon = "folder-symbolic"
                    }
                }
            }
        }

        UI.Group {
            Layout.fillWidth: true
            title: configIcons.tr("Placement")

            UI.ChoiceItem {
                visible: configIcons.iconsMode
                title: configIcons.plain(i18n("Arrangement:"))
                options: [
                    { value: 0, label: Qt.application.layoutDirection === Qt.LeftToRight
                        ? i18nc("@item:inlistbox arrangement of icons", "Left to Right")
                        : i18nc("@item:inlistbox arrangement of icons", "Right to Left") },
                    { value: 1, label: i18nc("@item:inlistbox arrangement of icons", "Top to Bottom") },
                ]
                currentValue: configIcons.cfg_arrangement
                onSelected: value => configIcons.cfg_arrangement = value
            }
            UI.ChoiceItem {
                visible: configIcons.iconsMode
                title: configIcons.tr("Alignment")
                options: [
                    { value: 0, label: i18nc("@item:inlistbox alignment of icons", "Align left") },
                    { value: 1, label: i18nc("@item:inlistbox alignment of icons", "Align right") },
                ]
                currentValue: configIcons.cfg_alignment
                onSelected: value => configIcons.cfg_alignment = value
            }
            UI.ListItem {
                visible: ("containmentType" in plasmoid)
                title: i18n("Lock in place")
                checkable: true
                checked: configIcons.cfg_locked || configIcons.lockedByKiosk
                enabled: !configIcons.lockedByKiosk
                onToggled: checked => {
                    if (!configIcons.lockedByKiosk) {
                        configIcons.cfg_locked = checked;
                    }
                }
            }
        }

        UI.Group {
            Layout.fillWidth: true
            title: configIcons.plain(i18n("Sorting:"))

            UI.ChoiceItem {
                title: configIcons.tr("Sort by")
                options: [
                    { value: -1, label: i18nc("@item:inlistbox sort icons manually", "Manual") },
                    { value: 0, label: i18nc("@item:inlistbox sort icons by name", "Name") },
                    { value: 1, label: i18nc("@item:inlistbox sort icons by size", "Size") },
                    { value: 6, label: i18nc("@item:inlistbox sort icons by file type", "Type") },
                    { value: 2, label: i18nc("@item:inlistbox sort icons by date", "Date") },
                ]
                currentValue: configIcons.cfg_sortMode
                onSelected: value => configIcons.cfg_sortMode = value
            }
            UI.ListItem {
                enabled: configIcons.cfg_sortMode !== -1
                title: i18nc("@option:check sort icons in descending order", "Descending")
                checkable: true
                checked: configIcons.cfg_sortDesc
                onToggled: checked => configIcons.cfg_sortDesc = checked
            }
            UI.ListItem {
                enabled: configIcons.cfg_sortMode !== -1
                title: i18nc("@option:check sort icons with folders first", "Folders first")
                checkable: true
                checked: configIcons.cfg_sortDirsFirst
                onToggled: checked => configIcons.cfg_sortDirsFirst = checked
            }
        }

        UI.Group {
            Layout.fillWidth: true
            title: configIcons.tr("Appearance")

            UI.ChoiceItem {
                visible: configIcons.isPopup
                title: configIcons.plain(i18nc("whether to use icon or list view", "View mode:"))
                options: [
                    { value: 0, label: i18nc("@item:inlistbox show icons in a list", "List") },
                    { value: 1, label: i18nc("@item:inlistbox show icons in a grid", "Grid") },
                ]
                currentValue: configIcons.cfg_viewMode
                onSelected: value => configIcons.cfg_viewMode = value
            }
            UI.SliderItem {
                visible: configIcons.iconsMode
                title: configIcons.plain(i18n("Icon size:"))
                from: 0
                to: 6
                stepSize: 1
                value: configIcons.cfg_iconSize
                formatValue: v => {
                    const units = Kirigami.Units.iconSizes;
                    const sizes = [units.smallMedium, units.medium, units.large, units.huge,
                                   units.large * 2, units.enormous, units.enormous * 2];
                    return configIcons.tr("%1 px").arg(sizes[Math.round(v)]);
                }
                onMoved: value => configIcons.cfg_iconSize = Math.round(value)
            }
            UI.ChoiceItem {
                visible: configIcons.iconsMode
                title: configIcons.plain(i18n("Label width:"))
                options: [
                    { value: 0, label: i18nc("@item:inlistbox how long a text label should be", "Narrow") },
                    { value: 1, label: i18nc("@item:inlistbox how long a text label should be", "Medium") },
                    { value: 2, label: i18nc("@item:inlistbox how long a text label should be", "Wide") },
                ]
                currentValue: configIcons.cfg_labelWidth
                onSelected: value => configIcons.cfg_labelWidth = value
            }
            UI.SliderItem {
                visible: configIcons.iconsMode
                title: configIcons.plain(i18n("Text lines:"))
                from: 1
                to: 10
                stepSize: 1
                value: configIcons.cfg_textLines
                formatValue: v => String(Math.round(v))
                onMoved: value => configIcons.cfg_textLines = Math.round(value)
            }
        }

        UI.Group {
            Layout.fillWidth: true
            title: configIcons.plain(i18n("When hovering over icons:"))

            UI.ListItem {
                title: i18n("Show tooltips")
                checkable: true
                checked: configIcons.cfg_toolTips
                onToggled: checked => configIcons.cfg_toolTips = checked
            }
            UI.ListItem {
                visible: Qt.styleHints.singleClickActivation
                title: i18n("Show selection markers")
                checkable: true
                checked: configIcons.cfg_selectionMarkers
                onToggled: checked => configIcons.cfg_selectionMarkers = checked
            }
            UI.ListItem {
                visible: !configIcons.isPopup
                title: i18n("Show folder preview popups")
                checkable: true
                checked: configIcons.cfg_popups
                onToggled: checked => configIcons.cfg_popups = checked
            }
        }

        UI.Group {
            Layout.fillWidth: true
            visible: !Qt.styleHints.singleClickActivation
            title: configIcons.plain(i18n("Rename:"))

            UI.ListItem {
                title: i18n("Rename inline by clicking selected item's text")
                checkable: true
                checked: configIcons.cfg_renameInline
                onToggled: checked => configIcons.cfg_renameInline = checked
            }
        }

        UI.Group {
            Layout.fillWidth: true
            title: configIcons.plain(i18n("Previews:"))

            UI.ListItem {
                title: i18n("Show preview thumbnails")
                checkable: true
                checked: configIcons.cfg_previews
                onToggled: checked => configIcons.cfg_previews = checked
            }
            UI.ListItem {
                title: i18n("Configure Preview Plugins…")
                chevron: true
                onClicked: {
                    const component = Qt.createComponent(Qt.resolvedUrl("FolderItemPreviewPluginsDialog.qml"));
                    component.incubateObject(configIcons.Window.window.contentItem, {
                        "previewPlugins": configIcons.cfg_previewPlugins,
                    }, Qt.Asynchronous);
                    component.destroy();
                }
            }
        }
    }
}
