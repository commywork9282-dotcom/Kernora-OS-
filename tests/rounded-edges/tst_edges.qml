import QtQuick
import QtTest
import "ui" as UI
import "m3" as Material

Rectangle {
    id: scene
    width: 400
    height: 400
    color: "black"
    Component {
        id: avatarFixture
        Rectangle {
            property int side: 52
            color: "black"
            width: side + 8
            height: side + 8
            UI.Avatar {
                x: 4
                y: 4
                size: parent.side
                source: Qt.resolvedUrl("solid.svg")
            }
        }
    }
    Component {
        id: iconFixture
        Rectangle {
            property int side: 40
            color: "black"
            width: side + 8
            height: side + 8
            UI.IconCircle {
                x: 4
                y: 4
                size: parent.side
                icon: "network-wireless"
                containerColor: "white"
                contentColor: "white"
            }
        }
    }
    Component {
        id: svgFixture
        Rectangle {
            property int side: 52
            property alias paintedWidth: icon.paintedWidth
            color: "black"
            width: side + 8
            height: side + 8
            UI.AppIcon {
                id: icon
                x: 4
                y: 4
                size: parent.side
                name: Qt.resolvedUrl("circle.svg").toString()
            }
        }
    }
    Component {
        id: symbolFixture
        Rectangle {
            property int side: 24
            color: "black"
            width: side + 8
            height: side + 8
            Material.MIcon {
                x: 4
                y: 4
                size: parent.side
                source: Qt.resolvedUrl("circle.svg")
                color: "white"
            }
        }
    }
    Component {
        id: launcherFixture
        Rectangle {
            property int side: 44
            color: "black"
            width: side + 8
            height: side + 8
            UI.DrawerTile {
                x: -14
                y: -6
                width: 80
                height: 80
                name: ""
                iconSource: Qt.resolvedUrl("circle.svg")
            }
        }
    }
    Component {
        id: rippleFixture
        Rectangle {
            property int side: 52
            property alias pressed: state.pressed
            color: "black"
            width: side + 8
            height: side + 8
            Item {
                x: 4
                y: 4
                width: parent.side
                height: parent.side
                Material.MStateLayer {
                    id: state
                    radius: width / 2
                    color: "white"
                    pressed: false
                }
            }
        }
    }
    TestCase {
        name: "RoundedEdges"
        when: windowShown
        function test_edges_data() {
            return [
                {tag: "avatar-32", kind: "avatar", side: 32},
                {tag: "avatar-account-card", kind: "avatar", side: 52},
                {tag: "avatar-login", kind: "avatar", side: 104},
                {tag: "icon-circle-40", kind: "icon", side: 40},
                {tag: "icon-circle-52", kind: "icon", side: 52},
                {tag: "app-svg-52", kind: "svg", side: 52},
                {tag: "symbol-svg-24", kind: "symbol", side: 24},
                {tag: "launcher-svg-44", kind: "launcher", side: 44},
                {tag: "icon-ripple-40", kind: "ripple", side: 40},
                {tag: "icon-ripple-52", kind: "ripple", side: 52}
            ];
        }
        function test_edges(data) {
            const component = data.kind === "avatar" ? avatarFixture : data.kind === "icon" ? iconFixture
                : data.kind === "svg" ? svgFixture : data.kind === "symbol" ? symbolFixture
                : data.kind === "launcher" ? launcherFixture : rippleFixture;
            const fixture = createTemporaryObject(component,
                                                  scene, {side: data.side});
            verify(fixture !== null);
            wait(100);
            if (data.kind === "ripple")
                fixture.pressed = true;
            wait(700);
            if (data.kind === "svg")
                compare(fixture.paintedWidth, data.side, "SVG painted size does not match the requested size");
            const image = grabImage(fixture);
            image.save(Qt.resolvedUrl("capture-" + data.tag + ".png").toString().replace(/^file:\/\//, ""));
            const scale = image.width / fixture.width;
            const centreX = image.width / 2;
            const centreY = image.height / 2;
            const svg = data.kind === "svg" || data.kind === "symbol" || data.kind === "launcher";
            const radius = data.side * scale / 2 * (svg ? 22 / 24 : 1);
            const centre = image.red(Math.floor(centreX), Math.floor(centreY));
            verify(centre > 16, "The masked content did not render");
            let partial = 0;
            let outside = 0;
            for (let y = 0; y < image.height; ++y) {
                for (let x = 0; x < image.width; ++x) {
                    const distance = Math.hypot(x + 0.5 - centreX, y + 0.5 - centreY);
                    const value = image.red(x, y);
                    if (Math.abs(distance - radius) < 2 * scale && value > 2 && value < centre - 2)
                        ++partial;
                    if (distance > radius + 2 * scale && value > 2)
                        ++outside;
                }
            }
            console.log(data.tag, "capture scale", scale, "size", image.width, image.height,
                        "fixture", fixture.width, fixture.height, "partial edge pixels", partial);
            verify(partial > data.side * scale * 0.5,
                   "The circular edge lost antialiasing: " + partial + " partial pixels");
            compare(outside, 0, "The image or ripple leaked outside its circular mask");
            compare(image.red(0, 0), 0);
        }
        function test_repeated_press() {
            const fixture = createTemporaryObject(rippleFixture, scene, {side: 52});
            verify(fixture !== null);
            wait(100);
            for (let press = 0; press < 2; ++press) {
                fixture.pressed = true;
                wait(700);
                let image = grabImage(fixture);
                verify(image.red(Math.floor(image.width / 2), Math.floor(image.height / 2)) > 16,
                       "The press effect did not appear on press " + (press + 1));
                fixture.pressed = false;
                wait(800);
                image = grabImage(fixture);
                compare(image.red(Math.floor(image.width / 2), Math.floor(image.height / 2)), 0,
                        "The press effect remained after release");
            }
        }
    }
}
