import qs.modules.common
import QtQuick
import QtQuick.Layouts

/**
 * Material 3 grouped list: a column of cards split by a hairline gap, shaped so the group still
 * reads as one box. Only the group's outer corners get `outerRadius`; every corner facing a
 * neighbour takes the much smaller `innerRadius`, so the seams read as cuts through one shape
 * rather than as a stack of separate cards.
 *
 * Children must expose the four per-corner radius properties — a Rectangle has them natively
 * and RippleButton forwards them. Hidden children are skipped and the shaping re-runs when one
 * comes or goes, so a conditional row hands its rounded end to its neighbour instead of leaving
 * the group with a flat edge.
 */
ColumnLayout {
    id: root

    property real outerRadius: Appearance.rounding.normal
    property real innerRadius: 4

    spacing: 3

    // Shaped from the group rather than by each child: which corners a row rounds is a fact
    // about its neighbours' visibility, which the row itself cannot see.
    function shapeChildren(): void {
        const shown = [];
        for (let i = 0; i < root.children.length; ++i) {
            if (root.children[i].visible)
                shown.push(root.children[i]);
        }
        for (let i = 0; i < shown.length; ++i) {
            const top = i === 0 ? root.outerRadius : root.innerRadius;
            const bottom = i === shown.length - 1 ? root.outerRadius : root.innerRadius;
            shown[i].topLeftRadius = top;
            shown[i].topRightRadius = top;
            shown[i].bottomLeftRadius = bottom;
            shown[i].bottomRightRadius = bottom;
        }
    }

    Component.onCompleted: {
        for (let i = 0; i < root.children.length; ++i)
            root.children[i].visibleChanged.connect(root.shapeChildren);
        root.shapeChildren();
    }
}
