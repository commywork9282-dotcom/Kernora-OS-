/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>
    SPDX-FileCopyrightText: 2020-2024 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kwindowsystem
import org.kernora.m3

ColumnLayout {
    id: root

    required property int index
    required property  var submodelIndex
    required property int appPid
    required property string display
    required property bool isMinimized
    required property bool isOnAllVirtualDesktops
    required property  var virtualDesktops
    required property list<string> activities

    property bool hasTrackInATitle: false
    property int orientation: ListView.Vertical

    ListView.onPooled: width = height = 0
    ListView.onReused: width = height = undefined

    readonly property string title: {
        if (!toolTipDelegate.isWin) {
            return toolTipDelegate.genericName;
        }

        let text = display;
        if (toolTipDelegate.isGroup && text === "") {
            return "";
        }

        if (!text.match(/\s+(—|-|–)/)) {
            return text;
        }

        text = `${(text.match(/.*(?=\s+(—|-|–))/) || [""])[0]}${(text.match(/<\d+>/) || [""]).pop()}`;

        if (text === "") {
            text = "—";
        }
        return text;
    }

    readonly property bool titleIncludesTrack: toolTipDelegate.playerData !== null && title.includes(toolTipDelegate.playerData.track)

    spacing: Plasmoid.configuration.showToolTips ? Kirigami.Units.smallSpacing : 0

    Item {
        id: headerItem
        implicitHeight: header.height
        implicitWidth: header.implicitWidth
        Layout.fillWidth: true

        Layout.maximumWidth: toolTipDelegate.tooltipInstanceMaximumWidth
        Layout.minimumWidth: (toolTipDelegate.isWin && Plasmoid.configuration.showToolTips) || toolTipDelegate.isGroup ? Layout.maximumWidth : 0
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        Layout.margins: toolTipDelegate.isWin && Plasmoid.configuration.showToolTips ? 0 : Kirigami.Units.gridUnit / 2

        RowLayout {
            id: header
            width: parent.width
            spacing: Kirigami.Units.smallSpacing

            ColumnLayout {
                spacing: 0
                Kirigami.Heading {
                    id: appNameHeading
                    level: 3
                    maximumLineCount: 1
                    Layout.fillWidth: true
                    lineHeight: toolTipDelegate.isWin && Plasmoid.configuration.showToolTips ? 1 : appNameHeading.lineHeight
                    elide: Text.ElideRight
                    text: toolTipDelegate.appName
                    color: (headerHoverHandler.visible && headerHoverHighlight.pressed) ? PlasmaCore.Theme.highlightedTextColor : PlasmaCore.Theme.textColor
                    opacity: root.index === 0 ? 1 : 0
                    visible: (text.length !== 0) && (root.orientation === ListView.Horizontal || root.index === 0)
                    textFormat: Text.PlainText
                }
                PlasmaComponents3.Label {
                    id: winTitle
                    maximumLineCount: 1
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    property bool somethingVisible: (thumbnailSourceItem.visible ||
                        appNameHeading.visible || subtext.visible)
                    text: ((root.titleIncludesTrack && playerController.active) ||
                           (root.title === appNameHeading.text && somethingVisible))
                          ? "" : root.title
                    color: (headerHoverHandler.visible && headerHoverHighlight.pressed) ? PlasmaCore.Theme.highlightedTextColor : PlasmaCore.Theme.textColor
                    opacity: 0.75
                    visible: root.orientation === ListView.Horizontal || text.length !== 0
                    textFormat: Text.PlainText
                }
                PlasmaComponents3.Label {
                    id: subtext
                    maximumLineCount: 2
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: toolTipDelegate.isWin ? root.generateSubText() : ""
                    color: (headerHoverHandler.visible && headerHoverHighlight.pressed) ? PlasmaCore.Theme.highlightedTextColor : PlasmaCore.Theme.textColor
                    opacity: 0.6
                    visible: text.length !== 0 && text !== appNameHeading.text
                    textFormat: Text.PlainText
                }
            }

            Item {
                Layout.alignment: !Plasmoid.configuration.showToolTips && !playerController.active && !volumeControls.active ? Qt.AlignVCenter : Qt.AlignTop
                Layout.preferredHeight: closeButton.height
                Layout.preferredWidth: closeButton.width
                visible: root.index === 0 && toolTipDelegate.smartLauncherCountVisible

                Badge {
                    anchors.centerIn: parent
                    height: Kirigami.Units.iconSizes.smallMedium
                    number: toolTipDelegate.smartLauncherCount
                }
            }

            PlasmaComponents3.ToolButton {
                id: closeButton
                Layout.alignment: Qt.AlignTop
                Layout.rightMargin: -headerItem.Layout.margins
                Layout.topMargin: -headerItem.Layout.margins
                visible: toolTipDelegate.isWin
                icon.name: "window-close"
                onClicked: {
                    backend.cancelHighlightWindows();
                    tasksModel.requestClose(root.submodelIndex);
                }
            }
        }

        Loader {
            id: headerHoverHandler
            active: (root.index !== -1) && !Plasmoid.configuration.showToolTips
            z: -2
            anchors.fill: headerItem
            anchors.margins: -headerItem.Layout.margins
            sourceComponent: ToolTipWindowMouseArea {
                rootTask: toolTipDelegate.parentTask
                modelIndex: root.submodelIndex
                winId: thumbnailSourceItem.winId
            }
        }

        PlasmaExtras.Highlight {
            id: headerHoverHighlight
            anchors.fill: headerHoverHandler
            z: -1
            visible: (headerHoverHandler.item as MouseArea)?.containsMouse ?? false
            pressed: (headerHoverHandler.item as MouseArea)?.containsPress ?? false
            hovered: true
        }
    }

    Item {
        id: thumbnailSourceItem

        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 8

        visible: Plasmoid.configuration.showToolTips && toolTipDelegate.isWin

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: thumbnailMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        Rectangle {
            id: thumbnailMask
            width: thumbnailSourceItem.width
            height: thumbnailSourceItem.height
            radius: M3.classic ? M3.cornerImage : 16
            visible: false
            layer.enabled: true
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(PlasmaCore.Theme.textColor, 0.08)
        }

        readonly property  var winId:
            toolTipDelegate.isWin ? toolTipDelegate.windows[root.index] : undefined

        PlasmaExtras.Highlight {
            anchors.fill: hoverHandler
            visible: (hoverHandler.item as MouseArea)?.containsMouse ?? false
            pressed: (hoverHandler.item as MouseArea)?.containsPress ?? false
            hovered: true
        }

        Loader {
            id: thumbnailLoader
            active: !toolTipDelegate.isLauncher
                && !albumArtImage.visible
                && (Number.isInteger(thumbnailSourceItem.winId) || pipeWireLoader.item && !pipeWireLoader.item.hasThumbnail)
                && root.index !== -1
            asynchronous: true
            visible: active
            anchors.fill: hoverHandler
            anchors.margins: Kirigami.Units.smallSpacing

            sourceComponent: root.isMinimized || pipeWireLoader.active ? iconItem : x11Thumbnail

            Component {
                id: x11Thumbnail

                PlasmaCore.WindowThumbnail {
                    winId: thumbnailSourceItem.winId
                }
            }

            Component {
                id: iconItem

                Kirigami.Icon {
                    id: realIconItem
                    source: toolTipDelegate.icon
                    animated: false
                    visible: valid
                    opacity: pipeWireLoader.active ? 0 : 1

                    SequentialAnimation {
                        running: true

                        PauseAnimation {
                            duration: Kirigami.Units.humanMoment
                        }

                        NumberAnimation {
                            id: showAnimation
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.OutCubic
                            property: "opacity"
                            target: realIconItem
                            to: 1
                        }
                    }

                }
            }
        }

        Loader {
            id: pipeWireLoader
            anchors.fill: hoverHandler
            anchors.margins: thumbnailLoader.anchors.margins

            active: !toolTipDelegate.isLauncher && !albumArtImage.visible && KWindowSystem.isPlatformWayland && root.index !== -1
            asynchronous: true
            source: "KernoraWindowThumbnail.qml"
        }

        Loader {
            active: false
            asynchronous: true
            visible: active
            anchors.fill: pipeWireLoader.active ? pipeWireLoader : thumbnailLoader

            sourceComponent: GE.DropShadow {
                horizontalOffset: 0
                verticalOffset: 3
                radius: 8
                samples: Math.round(radius * 1.5)
                color: "Black"
                source: pipeWireLoader.active ? pipeWireLoader.item : thumbnailLoader.item
            }
        }

        Loader {
            active: albumArtImage.visible && albumArtImage.status === Image.Ready && root.index !== -1
            asynchronous: true
            visible: active
            anchors.centerIn: hoverHandler

            sourceComponent: ShaderEffect {
                id: albumArtBackground
                readonly property Image source: albumArtImage

                readonly property real scaleFactor: Math.max(hoverHandler.width / source.paintedWidth, hoverHandler.height / source.paintedHeight)
                width: Math.round(source.paintedWidth * scaleFactor)
                height: Math.round(source.paintedHeight * scaleFactor)
                layer.enabled: true
                opacity: 0.25
                layer.effect: GE.FastBlur {
                    source: albumArtBackground
                    anchors.fill: source
                    radius: 30
                }
            }
        }

        Image {
            id: albumArtImage
            readonly property bool available: (status === Image.Ready || status === Image.Loading)
                && (!(toolTipDelegate.isGroup || backend.applicationCategories(launcherUrl).includes("WebBrowser")) || root.titleIncludesTrack)

            anchors.fill: hoverHandler
            sourceSize: Qt.size(parent.width, parent.height)

            asynchronous: true
            source: toolTipDelegate.playerData?.artUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            visible: available
        }

        Loader {
            id: hoverHandler
            active: root.index !== -1
            anchors.fill: parent
            sourceComponent: ToolTipWindowMouseArea {
                rootTask: toolTipDelegate.parentTask
                modelIndex: root.submodelIndex
                winId: thumbnailSourceItem.winId
            }
        }
    }

    Loader {
        id: playerController
        active: toolTipDelegate.playerData && ((hasTrackInATitle && albumArtImage.available) || (!hasTrackInATitle && root.index == 0))

        asynchronous: true
        visible: active
        Layout.fillWidth: true
        Layout.maximumWidth: headerItem.Layout.maximumWidth
        Layout.leftMargin: headerItem.Layout.margins
        Layout.rightMargin: headerItem.Layout.margins

        source: "PlayerController.qml"
    }

    Loader {
        id: volumeControls
        active: toolTipDelegate.parentTask !== null
             && pulseAudio.item !== null
             && toolTipDelegate.parentTask.hasAudioStream
             && ((hasTrackInATitle && albumArtImage.available) || (!hasTrackInATitle && root.index == 0))
        asynchronous: true
        visible: active
        Layout.fillWidth: true
        Layout.maximumWidth: headerItem.Layout.maximumWidth
        Layout.leftMargin: headerItem.Layout.margins
        Layout.rightMargin: headerItem.Layout.margins
        sourceComponent: RowLayout {
            PlasmaComponents3.ToolButton {
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                icon.name: if (checked) {
                    "audio-volume-muted"
                } else if (slider.displayValue <= 25) {
                    "audio-volume-low"
                } else if (slider.displayValue <= 75) {
                    "audio-volume-medium"
                } else {
                    "audio-volume-high"
                }
                onClicked: toolTipDelegate.parentTask.toggleMuted()
                checked: toolTipDelegate.parentTask.muted

                PlasmaComponents3.ToolTip {
                    text: parent.checked
                        ? i18nc("button to unmute app", "Unmute %1", toolTipDelegate.parentTask.appName)
                        : i18nc("button to mute app", "Mute %1", toolTipDelegate.parentTask.appName)
                }
            }

            PlasmaComponents3.Slider {
                id: slider

                readonly property int displayValue: Math.round(value / to * 100)
                readonly property int loudestVolume: toolTipDelegate.parentTask.audioStreams
                    .reduce((loudestVolume, stream) => Math.max(loudestVolume, stream.volume), 0)

                Layout.fillWidth: true
                from: pulseAudio.item.minimalVolume
                to: pulseAudio.item.normalVolume
                value: loudestVolume
                stepSize: to / 100
                opacity: toolTipDelegate.parentTask.muted ? 0.5 : 1

                Accessible.name: i18nc("Accessibility data on volume slider", "Adjust volume for %1", toolTipDelegate.parentTask.appName)

                onMoved: toolTipDelegate.parentTask.audioStreams.forEach((stream) => {
                    let v = Math.max(from, value)
                    if (v > 0 && loudestVolume > 0) {
                        v = Math.min(Math.round(stream.volume / loudestVolume * v), to)
                    }
                    stream.model.Volume = v
                    stream.model.Muted = v === 0
                })
            }
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.minimumWidth: percentMetrics.advanceWidth
                horizontalAlignment: Qt.AlignRight
                text: i18nc("volume percentage", "%1%", slider.displayValue)
                textFormat: Text.PlainText
                TextMetrics {
                    id: percentMetrics
                    text: i18nc("only used for sizing, should be widest possible string", "100%")
                }
            }
        }
    }

    function generateSubText(): string {
        const subTextEntries = [];

        if (!Plasmoid.configuration.showOnlyCurrentDesktop && virtualDesktopInfo.numberOfDesktops > 1) {
            if (!isOnAllVirtualDesktops && virtualDesktops.length > 0) {
                const virtualDesktopNameList = virtualDesktops.map(virtualDesktop => {
                    const index = virtualDesktopInfo.desktopIds.indexOf(virtualDesktop);
                    return virtualDesktopInfo.desktopNames[index];
                });

                subTextEntries.push(i18nc("Comma-separated list of desktops", "On %1",
                    virtualDesktopNameList.join(", ")));
            } else if (isOnAllVirtualDesktops) {
                subTextEntries.push(i18nc("Comma-separated list of desktops", "Pinned to all desktops"));
            }
        }

        if (activities.length === 0 && activityInfo.numberOfRunningActivities > 1) {
            subTextEntries.push(i18nc("Which virtual desktop a window is currently on",
                "Available on all activities"));
        } else if (activities.length > 0) {
            const activityNames = activities
                .filter(activity => activity !== activityInfo.currentActivity)
                .map(activity => activityInfo.activityName(activity))
                .filter(activityName => activityName !== "");

            if (Plasmoid.configuration.showOnlyCurrentActivity) {
                if (activityNames.length > 0) {
                    subTextEntries.push(i18nc("Activities a window is currently on (apart from the current one)",
                        "Also available on %1", activityNames.join(", ")));
                }
            } else if (activityNames.length > 0) {
                subTextEntries.push(i18nc("Which activities a window is currently on",
                    "Available on %1", activityNames.join(", ")));
            }
        }

        return subTextEntries.join("\n");
    }
}
