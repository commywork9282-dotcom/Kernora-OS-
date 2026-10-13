import QtQuick
import org.kernora.m3

ParallelAnimation {
    id: root

    required property Item item
    property int delay: 0
    property real distance: 18
    readonly property Translate offset: Translate { }

    Component.onCompleted: {
        item.transform.push(offset);
        restart();
    }

    SequentialAnimation {
        PropertyAction { target: root.item; property: "opacity"; value: 0 }
        PauseAnimation { duration: M3.motionScale > 0 ? root.delay * M3.motionScale : 0 }
        NumberAnimation {
            target: root.item
            property: "opacity"
            to: 1
            duration: M3.durationMedium4
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasizedDecelerate
        }
    }
    SequentialAnimation {
        PropertyAction { target: root.offset; property: "y"; value: root.distance }
        PauseAnimation { duration: M3.motionScale > 0 ? root.delay * M3.motionScale : 0 }
        NumberAnimation {
            target: root.offset
            property: "y"
            to: 0
            duration: M3.durationLong2
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasizedDecelerate
        }
    }
}
