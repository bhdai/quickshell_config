import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import "ButtonGroupLayout.js" as ButtonGroupLayout

/**
 * A container that displays buttons with equal widths and bouncy interactions.
 *
 * Holding a button grows it and shrinks only its two neighbours, at a fixed row width.
 * Children read their allocated width from `buttonWidths` (indexed by child order) and
 * report a press by writing their own index to `clickIndex`, or -1 on release —
 * `GroupButton` does both.
 */
Rectangle {
    id: root
    default property alias data: rowLayout.data
    property real spacing: 5
    property real padding: 0
    property alias clickIndex: rowLayout.clickIndex
    property alias visibleChildCount: rowLayout.visibleChildCount

    topLeftRadius: 12
    bottomLeftRadius: 12
    topRightRadius: 12
    bottomRightRadius: 12

    color: "transparent"
    implicitHeight: 50 + padding * 2

    children: [
        RowLayout {
            id: rowLayout
            anchors.fill: parent
            anchors.margins: root.padding
            spacing: root.spacing

            property int clickIndex: -1

            property int visibleChildCount: {
                let count = 0;
                for (let i = 0; i < children.length; ++i) {
                    if (children[i].visible)
                        count++;
                }
                return count;
            }

            // How much the held button asks to gain, taken from the button itself so each
            // kind of button keeps owning its own press expression.
            readonly property real pressGrowth: {
                if (clickIndex < 0 || clickIndex >= children.length)
                    return 0;
                const pressed = children[clickIndex];
                return Math.max(0, (pressed.clickedWidth ?? 0) - (pressed.baseWidth ?? 0));
            }

            readonly property var buttonWidths: {
                const visibility = [];
                for (let i = 0; i < children.length; ++i)
                    visibility.push(children[i].visible);
                return ButtonGroupLayout.allocateWidths(visibility, width, spacing, clickIndex, pressGrowth);
            }
        }
    ]
}
