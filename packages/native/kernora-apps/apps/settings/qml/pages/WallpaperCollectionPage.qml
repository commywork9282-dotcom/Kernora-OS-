/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui
import "../components"

SettingsPage {
    id: page

    required property var appearance
    required property string collection
    required property string name

    readonly property bool liveCollection: collection === "kernora"
    readonly property var items: {
        if (liveCollection) {
            return appearance.liveWallpapers;
        }
        const found = appearance.collections.find(c => c.id === collection);
        return found ? found.items : [];
    }

    title: name

    Group {
        GridLayout {
            width: parent.width
            columns: Math.max(2, Math.floor(width / 190))
            columnSpacing: 12
            rowSpacing: 12

            Repeater {
                model: page.items
                delegate: WallpaperTile {
                    required property var modelData
                    Layout.fillWidth: true
                    title: modelData.name
                    subtitle: page.liveCollection ? i18n("Live") : ""
                    scene: page.liveCollection ? modelData.scene : ""
                    preview: page.liveCollection ? "" : modelData.preview
                    selected: page.liveCollection
                              ? page.appearance.wallpaperPlugin === modelData.id
                              : !page.appearance.live && page.appearance.sameImage(page.appearance.wallpaperImage, modelData.image)
                    onClicked: {
                        if (page.liveCollection) {
                            page.appearance.chooseLive(modelData.id);
                        } else {
                            page.appearance.chooseImage(modelData.image);
                        }
                    }
                }
            }
        }
    }
}
