/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kernora.ui as UI
import "m3"

Item {
    id: root

    required property int index
    required property var display
    required property var decoration
    required property size imageSize
    required property string uuid
    required property int type

    property bool first: false
    property bool last: false
    property bool current: false
    readonly property bool hovered: hover.hovered

    signal chosen()
    signal removeRequested()

    readonly property bool isImage: type === 4
    readonly property bool isFiles: type === 8
    readonly property string plainText: String(display ?? "").slice(0, 600).replace(/\s+/g, " ").trim()
    readonly property bool isLink: type === 2 && /^(https?|ftp):\/\/[^\s/]+\S*$/i.test(plainText)
    readonly property var urls: isFiles ? String(display ?? "").split(" ").filter(url => url.length > 0) : []
    readonly property bool isEmoji: type === 2 && plainText.length > 0 && plainText.length <= 24
        && /[\u{1F000}-\u{1FAFF}\uFE0F]/u.test(plainText)
        && /^(?:[\u{1F000}-\u{1FAFF}\u{E0020}-\u{E007F}\u2190-\u21FF\u2300-\u23FF\u2600-\u27BF\u2B00-\u2BFF\u00A9\u00AE\u203C\u2049\u2122\u2139\u3030\u303D\u3297\u3299\u200D\uFE0F\u20E3#*0-9 ])+$/u.test(plainText)

    function fileName(url: string): string {
        const path = url.replace(/\/+$/, "");
        return decodeURIComponent(path.slice(path.lastIndexOf("/") + 1));
    }
    function folderName(url: string): string {
        const path = decodeURIComponent(url.replace(/^file:\/\//, "").replace(/\/+$/, ""));
        return path.slice(0, Math.max(1, path.lastIndexOf("/")));
    }

    readonly property string headline: {
        if (isEmoji) {
            return "";
        }
        if (isImage) {
            return i18n("Picture");
        }
        if (isFiles) {
            return urls.length === 1 ? fileName(urls[0]) : i18np("%1 file", "%1 files", urls.length);
        }
        if (isLink) {
            return plainText.replace(/^[a-z]+:\/\//i, "").replace(/^www\./i, "").split(/[/?#]/)[0];
        }
        return plainText.length > 0 ? plainText : i18n("Blank space");
    }
    readonly property string supporting: {
        if (isEmoji) {
            return i18n("Emoji");
        }
        if (isImage) {
            return imageSize.width > 0 ? i18nc("picture size in pixels", "%1 × %2", imageSize.width, imageSize.height) : "";
        }
        if (isFiles) {
            return urls.length > 0 ? folderName(urls[0]) : "";
        }
        if (isLink) {
            return plainText;
        }
        return "";
    }

    implicitHeight: Math.max(64, content.implicitHeight + 24)

    Accessible.role: Accessible.ListItem
    Accessible.name: headline
    Accessible.description: supporting

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        onClicked: root.chosen()
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: root.current ? M3.secondaryContainer : M3.surfaceContainerHigh
        topLeftRadius: root.first ? M3.cornerCard : M3.cornerCardInner
        topRightRadius: root.first ? M3.cornerCard : M3.cornerCardInner
        bottomLeftRadius: root.last ? M3.cornerCard : M3.cornerCardInner
        bottomRightRadius: root.last ? M3.cornerCard : M3.cornerCardInner

        Behavior on color {
            ColorAnimation {
                duration: M3.durationShort3
            }
        }

        MStateLayer {
            topLeftRadius: card.topLeftRadius
            topRightRadius: card.topRightRadius
            bottomLeftRadius: card.bottomLeftRadius
            bottomRightRadius: card.bottomRightRadius
            color: root.current ? M3.secondaryContainerContent : M3.surfaceContent
            pressed: mouse.pressed
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
        }

        RowLayout {
            id: content
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 16
                rightMargin: 8
            }
            spacing: 16

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                visible: root.isLink
                implicitWidth: 40
                implicitHeight: 40
                radius: 20
                color: root.current ? M3.surfaceContainerLowest : M3.surfaceContainerHighest

                MIcon {
                    anchors.centerIn: parent
                    size: 20
                    source: "link"
                    color: M3.primary
                }
            }

            UI.RoundedClip {
                Layout.alignment: Qt.AlignVCenter
                visible: root.isImage
                radius: M3.cornerImage
                implicitHeight: 72
                implicitWidth: root.imageSize.height > 0
                    ? Math.max(72, Math.min(144, Math.round(72 * root.imageSize.width / root.imageSize.height)))
                    : 72

                Rectangle {
                    anchors.fill: parent
                    color: M3.surfaceContainerHighest
                }
                Image {
                    anchors.fill: parent
                    source: root.isImage ? root.decoration : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.height: 144
                    asynchronous: true
                    cache: false
                    smooth: true
                }
            }

            UI.RoundedClip {
                Layout.alignment: Qt.AlignVCenter
                visible: root.isFiles
                radius: M3.cornerImage
                implicitWidth: 48
                implicitHeight: 48

                Rectangle {
                    anchors.fill: parent
                    color: root.current ? M3.surfaceContainerLowest : M3.surfaceContainerHighest
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    visible: preview.status !== Image.Ready
                    source: "text-x-generic"
                    isMask: true
                    color: M3.surfaceVariantContent
                }
                Image {
                    id: preview
                    anchors.fill: parent
                    source: root.isFiles && root.urls.length > 0 ? `image://klipperpreview/${root.urls[0]}` : ""
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: root.isEmoji
                text: root.isEmoji ? root.plainText.replace(/\uFE0F/g, "") : ""
                font.family: "Noto Color Emoji"
                font.pixelSize: 28
                renderType: Text.NativeRendering
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                MText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    role: root.type === 2 && !root.isLink ? "bodyLarge" : "titleSmall"
                    text: root.headline
                    textFormat: Text.PlainText
                    color: root.current ? M3.secondaryContainerContent : M3.surfaceContent
                    wrapMode: Text.Wrap
                    maximumLineCount: root.type === 2 && !root.isLink ? 3 : 1
                    elide: Text.ElideRight
                }
                MText {
                    Layout.fillWidth: true
                    role: "bodySmall"
                    text: root.supporting
                    textFormat: Text.PlainText
                    visible: text.length > 0
                    color: root.current ? M3.secondaryContainerContent : M3.surfaceVariantContent
                    maximumLineCount: 1
                    elide: root.isFiles ? Text.ElideMiddle : Text.ElideRight
                }
            }

            MIconButton {
                id: removeButton
                Layout.alignment: Qt.AlignVCenter
                size: 36
                iconSize: 20
                icon: "edit-delete"
                text: i18n("Remove")
                opacity: root.current ? 1 : 0
                enabled: root.current
                onClicked: root.removeRequested()

                Behavior on opacity {
                    NumberAnimation {
                        duration: M3.durationShort3
                    }
                }
            }
        }
    }
}
