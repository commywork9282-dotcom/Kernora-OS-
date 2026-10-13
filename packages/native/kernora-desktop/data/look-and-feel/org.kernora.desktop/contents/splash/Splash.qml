import QtQuick

Rectangle {
    id: root
    color: "#181210"

    property int stage

    onStageChanged: {
        if (stage == 5) {
            outroAnimation.running = true;
        }
    }

    Item {
        id: content
        anchors.fill: parent

        Image {
            id: logo
            readonly property real size:
                Math.round(Math.min(root.width, root.height) * 0.22)

            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Math.round(root.height * 0.04)

            source: "images/kernora.png"
            sourceSize.width: size
            sourceSize.height: size
            width: size
            height: size
            smooth: true

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 6000
                loops: Animation.Infinite
                running: true
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: logo.bottom
            anchors.topMargin: Math.round(root.height * 0.06)
            text: "Kernora OS"
            color: "#ede0dc"
            font.family: "Google Sans Flex"
            font.pixelSize: Math.round(root.height * 0.028)
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
