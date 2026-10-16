/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import "impl"

T.BusyIndicator {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    padding: 0
    hoverEnabled: false

    contentItem: Item {
        id: spinner

        implicitWidth: Kirigami.Units.gridUnit * 2
        implicitHeight: Kirigami.Units.gridUnit * 2

        readonly property real size: Math.min(width, height)
        readonly property bool active: visible && Window.visibility !== Window.Hidden
                                       && Kirigami.Units.longDuration > 1

        visible: control.running || fade.running
        opacity: control.running ? 1 : 0
        Behavior on opacity {
            OpacityAnimator {
                id: fade
                duration: M3.durationShort4
            }
        }

        MCircularProgress {
            anchors.centerIn: parent
            width: spinner.size
            height: spinner.size
            running: spinner.active
        }
    }
}
