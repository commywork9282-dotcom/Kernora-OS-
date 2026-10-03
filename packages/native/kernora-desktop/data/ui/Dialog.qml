/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kde.kirigami as Kirigami

QQC2.Popup {
    id: root

    property string icon
    property string title
    property string text
    property string acceptText: (typeof i18nd === "function" ? i18nd("kernora-ui", "OK") : qsTr("OK"))
    property string rejectText: (typeof i18nd === "function" ? i18nd("kernora-ui", "Cancel") : qsTr("Cancel"))
    property bool acceptEnabled: true
    property bool destructive: false
    property bool showReject: true
    property bool showAccept: true
    property int preferredWidth: 420
    default property alias content: body.data

    signal accepted()
    signal rejected()

    parent: QQC2.Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(preferredWidth, (parent ? parent.width : preferredWidth) - 48)
    modal: true
    dim: true
    focus: true
    padding: 24
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    transformOrigin: QQC2.Popup.Center

    onRejected: close()

    function accept(): void {
        accepted();
        close();
    }

    QQC2.Overlay.modal: Rectangle {
        color: M3.withAlpha(M3.scrim, 0.4)
        Behavior on opacity { NumberAnimation { duration: M3.durationMedium1 } }
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: M3.durationShort4 }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: M3.durationShort3; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedAccelerate }
    }

    background: Kirigami.ShadowedRectangle {
        readonly property var shadowSpec: M3.elevationOf("dialog")
        radius: M3.cornerDialog
        color: M3.surfaceContainerHigh
        shadow.size: M3.classic ? shadowSpec.blur : 0
        shadow.yOffset: shadowSpec.offset
        shadow.color: Qt.rgba(0, 0, 0, shadowSpec.opacity)
    }

    contentItem: ColumnLayout {
        spacing: 16

        MIcon {
            Layout.alignment: Qt.AlignHCenter
            visible: root.icon.length > 0
            size: 24
            source: root.icon
            color: root.destructive ? M3.error : M3.secondary
        }
        MText {
            Layout.fillWidth: true
            role: "headlineSmall"
            text: root.title
            visible: text.length > 0
            wrapMode: Text.Wrap
            horizontalAlignment: root.icon.length > 0 ? Text.AlignHCenter : Text.AlignLeft
        }
        MText {
            Layout.fillWidth: true
            role: "bodyMedium"
            text: root.text
            visible: text.length > 0
            color: M3.surfaceVariantContent
            wrapMode: Text.Wrap
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.15
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 8
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8
            visible: root.showAccept || root.showReject
            Item { Layout.fillWidth: true }
            QQC2.Button {
                text: root.rejectText
                flat: true
                visible: root.showReject
                onClicked: root.rejected()
            }
            QQC2.Button {
                text: root.acceptText
                flat: !root.destructive
                highlighted: root.destructive
                visible: root.showAccept
                enabled: root.acceptEnabled
                onClicked: root.accept()
            }
        }
    }
}
