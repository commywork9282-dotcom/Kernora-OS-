import QtQuick
import org.kde.kirigami as Kirigami
import org.kernora.m3

Rectangle {
    id: root
    color: M3.surface

    property int stage

    onStageChanged: {
        if (stage == 5) {
            outroAnimation.running = true;
        }
    }

    Item {
        id: content
        anchors.fill: parent

        Kirigami.Icon {
            id: logo
            readonly property real size: Math.round(Math.min(root.width, root.height) * 0.14)

            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Math.round(root.height * 0.04)
            width: size
            height: size
            source: Qt.resolvedUrl("images/kernora.png")
            isMask: true
            color: M3.surfaceContent
        }

        MCircularProgress {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: logo.bottom
            anchors.topMargin: Math.round(root.height * 0.06)
            width: Math.round(logo.size * 0.5)
            height: width
            running: true
        }
    }

    OpacityAnimator {
        id: outroAnimation
        target: content
        from: 1
        to: 0
        duration: 400
        running: false
    }
}
