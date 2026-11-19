/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import org.kernora.m3

PixelPage {
    id: page

    icon: config.failed ? "error" : "check_circle"
    title: config.failed ? qsTr("Installation Failed") : qsTr("All set")
    description: config.failed ? config.failureMessage
        : qsTr("%1 is installed. Restart the computer and sign in to your account.").arg(Branding.string(Branding.ShortProductName))
    showBack: false
    primaryText: config.failed ? qsTr("Close Installer") : qsTr("Restart now")
    primaryEnabled: true
    primaryAction: () => config.failed ? ViewManager.quit() : config.doRestart(true)
    secondaryText: config.failed ? "" : qsTr("Later")
    secondaryAction: () => ViewManager.quit()

    below: Text {
        visible: config.failed && text.length > 0
        width: parent ? parent.width : 400
        text: config.failureDetails
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        font: M3.bodyMedium
        color: M3.surfaceVariantContent
    }

    Item {
        anchors.fill: parent

        MShape {
            id: badge

            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.62
            height: width
            shape: config.failed ? "cookie4" : "sunny"
            color: config.failed ? M3.errorContainer : M3.primaryContainer
            rotation: -30 * (1 - arrive.value)
            scale: 0.6 + 0.4 * arrive.value

            MMorph {
                id: arrive
                active: page.visible
                dampingRatio: 0.55
                response: 0.6
            }

            MIcon {
                anchors.centerIn: parent
                rotation: -badge.rotation
                size: Math.round(badge.width * 0.36)
                source: page.symbol(config.failed ? "error" : "check")
                color: config.failed ? M3.errorContainerContent : M3.primaryContainerContent
            }
        }
    }

    function onActivate() {}
    function onLeave() {}
}
