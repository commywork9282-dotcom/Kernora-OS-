/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.kicker as Kicker
import "m3"

Flickable {
    id: root

    property QtObject launcher: null
    property string query
    property int columns: 6
    property real cellWidth: 104
    property int currentIndex: 0

    signal launched()
    signal searchWeb(string text)
    signal searchStore(string text)

    readonly property bool active: query.length > 0
    readonly property var apps: appsRunner.count > 0 ? appsRunner.modelForRow(0) : null
    readonly property var answers: calcRunner.count > 0 ? calcRunner.modelForRow(0) : null
    readonly property var settings: settingsRunner.count > 0 ? settingsRunner.modelForRow(0) : null
    readonly property var files: filesRunner.count > 0 ? filesRunner.modelForRow(0) : null

    readonly property int appCount: apps ? Math.min(columns, apps.count) : 0
    readonly property int answerCount: answers ? Math.min(3, answers.count) : 0
    readonly property int settingCount: settings ? Math.min(5, settings.count) : 0
    readonly property int fileCount: files ? Math.min(6, files.count) : 0

    readonly property int answerOffset: appCount
    readonly property int webIndex: answerOffset + answerCount
    readonly property int settingOffset: webIndex + 1
    readonly property int fileOffset: settingOffset + settingCount
    readonly property int storeIndex: fileOffset + fileCount
    readonly property int total: storeIndex + 1

    contentWidth: width
    contentHeight: column.implicitHeight + 24
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    onQueryChanged: {
        currentIndex = 0;
        contentY = 0;
    }

    function move(step: int): void {
        currentIndex = Math.max(0, Math.min(total - 1, currentIndex + step));
    }

    function trigger(model: var, row: int): void {
        if (model && row >= 0 && model.trigger(row, "", null)) {
            root.launched();
        }
    }

    function activate(index: int): void {
        if (index < appCount) {
            trigger(apps, index);
        } else if (index < webIndex) {
            trigger(answers, index - answerOffset);
        } else if (index === webIndex) {
            root.searchWeb(query);
        } else if (index < fileOffset) {
            trigger(settings, index - settingOffset);
        } else if (index < storeIndex) {
            trigger(files, index - fileOffset);
        } else {
            root.searchStore(query);
        }
    }

    function reveal(item: Item): void {
        const point = item.mapToItem(column, 0, 0);
        if (point.y < contentY) {
            contentY = Math.max(0, point.y - 8);
        } else if (point.y + item.height > contentY + height) {
            contentY = Math.min(contentHeight - height, point.y + item.height - height + 8);
        }
    }

    Kicker.RunnerModel {
        id: appsRunner
        appletInterface: root.launcher
        runners: ["krunner_services"]
        mergeResults: true
        query: root.query
    }
    Kicker.RunnerModel {
        id: calcRunner
        appletInterface: root.launcher
        runners: ["calculator", "unitconverter"]
        mergeResults: true
        query: root.query
    }
    Kicker.RunnerModel {
        id: settingsRunner
        appletInterface: root.launcher
        runners: ["org.kernora.settings"]
        mergeResults: true
        query: root.query
    }
    Kicker.RunnerModel {
        id: filesRunner
        appletInterface: root.launcher
        runners: ["baloosearch", "krunner_recentdocuments", "locations"]
        mergeResults: true
        query: root.query
    }

    component Heading: MText {
        leftPadding: 16
        topPadding: 4
        bottomPadding: 4
        role: "titleSmall"
        color: M3.surfaceVariantContent
    }

    Column {
        id: column
        x: 16
        width: root.width - 32
        topPadding: 16
        spacing: 2

        Row {
            visible: root.appCount > 0
            bottomPadding: 10

            Repeater {
                model: root.apps

                delegate: DrawerTile {
                    id: appTile
                    required property int index
                    required property var model
                    visible: index < root.columns
                    width: root.cellWidth
                    height: 108
                    name: model.display ?? ""
                    iconSource: model.decoration ?? ""
                    current: root.currentIndex === index
                    onCurrentChanged: if (current) root.reveal(appTile)
                    onClicked: root.trigger(root.apps, index)
                }
            }
        }

        Repeater {
            model: root.answers

            delegate: DrawerResultRow {
                id: answerRow
                required property int index
                required property var model
                visible: index < root.answerCount
                width: column.width
                title: model.display ?? ""
                subtitle: model.description ?? ""
                iconSource: model.decoration ?? ""
                first: index === 0
                last: index === root.answerCount - 1
                current: root.currentIndex === root.answerOffset + index
                onCurrentChanged: if (current) root.reveal(answerRow)
                onClicked: root.trigger(root.answers, index)
            }
        }

        Item {
            width: 1
            height: 10
            visible: root.answerCount > 0
        }

        DrawerResultRow {
            id: webRow
            width: parent.width
            title: root.query
            subtitle: i18n("Search the web")
            iconSource: "librewolf"
            current: root.currentIndex === root.webIndex
            onCurrentChanged: if (current) root.reveal(webRow)
            onClicked: root.searchWeb(root.query)
        }

        Heading {
            visible: root.settingCount > 0
            topPadding: 14
            text: i18n("Settings")
        }

        Repeater {
            model: root.settings

            delegate: DrawerResultRow {
                id: settingRow
                required property int index
                required property var model
                visible: index < root.settingCount
                width: column.width
                title: model.display ?? ""
                subtitle: model.description ?? ""
                iconSource: model.decoration ?? ""
                first: index === 0
                last: index === root.settingCount - 1
                current: root.currentIndex === root.settingOffset + index
                onCurrentChanged: if (current) root.reveal(settingRow)
                onClicked: root.trigger(root.settings, index)
            }
        }

        Heading {
            visible: root.fileCount > 0
            topPadding: 14
            text: i18n("Files")
        }

        Repeater {
            model: root.files

            delegate: DrawerResultRow {
                id: fileRow
                required property int index
                required property var model
                visible: index < root.fileCount
                width: column.width
                title: model.display ?? ""
                subtitle: model.description ?? ""
                iconSource: model.decoration ?? ""
                first: index === 0
                last: index === root.fileCount - 1
                current: root.currentIndex === root.fileOffset + index
                onCurrentChanged: if (current) root.reveal(fileRow)
                onClicked: root.trigger(root.files, index)
            }
        }

        Item {
            width: 1
            height: 12
        }

        DrawerResultRow {
            id: storeRow
            width: parent.width
            title: i18n("Search for “%1” in Store", root.query)
            iconSource: "org.kernora.store"
            current: root.currentIndex === root.storeIndex
            onCurrentChanged: if (current) root.reveal(storeRow)
            onClicked: root.searchStore(root.query)
        }
    }
}
