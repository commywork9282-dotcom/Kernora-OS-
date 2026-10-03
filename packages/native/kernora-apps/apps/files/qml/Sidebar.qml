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

QQC2.ScrollView {
    id: root

    property url currentFolder
    property bool showTrash: true
    signal chosen(url folder)

    contentWidth: availableWidth
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

    Places {
        id: places
        onReady: (row, ok, url) => {
            if (ok) {
                root.chosen(url);
            }
        }
        onFailed: message => QQC2.ApplicationWindow.window.showMessage(message, "", null)
    }

    function folderFor(url: url): url {
        return String(url).startsWith("trash:") ? Files.trashFolder() : url;
    }
    function isCurrent(url: url): bool {
        const target = String(folderFor(url)).replace(/\/$/, "");
        return target === String(root.currentFolder).replace(/\/$/, "");
    }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: places
            delegate: Column {
                id: place

                required property int index
                required property string display
                required property url url
                required property string iconName
                required property bool isHidden
                required property bool isSetupNeeded

                readonly property int group: places.groupOf(index)
                readonly property bool shown: !isHidden && (group === 0 || group === 4 || group === 5)
                    && !String(url).startsWith("remote:") && !String(url).startsWith("recentlyused:")
                    && (root.showTrash || !String(url).startsWith("trash:"))
                readonly property bool firstDevice: (group === 4 || group === 5) && (index === 0 || places.groupOf(index - 1) < 4)

                width: parent.width
                visible: shown
                spacing: 2

                MText {
                    visible: place.firstDevice && place.shown
                    leftPadding: 20
                    topPadding: 16
                    bottomPadding: 6
                    role: "titleSmall"
                    color: M3.surfaceVariantContent
                    text: i18n("Devices")
                }

                NavigationItem {
                    width: parent.width
                    height: 52
                    title: place.display
                    current: root.isCurrent(place.url)
                    leading: Component {
                        MIcon {
                            size: 24
                            source: place.iconName
                            color: root.isCurrent(place.url) ? M3.secondaryContainerContent : M3.surfaceVariantContent
                        }
                    }
                    onClicked: {
                        if (place.isSetupNeeded) {
                            places.setup(place.index);
                        } else {
                            root.chosen(root.folderFor(place.url));
                        }
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (place.group === 5 || place.group === 4) && !place.isSetupNeeded && (places.canEject(place.index) || places.canUnmount(place.index))
                        iconName: "media-eject"
                        text: i18n("Eject")
                        onClicked: places.canEject(place.index) ? places.eject(place.index) : places.unmount(place.index)
                    }
                }
            }
        }
    }
}
