import QtQuick
import org.kernora.m3

Rectangle {
    id: root

    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property point pressPoint
    property color restingColor: M3.surfaceContainerLow
    property color activeColor: M3.secondaryContainer
    property real corner: 24

    radius: M3.classic ? M3.cornerCard : pressed ? 16 : hovered ? corner + 4 : corner
    color: hovered || focused ? activeColor : restingColor
    border.width: focused ? 2 : 0
    border.color: M3.primary

    Behavior on color {
        ColorAnimation { duration: M3.durationMedium2 }
    }
    Behavior on radius {
        NumberAnimation {
            duration: M3.durationMedium2
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasizedDecelerate
        }
    }

    MStateLayer {
        radius: root.radius
        color: M3.surfaceContent
        hovered: root.hovered
        pressed: root.pressed
        focused: root.focused
        pressPoint: root.pressPoint
    }
}
