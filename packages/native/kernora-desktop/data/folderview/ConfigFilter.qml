/*
    SPDX-FileCopyrightText: 2014 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.private.desktopcontainment.folder as Folder
import org.kde.kitemmodels as KItemModels
import org.kernora.m3
import org.kernora.ui as UI

Item {
    id: configIcons

    property int cfg_filterMode
    property alias cfg_filterPattern: filterPattern.text
    property alias cfg_filterMimeTypes: mimeTypesModel.checkedTypes
    property bool cfg_showHiddenFiles

    readonly property bool filtering: cfg_filterMode > 0

    implicitHeight: content.implicitHeight + 24

    function plain(text: string): string {
        return text.replace(/\s*[:：]\s*$/, "");
    }

    KItemModels.KSortFilterProxyModel {
        id: filteredMimeTypesModel

        sourceModel: Folder.MimeTypesModel {
            id: mimeTypesModel
        }

        filterRegularExpression: RegExp(mimeFilter.text, "i")
        filterRoleName: "name"

        sortRoleName: "name"
        sortOrder: Qt.AscendingOrder

        function checkFiltered() {
            var types = [];

            for (var i = 0; i < count; ++i) {
                types.push(get(i).name);
            }

            mimeTypesModel.checkedTypes = types;
        }

        function uncheckFiltered() {
            var types = [];

            for (var i = 0; i < count; ++i) {
                types.push(get(i).name);
            }

            mimeTypesModel.checkedTypes = mimeTypesModel.checkedTypes
                .filter(x => types.indexOf(x) === -1);
        }
    }

    ColumnLayout {
        id: content
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 20

        UI.Group {
            Layout.fillWidth: true
            title: configIcons.plain(i18n("Files:"))

            Repeater {
                model: [i18n("Show all"), i18n("Show matching"), i18n("Hide matching")]
                delegate: UI.RadioRow {
                    width: parent ? parent.width : implicitWidth
                    required property int index
                    required property string modelData
                    title: modelData
                    checked: configIcons.cfg_filterMode === index
                    onClicked: configIcons.cfg_filterMode = index
                }
            }
        }

        UI.InputField {
            id: filterPattern
            Layout.fillWidth: true
            visible: configIcons.filtering
            label: configIcons.plain(i18n("File name pattern:"))
            input.inputMethodHints: Qt.ImhNoPredictiveText
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: configIcons.filtering

            MText {
                Layout.leftMargin: 16
                role: "titleSmall"
                color: M3.primary
                text: configIcons.plain(i18n("File types:"))
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: typesLayout.implicitHeight + 24
                radius: M3.classic ? M3.cornerCard : 20
                color: M3.surfaceContainer

                ColumnLayout {
                    id: typesLayout
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 12
                    }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        UI.SearchField {
                            id: mimeFilter
                            Layout.fillWidth: true
                            placeholderText: i18nd("kernora-ui", "Search")
                        }
                        UI.IconButton {
                            iconName: "edit-select-all"
                            text: i18n("Select All")
                            onClicked: filteredMimeTypesModel.checkFiltered()
                        }
                        UI.IconButton {
                            iconName: "edit-select-none"
                            text: i18n("Deselect All")
                            onClicked: filteredMimeTypesModel.uncheckFiltered()
                        }
                        UI.IconButton {
                            iconName: filteredMimeTypesModel.sortOrder === Qt.AscendingOrder ? "view-sort-ascending-symbolic" : "view-sort-descending-symbolic"
                            text: i18n("Switch Sort Order")
                            onClicked: {
                                filteredMimeTypesModel.sortOrder = filteredMimeTypesModel.sortOrder === Qt.AscendingOrder ? Qt.DescendingOrder : Qt.AscendingOrder;
                                filteredMimeTypesModel.sort(0, filteredMimeTypesModel.sortOrder);
                            }
                        }
                    }

                    ListView {
                        id: mimeTypesView
                        Layout.fillWidth: true
                        Layout.preferredHeight: 360
                        clip: true
                        reuseItems: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: filteredMimeTypesModel

                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                        delegate: Item {
                            id: delegate
                            required property string name
                            required property string comment
                            required property var decoration
                            readonly property bool checked: mimeTypesModel.checkedTypes.indexOf(name) >= 0

                            width: mimeTypesView.width
                            height: 56

                            function toggle(): void {
                                const types = mimeTypesModel.checkedTypes.slice();
                                const idx = types.indexOf(name);
                                if (idx >= 0) {
                                    types.splice(idx, 1);
                                } else {
                                    types.push(name);
                                }
                                mimeTypesModel.checkedTypes = types;
                            }

                            MStateLayer {
                                anchors.fill: parent
                                radius: 12
                                hovered: rowMouse.containsMouse
                                pressed: rowMouse.pressed
                            }
                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: delegate.toggle()
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 12
                                spacing: 12

                                QQC2.CheckBox {
                                    checked: delegate.checked
                                    onToggled: delegate.toggle()
                                }
                                Kirigami.Icon {
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    animated: false
                                    source: delegate.decoration
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    MText {
                                        Layout.fillWidth: true
                                        role: "bodyLarge"
                                        text: delegate.comment || delegate.name
                                        elide: Text.ElideRight
                                    }
                                    MText {
                                        Layout.fillWidth: true
                                        role: "bodySmall"
                                        color: M3.surfaceVariantContent
                                        text: delegate.name
                                        elide: Text.ElideRight
                                        visible: delegate.comment.length > 0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        UI.Group {
            Layout.fillWidth: true

            UI.ListItem {
                title: configIcons.plain(i18n("Show hidden files:"))
                checkable: true
                checked: configIcons.cfg_showHiddenFiles
                onToggled: checked => configIcons.cfg_showHiddenFiles = checked
            }
        }
    }
}
