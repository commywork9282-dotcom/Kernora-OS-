/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui

Item {
    id: welcome

    Rectangle {
        anchors.fill: parent
        color: M3.surface
    }

    readonly property string welcomeText: qsTr("<h3>Welcome to the %1 <quote>%2</quote> installer</h3>
            <p>This program will ask you some questions and set up %1 on your computer.</p>")
            .arg(Branding.string(Branding.ProductName)).arg(Branding.string(Branding.Version))
    function part(tag: string): string {
        const match = welcomeText.match(new RegExp("<" + tag + ">([\\s\\S]*?)</" + tag + ">"));
        const text = match ? match[1] : "";
        const version = Branding.string(Branding.Version);
        const quoted = /^[0-9.]+$/.test(version) ? ["", ""] : ["«", "»"];
        return text.replace(/<quote>/g, quoted[0]).replace(/<\/quote>/g, quoted[1]).replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim();
    }

    RoundedClip {
        id: hero
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        height: parent.height * 0.46
        radius: 28

        Rectangle {
            anchors.fill: parent
            color: M3.surfaceContainerHigh
        }
        Loader {
            id: scene
            anchors.fill: parent
            source: "file:///usr/share/plasma/wallpapers/org.kernora.shapes/contents/ui/Scene.qml"
            property real phase: 0.3
            NumberAnimation on phase {
                from: 0.3
                to: 1.3
                duration: 300000
                loops: Animation.Infinite
            }
            onLoaded: {
                item.intro = 1;
                item.phase = Qt.binding(() => scene.phase % 1);
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 104
            height: 104
            radius: 52
            color: M3.primary
            MIcon {
                anchors.centerIn: parent
                size: 64
                source: "kernora-logo"
                color: M3.primaryContent
            }
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: hero.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 40
        anchors.rightMargin: 40
        anchors.topMargin: 24
        anchors.bottomMargin: 16
        spacing: 10

        MText {
            Layout.fillWidth: true
            role: "headlineMedium"
            text: welcome.part("h3")
            wrapMode: Text.Wrap
        }
        MText {
            Layout.fillWidth: true
            role: "bodyLarge"
            color: M3.surfaceVariantContent
            text: welcome.part("p")
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 16
            IconCircle {
                icon: "preferences-desktop-locale"
                accent: 3
            }
            ComboBox {
                Layout.fillWidth: true
                Layout.maximumWidth: 420
                model: config.languagesModel
                textRole: "label"
                currentIndex: config.localeIndex
                onActivated: index => config.localeIndex = index
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: !config.requirementsModel.satisfiedRequirements
            implicitHeight: requirements.implicitHeight + 32
            radius: 20
            color: config.requirementsModel.satisfiedMandatory ? M3.tertiaryContainer : M3.errorContainer
            readonly property color ink: config.requirementsModel.satisfiedMandatory ? M3.tertiaryContainerContent : M3.errorContainerContent

            ColumnLayout {
                id: requirements
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6
                Repeater {
                    model: config.requirementsModel
                    delegate: RowLayout {
                        required property bool satisfied
                        required property bool mandatory
                        required property string negatedText
                        visible: !satisfied
                        spacing: 10
                        MIcon {
                            size: 20
                            source: mandatory ? "dialog-error" : "dialog-warning"
                            color: requirements.parent.ink
                        }
                        MText {
                            Layout.fillWidth: true
                            role: "bodyMedium"
                            text: negatedText
                            wrapMode: Text.Wrap
                            color: requirements.parent.ink
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    function onActivate() {}
    function onLeave() {}
}
