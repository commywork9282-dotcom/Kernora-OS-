/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kquickcontrolsaddons as KQCAddons

import org.kernora.ui

RoundedClip {
    id: picture

    property var source
    readonly property bool isImageData: !!source && typeof source !== "string"
    readonly property bool isPath: typeof source === "string" && (source.startsWith("/") || source.includes(":"))
    readonly property bool valid: isImageData ? !imageData.null : (isPath && fileImage.status === Image.Ready)

    KQCAddons.QImageItem {
        id: imageData
        anchors.fill: parent
        visible: picture.isImageData
        fillMode: KQCAddons.QImageItem.PreserveAspectCrop
        smooth: true
    }
    Binding {
        target: imageData
        property: "image"
        value: picture.source
        when: picture.isImageData
    }
    Image {
        id: fileImage
        anchors.fill: parent
        visible: picture.isPath
        source: picture.isPath ? picture.source : ""
        sourceSize: Qt.size(96, 96)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }
}
