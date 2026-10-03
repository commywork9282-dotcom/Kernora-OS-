/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3

import org.kernora.m3

PlasmaComponents3.StackView {
    id: actionContainer

    property ModelInterface modelInterface

    implicitWidth: currentItem.Layout.maximumWidth < Infinity ? currentItem.Layout.maximumWidth : currentItem.implicitWidth
    implicitHeight: currentItem.implicitHeight

    function beginReply() {
        modelInterface.replying = true;
        modelInterface.forceActiveFocusRequested();
        if (currentItem === actionRow) {
            push(replyFieldComponent);
        }
        currentItem.activate()
    }

    pushEnter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: M3.durationMedium2
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingStandardDecelerate
        }
    }
    pushExit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: M3.durationShort4
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingStandardAccelerate
        }
    }

    initialItem: (actionContainer.modelInterface.hasReplyAction && (actionContainer.modelInterface.actionNames || []).length === 0) ? replyFieldComponent : actionRow
    Flow {
        id: actionRow
        visible: actionContainer.currentItem === actionRow
        width: actionContainer.width
        spacing: 8

        Repeater {
            id: actionRepeater

            model: {
                const buttons = [];
                const actionNames = (actionContainer.modelInterface.actionNames || []);
                const actionLabels = (actionContainer.modelInterface.actionLabels || []);

                for (let i = 0; i < actionNames.length; ++i) {
                    buttons.push({
                        actionName: actionNames[i],
                        label: actionLabels[i]
                    });
                }

                if (actionContainer.modelInterface.hasReplyAction) {
                    buttons.unshift({
                        actionName: "inline-reply",
                        label: actionContainer.modelInterface.replyActionLabel || i18ndc("plasma_applet_org.kde.plasma.notifications", "Reply to message", "Reply")
                    });
                }

                return buttons;
            }

            MButton {
                required property var modelData
                variant: "tonal"
                icon: modelData.actionName === "inline-reply" ? "mail-reply-sender" : ""
                text: modelData.label || ""

                onClicked: {
                    if (modelData.actionName === "inline-reply") {
                        actionContainer.beginReply();
                        return;
                    }

                    actionContainer.modelInterface.actionInvoked(modelData.actionName);
                }
            }
        }
    }

    Component {
        id: replyFieldComponent
        NotificationReplyField {
            modelInterface: actionContainer.modelInterface
            onBeginReplyRequested: actionContainer.beginReply()
        }
    }
}
