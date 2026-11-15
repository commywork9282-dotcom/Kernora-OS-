/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kernora.m3

PlasmaCore.Dialog {
    id: window

    property rect area: Qt.rect(0, 0, 0, 0)
    readonly property bool away: scene.launching

    signal widgetsRequested()

    type: PlasmaCore.Dialog.AppletPopup
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
    visible: false

    x: area.x
    y: area.y

    function openAt(point: point): void {
        scene.openAt(point);
    }

    onActiveChanged: {
        if (active) {
            return;
        }
        if (scene.launching) {
            scene.settingsShown();
        } else {
            scene.dismiss();
        }
    }

    mainItem: Item {
        id: scene

        readonly property real itemWidth: 216
        readonly property real itemHeight: 52
        readonly property real gap: 2
        readonly property real outerRadius: 28
        readonly property real innerRadius: 4
        readonly property real iconSize: 20
        readonly property real iconStart: 16
        readonly property real textStart: 54
        readonly property real textEnd: 14
        readonly property real thumb: 32
        readonly property real arrowCenter: 26
        readonly property real arrowSpace: 13
        readonly property bool rtl: Qt.application.layoutDirection === Qt.RightToLeft

        readonly property var options: [
            { label: i18nd("kernora-ui", "Wallpaper & style"), icon: "preferences-desktop-color", page: "appearance" },
            { label: i18nd("kernora-ui", "Widgets"), icon: "preferences-desktop-widgets", page: "" },
            { label: i18nd("kernora-ui", "Home settings"), icon: "configure", page: "home" }
        ]

        property bool menuOpen: false
        property bool leftAligned: true
        property bool above: true
        property bool keyboardUsed: false
        property int focusIndex: -1
        property real menuScale: 1
        property real contentOpacity: 1

        property bool launching: false
        property bool shown: false

        width: window.area.width
        height: window.area.height

        P5Support.DataSource {
            id: executable
            engine: "executable"
            onNewData: sourceName => disconnectSource(sourceName)
        }

        function ms(value: real): int {
            return Math.max(1, Math.round(value * M3.motionScale));
        }

        function place(point: point): void {
            const count = options.length;
            const measured = count * itemHeight;
            const margins = (count - 1) * gap;
            const half = thumb / 2;
            const left = point.x - half;
            const top = point.y - half;
            const right = point.x + half;
            const offset = thumb / 2 - arrowCenter;
            let height = measured + arrowSpace + margins;

            let leftFirst = !rtl;
            let x = leftFirst ? left + offset : right - itemWidth - offset;
            let centreH = false;
            const fitsLeft = left + offset + itemWidth < scene.width;
            const fitsRight = right - itemWidth - offset > 0;
            if (leftFirst ? !fitsLeft : !fitsRight) {
                leftFirst = !leftFirst;
                x = leftFirst ? left + offset : right - itemWidth - offset;
                centreH = leftFirst ? !fitsLeft : !fitsRight;
            }

            let y = top - height;
            let isAbove = y > 0;
            if (!isAbove) {
                y = top + thumb + arrowSpace;
                height -= arrowSpace;
            }

            let menuY = isAbove ? y - margins : y;
            if (y + height > scene.height) {
                const rightSide = left + thumb;
                const leftSide = right - itemWidth - thumb;
                if (!rtl) {
                    leftFirst = rightSide + itemWidth < scene.width;
                    x = leftFirst ? rightSide : leftSide;
                } else {
                    leftFirst = !(leftSide > 0);
                    x = leftFirst ? rightSide : leftSide;
                }
                isAbove = true;
                menuY = scene.height / 2 - (measured + margins) / 2;
            }
            if (centreH || x < 0 || x + itemWidth > scene.width) {
                x = scene.width / 2 - itemWidth / 2;
            }

            leftAligned = leftFirst;
            above = isAbove;
            menu.x = Math.round(x);
            menu.y = Math.round(menuY);
        }

        function openAt(point: point): void {
            if (launching || closeAnimation.running) {
                return;
            }
            card.visible = false;
            place(point);
            keyboardUsed = false;
            focusIndex = -1;
            menuOpen = true;
            menuScale = 0.5;
            menu.opacity = 0;
            contentOpacity = 0;
            window.visible = true;
            window.requestActivate();
            scene.forceActiveFocus();
            openAnimation.restart();
        }

        function dismiss(): void {
            if (!menuOpen || launching) {
                return;
            }
            menuOpen = false;
            openAnimation.stop();
            closeAnimation.restart();
        }

        function activate(index: int): void {
            if (!menuOpen || launching) {
                return;
            }
            const option = options[index];
            if (!option) {
                return;
            }
            if (option.page.length === 0) {
                dismiss();
                window.widgetsRequested();
                return;
            }
            launch(index, option.page);
        }

        function launch(index: int, page: string): void {
            const row = rows.itemAt(index);
            const glyph = row.glyph.mapToItem(scene, 0, 0, row.glyph.width, row.glyph.height);
            shown = false;
            launching = true;
            menuOpen = false;
            openAnimation.stop();
            closeAnimation.restart();

            card.startX = glyph.x + glyph.width / 2;
            card.startY = glyph.y + glyph.height / 2;
            card.startSize = glyph.width;
            card.icon = options[index].icon;
            card.progress = 0;
            card.xProgress = 0;
            card.fill = 0;
            card.glyphOpacity = 1;
            card.splash = 0;
            card.opacity = 1;
            card.visible = true;
            cardAnimation.restart();
            splashTimer.restart();
            fallbackTimer.restart();
            executable.connectSource("kernora-settings --fullscreen " + page + " >/dev/null 2>&1 &");
        }

        function settingsShown(): void {
            shown = true;
            if (!cardAnimation.running) {
                revealTimer.restart();
            }
        }

        function reveal(): void {
            if (!card.visible || revealAnimation.running) {
                return;
            }
            fallbackTimer.stop();
            splashTimer.stop();
            revealAnimation.restart();
        }

        function finishLaunch(): void {
            card.visible = false;
            launching = false;
            window.visible = false;
        }

        Keys.onPressed: event => {
            if (launching && !cardAnimation.running && event.key === Qt.Key_Escape) {
                reveal();
                event.accepted = true;
                return;
            }
            if (!menuOpen) {
                return;
            }
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
                dismiss();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                keyboardUsed = true;
                focusIndex = (focusIndex + 1) % options.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                keyboardUsed = true;
                focusIndex = focusIndex <= 0 ? options.length - 1 : focusIndex - 1;
                event.accepted = true;
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                       && focusIndex >= 0) {
                activate(focusIndex);
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            enabled: scene.menuOpen
            onPressed: mouse => {
                mouse.accepted = true;
                scene.dismiss();
            }
        }

        Item {
            id: menu

            width: scene.itemWidth
            height: column.implicitHeight
            visible: scene.menuOpen || closeAnimation.running
            opacity: 0

            transform: Scale {
                origin.x: scene.leftAligned ? scene.arrowCenter : scene.itemWidth - scene.arrowCenter
                origin.y: scene.above ? menu.height : 0
                xScale: scene.menuScale
                yScale: scene.menuScale
            }

            Column {
                id: column
                spacing: scene.gap

                Repeater {
                    id: rows
                    model: scene.options

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool first: index === 0
                        readonly property bool last: index === scene.options.length - 1
                        readonly property real topRadius: first ? scene.outerRadius : scene.innerRadius
                        readonly property real bottomRadius: last ? scene.outerRadius : scene.innerRadius
                        readonly property alias glyph: glyph

                        width: scene.itemWidth
                        height: scene.itemHeight

                        Kirigami.ShadowedRectangle {
                            anchors.fill: parent
                            color: M3.surfaceContainer
                            corners.topLeftRadius: row.topRadius
                            corners.topRightRadius: row.topRadius
                            corners.bottomLeftRadius: row.bottomRadius
                            corners.bottomRightRadius: row.bottomRadius
                            shadow.size: 6
                            shadow.yOffset: 1
                            shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.32 : 0.14)
                        }

                        MStateLayer {
                            topLeftRadius: row.topRadius
                            topRightRadius: row.topRadius
                            bottomLeftRadius: row.bottomRadius
                            bottomRightRadius: row.bottomRadius
                            color: M3.surfaceContent
                            hovered: pointer.containsMouse
                            pressed: pointer.pressed
                            focused: scene.keyboardUsed && scene.focusIndex === row.index
                            pressPoint: Qt.point(pointer.mouseX, pointer.mouseY)
                        }

                        Item {
                            anchors.fill: parent
                            opacity: scene.contentOpacity

                            MIcon {
                                id: glyph
                                x: scene.rtl ? parent.width - scene.iconStart - width : scene.iconStart
                                anchors.verticalCenter: parent.verticalCenter
                                size: scene.iconSize
                                source: row.modelData.icon
                                color: M3.surfaceContent
                            }

                            MText {
                                x: scene.rtl ? scene.textEnd : scene.textStart
                                width: parent.width - scene.textStart - scene.textEnd
                                anchors.verticalCenter: parent.verticalCenter
                                role: "bodyMedium"
                                text: row.modelData.label
                                color: M3.surfaceContent
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                horizontalAlignment: Text.AlignLeft
                            }
                        }

                        MouseArea {
                            id: pointer
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            onClicked: scene.activate(row.index)
                        }

                        Accessible.role: Accessible.MenuItem
                        Accessible.name: row.modelData.label
                    }
                }
            }
        }

        ParallelAnimation {
            id: openAnimation

            SequentialAnimation {
                NumberAnimation {
                    target: scene
                    property: "menuScale"
                    from: 0.5
                    to: 1.02
                    duration: scene.ms(200)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
                }
                NumberAnimation {
                    target: scene
                    property: "menuScale"
                    from: 1.02
                    to: 1
                    duration: scene.ms(200)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: [0.3, 0, 0.33, 1, 1, 1]
                }
            }
            NumberAnimation {
                target: menu
                property: "opacity"
                from: 0
                to: 1
                duration: scene.ms(83)
            }
            NumberAnimation {
                target: scene
                property: "contentOpacity"
                from: 0
                to: 1
                duration: scene.ms(83)
            }
        }

        ParallelAnimation {
            id: closeAnimation

            NumberAnimation {
                target: scene
                property: "menuScale"
                to: 0.5
                duration: scene.ms(233)
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: scene.ms(150)
                }
                NumberAnimation {
                    target: menu
                    property: "opacity"
                    to: 0
                    duration: scene.ms(83)
                }
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: scene.ms(150)
                }
                NumberAnimation {
                    target: scene
                    property: "contentOpacity"
                    to: 0
                    duration: scene.ms(83)
                }
            }

            onFinished: {
                if (!scene.launching && !scene.menuOpen) {
                    window.visible = false;
                }
            }
        }

        Rectangle {
            id: card

            property real startX: 0
            property real startY: 0
            property real startSize: 20
            property real progress: 0
            property real xProgress: 0
            property real fill: 0
            property real glyphOpacity: 1
            property real splash: 0
            property string icon: ""

            readonly property real centreX: startX + (scene.width / 2 - startX) * xProgress
            readonly property real centreY: startY + (scene.height / 2 - startY) * progress

            visible: false
            width: startSize + (scene.width - startSize) * progress
            height: startSize + (scene.height - startSize) * progress
            x: centreX - width / 2
            y: centreY - height / 2
            radius: (startSize / 2) * (1 - progress)
            color: Qt.alpha(M3.surface, fill)
            antialiasing: true

            MIcon {
                anchors.centerIn: parent
                size: Math.min(parent.width, parent.height)
                source: card.icon
                color: M3.surfaceContent
                opacity: card.glyphOpacity
                visible: opacity > 0
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: 128
                height: 128
                source: "org.kernora.settings"
                opacity: card.splash
                visible: opacity > 0
                animated: false
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                enabled: scene.launching && card.splash > 0
                onPressed: scene.reveal()
            }
        }

        ParallelAnimation {
            id: cardAnimation

            NumberAnimation {
                target: card
                property: "progress"
                from: 0
                to: 1
                duration: scene.ms(500)
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.05, 0, 0.133333, 0.06, 0.166666, 0.4, 0.208333, 0.82, 0.25, 1, 1, 1]
            }
            NumberAnimation {
                target: card
                property: "xProgress"
                from: 0
                to: 1
                duration: scene.ms(500)
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.1217, 0.0462, 0.15, 0.4686, 0.1667, 0.66, 0.1834, 0.8878, 0.1667, 1, 1, 1]
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: scene.ms(25)
                }
                NumberAnimation {
                    target: card
                    property: "fill"
                    from: 0
                    to: 1
                    duration: scene.ms(50)
                }
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: scene.ms(25)
                }
                NumberAnimation {
                    target: card
                    property: "glyphOpacity"
                    from: 1
                    to: 0
                    duration: scene.ms(50)
                }
            }

            onFinished: {
                if (scene.shown) {
                    revealTimer.restart();
                }
            }
        }

        SequentialAnimation {
            id: revealAnimation

            NumberAnimation {
                target: card
                property: "opacity"
                to: 0
                duration: scene.ms(150)
            }
            ScriptAction {
                script: scene.finishLaunch()
            }
        }

        Timer {
            id: revealTimer
            interval: 250
            onTriggered: scene.reveal()
        }

        Timer {
            id: splashTimer
            interval: 700
            onTriggered: splashFade.restart()
        }

        NumberAnimation {
            id: splashFade
            target: card
            property: "splash"
            to: 1
            duration: scene.ms(150)
        }

        Timer {
            id: fallbackTimer
            interval: 15000
            onTriggered: scene.reveal()
        }
    }
}
