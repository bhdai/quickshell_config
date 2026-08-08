import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property var line1: []
    property var line2: []
    property real maximum: 1
    property int historyLength: 24
    property real slideProgress: 1
    property bool smoothScroll: true
    property bool fillUnderLine: true
    property color line1Color: "transparent"
    property color line2Color: "transparent"
    property real line1FillAlpha: 0.18
    property real line2FillAlpha: 0.12
    property int geometryUpdateCount: 0

    function points(values) {
        if (values.length < 2)
            return [];

        const step = width / (historyLength - 1);
        const progress = smoothScroll ? slideProgress : 1;
        const startX = width - (values.length - 1) * step - step * progress + step;
        return values.map((value, index) => Qt.point(
            startX + index * step,
            height - 3 - Math.max(0, Math.min(1, value / maximum)) * (height - 6)
        ));
    }

    function fillPoints(values) {
        const path = points(values);
        if (path.length < 2 || !fillUnderLine)
            return [];
        return path.concat([
            Qt.point(path[path.length - 1].x, height),
            Qt.point(path[0].x, height),
            path[0]
        ]);
    }

    onLine1Changed: geometryUpdateCount++
    onLine2Changed: geometryUpdateCount++
    onMaximumChanged: geometryUpdateCount++
    onSlideProgressChanged: {
        if (smoothScroll)
            geometryUpdateCount++;
    }

    Shape {
        anchors.fill: parent

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.fillUnderLine ? Qt.rgba(root.line1Color.r, root.line1Color.g, root.line1Color.b, root.line1FillAlpha) : "transparent"

            PathPolyline {
                path: root.fillPoints(root.line1)
            }
        }

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.fillUnderLine ? Qt.rgba(root.line2Color.r, root.line2Color.g, root.line2Color.b, root.line2FillAlpha) : "transparent"

            PathPolyline {
                path: root.fillPoints(root.line2)
            }
        }

        ShapePath {
            strokeColor: root.line1Color
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: root.points(root.line1)
            }
        }

        ShapePath {
            strokeColor: root.line2Color
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: root.points(root.line2)
            }
        }
    }
}
