import QtQuick
import QtQuick.Shapes

// A photograph with rounded corners, drawn without any masking primitive.
//
// The real picker should use Quickshell.Widgets' ClippingRectangle. This exists only
// because none of the masking primitives survive an offscreen grab — ClippingRectangle,
// a Qt5Compat OpacityMask layer.effect and a QtQuick.Effects MultiEffect all render
// nothing under QT_QPA_PLATFORM=offscreen, so a spike built on any of them would produce
// screenshots with no wallpapers in them. Shape does render, so the corners are painted
// over in the surrounding colour instead of being clipped out.
Item {
    id: root

    property alias source: image.source
    property real radius: 12
    // What the corners are painted with. A cut-out only looks like a cut-out against the
    // colour actually behind the cell.
    property color surround: "black"

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        clip: true

        Image {
            anchors.fill: parent
            id: image
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: root.width * 2
            sourceSize.height: root.height * 2
            asynchronous: true
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillRule: ShapePath.OddEvenFill
            fillColor: root.surround
            strokeWidth: 0
            strokeColor: "transparent"

            startX: 0
            startY: 0
            PathLine {
                x: root.width
                y: 0
            }
            PathLine {
                x: root.width
                y: root.height
            }
            PathLine {
                x: 0
                y: root.height
            }
            PathLine {
                x: 0
                y: 0
            }

            PathMove {
                x: root.radius
                y: 0
            }
            PathLine {
                x: root.width - root.radius
                y: 0
            }
            PathArc {
                x: root.width
                y: root.radius
                radiusX: root.radius
                radiusY: root.radius
                direction: PathArc.Clockwise
            }
            PathLine {
                x: root.width
                y: root.height - root.radius
            }
            PathArc {
                x: root.width - root.radius
                y: root.height
                radiusX: root.radius
                radiusY: root.radius
                direction: PathArc.Clockwise
            }
            PathLine {
                x: root.radius
                y: root.height
            }
            PathArc {
                x: 0
                y: root.height - root.radius
                radiusX: root.radius
                radiusY: root.radius
                direction: PathArc.Clockwise
            }
            PathLine {
                x: 0
                y: root.radius
            }
            PathArc {
                x: root.radius
                y: 0
                radiusX: root.radius
                radiusY: root.radius
                direction: PathArc.Clockwise
            }
        }
    }
}
