/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import org.kernora.m3

Item {
    id: hello

    readonly property var greetings: ["Hello", "Привет", "Hola", "Bonjour", "Hallo", "Olá", "Привіт", "Cześć", "Merhaba", "你好", "こんにちは", "Ciao"]
    readonly property bool checking: !ViewManager.nextEnabled && failures.count === 0
    readonly property bool blocking: !checking && !config.requirementsModel.satisfiedMandatory
    property int shown: Qt.locale().name.indexOf("ru") === 0 ? 1 : 0
    readonly property bool still: M3.motionScale === 0

    SetupAccessibility {}

    function symbol(name: string): url {
        return Qt.resolvedUrl("symbols/" + name + "_24px.svg");
    }

    Rectangle {
        anchors.fill: parent
        color: M3.surface
    }

    MShape {
        x: hello.width - hello.height * 0.62
        y: -hello.height * 0.37
        width: hello.height * 1.09
        height: width
        shape: "puffy"
        color: M3.primaryContainer
        opacity: 0.85

        RotationAnimation on rotation {
            running: !hello.still
            from: 12
            to: 372
            duration: 240000
            loops: Animation.Infinite
        }
    }

    MShape {
        x: -hello.height * 0.4
        y: hello.height * 0.48
        width: hello.height * 0.91
        height: width
        shape: "cookie12"
        color: M3.tertiaryContainer
        opacity: 0.8

        RotationAnimation on rotation {
            running: !hello.still
            from: -18
            to: -378
            duration: 300000
            loops: Animation.Infinite
        }
    }

    Item {
        id: tryButton

        x: 32
        y: 32
        width: tryLabel.implicitWidth + 40
        height: 48
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: tryLabel.text
        Keys.onReturnPressed: ViewManager.quit()
        Keys.onSpacePressed: ViewManager.quit()

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: M3.surfaceContainerHigh
        }

        MText {
            id: tryLabel
            anchors.centerIn: parent
            role: "labelLarge"
            text: qsTr("Try without installing")
            color: M3.surfaceContent
        }

        MStateLayer {
            anchors.fill: parent
            radius: height / 2
            color: M3.surfaceContent
            hovered: tryMouse.containsMouse
            pressed: tryMouse.pressed
            focused: tryButton.activeFocus
        }

        MouseArea {
            id: tryMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ViewManager.quit()
        }
    }

    Item {
        id: greeting

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(hello.height * 0.5 - height / 2)
        width: hello.width
        height: 150

        Repeater {
            model: 2

            MText {
                required property int index
                readonly property bool current: (hello.shown % 2) === index
                property string label: hello.greetings[index]

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: current ? 0 : 24
                role: "displayLarge"
                font.pixelSize: Math.round(Math.max(72, Math.min(112, hello.height * 0.125)))
                font.weight: Font.Normal
                text: label
                color: M3.surfaceContent
                opacity: current ? 1 : 0

                Component.onCompleted: label = hello.greetings[(hello.shown + (current ? 0 : 1)) % hello.greetings.length]
                onCurrentChanged: if (current) label = hello.greetings[hello.shown % hello.greetings.length]

                Behavior on opacity {
                    NumberAnimation {
                        duration: hello.still ? 0 : 600
                        easing.type: Easing.Bezier
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                    }
                }

                Behavior on anchors.verticalCenterOffset {
                    NumberAnimation {
                        duration: hello.still ? 0 : 600
                        easing.type: Easing.Bezier
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                    }
                }
            }
        }
    }

    Timer {
        interval: 2600
        running: hello.visible
        repeat: true
        onTriggered: hello.shown = hello.shown + 1
    }

    Rectangle {
        id: notice

        visible: hello.checking || failures.count > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: actions.top
        anchors.bottomMargin: 32
        width: Math.min(560, hello.width - 64)
        height: noticeBody.implicitHeight + 40
        radius: 28
        color: hello.checking ? M3.surfaceContainerHigh : hello.blocking ? M3.errorContainer : M3.tertiaryContainer

        readonly property color ink: hello.checking ? M3.surfaceContent
            : hello.blocking ? M3.errorContainerContent : M3.tertiaryContainerContent

        Column {
            id: noticeBody

            x: 24
            y: 20
            width: parent.width - 48
            spacing: 10

            MText {
                width: parent.width
                role: "titleMedium"
                text: hello.checking ? qsTr("Checking this computer…")
                    : hello.blocking ? qsTr("Installation cannot continue yet")
                    : qsTr("You can continue with these warnings")
                color: notice.ink
                wrapMode: Text.Wrap
            }

            MLinearProgress {
                visible: hello.checking
                width: parent.width
                indeterminate: true
            }

            Repeater {
                id: failures

                model: config.unsatisfiedRequirements

                delegate: MText {
                    required property string negatedText

                    width: noticeBody.width
                    role: "bodyMedium"
                    text: negatedText.length > 0 ? negatedText : qsTr("A system check did not complete successfully.")
                    color: notice.ink
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    Row {
        id: actions

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(Math.max(40, Math.min(72, hello.height * 0.08)))
        spacing: 12

        Item {
            id: assist

            width: 96
            height: 96
            activeFocusOnTab: true

            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Accessibility")
            Keys.onReturnPressed: sheet.open()
            Keys.onEnterPressed: sheet.open()
            Keys.onSpacePressed: sheet.open()

            MMorph {
                id: assistMorph
                active: assistMouse.pressed
            }

            Rectangle {
                id: assistShape
                anchors.fill: parent
                radius: height / 2 + (24 - height / 2) * assistMorph.value
                color: M3.surfaceContainerHighest
            }

            MIcon {
                anchors.centerIn: parent
                size: 32
                source: hello.symbol("accessibility_new")
                color: M3.surfaceContent
            }

            MStateLayer {
                anchors.fill: parent
                radius: assistShape.radius
                color: M3.surfaceContent
                hovered: assistMouse.containsMouse
                pressed: assistMouse.pressed
                focused: assist.activeFocus
            }

            MouseArea {
                id: assistMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sheet.open()
            }
        }

        Item {
            id: next

            width: 280
            height: 96
            enabled: ViewManager.nextEnabled
            opacity: enabled ? 1 : 0.38
            activeFocusOnTab: true
            focus: true

            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Next")
            Keys.onReturnPressed: ViewManager.next()
            Keys.onEnterPressed: ViewManager.next()
            Keys.onSpacePressed: ViewManager.next()

            MMorph {
                id: nextMorph
                active: nextMouse.pressed
            }

            Rectangle {
                id: nextShape
                anchors.fill: parent
                radius: height / 2 + (24 - height / 2) * nextMorph.value
                color: M3.primary
            }

            MIcon {
                anchors.centerIn: parent
                size: 36
                source: hello.symbol("arrow_forward")
                color: M3.primaryContent
            }

            MStateLayer {
                anchors.fill: parent
                radius: nextShape.radius
                color: M3.primaryContent
                hovered: nextMouse.containsMouse
                pressed: nextMouse.pressed
                focused: next.activeFocus
            }

            MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ViewManager.next()
            }
        }
    }

    AccessibilitySheet {
        id: sheet
        anchors.fill: parent
        onClosed: assist.forceActiveFocus()
    }

    function onActivate() {
        next.forceActiveFocus();
    }

    function onLeave() {}
}
