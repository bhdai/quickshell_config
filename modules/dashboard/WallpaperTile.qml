import QtQuick
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "dashboard_metrics.js" as Metrics

/**
 * One library thumbnail. Clicking it takes focus and asks the Wallpaper service to apply
 * `path`; the popup stays open and focus stays here.
 *
 * Applied is read back from what the service committed, never from what this tile asked
 * for. A tile that painted itself applied on click would be lying for as long as the decode
 * takes, and would go on lying if the decode failed.
 */
Item {
    id: root

    required property int tileIndex
    required property string path

    signal focusClaimed(int tileIndex, string tilePath)
    signal moveRequested(string direction)
    signal tabRequested()

    readonly property bool applied: root.path.length > 0 && root.path === Wallpaper.wallpaper
    readonly property bool pending: root.path.length > 0 && root.path === Wallpaper.pendingPath

    // Set rather than implied: a row the library only half fills must leave the rest of that
    // row empty rather than stretch the cells it does have.
    width: Metrics.CELL_W
    height: Metrics.CELL_H

    function activate(): void {
        Wallpaper.set(root.path);
    }

    onActiveFocusChanged: {
        if (root.activeFocus)
            root.focusClaimed(root.tileIndex, root.path);
    }

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
            root.moveRequested("left");
            break;
        case Qt.Key_Right:
            root.moveRequested("right");
            break;
        case Qt.Key_Up:
            root.moveRequested("up");
            break;
        case Qt.Key_Down:
            root.moveRequested("down");
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root.activate();
            break;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            root.tabRequested();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        // Shows through until the decode lands, and stays visible behind an image whose
        // aspect leaves the cell short of a full cover.
        color: Appearance.colors.colLayer2

        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl(root.path)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // Both dimensions set, so a 5K JPEG costs a cell-sized texture instead of its
            // full one, sixteen of them at a time. Doubled because the cell is small enough
            // that a texel per logical pixel reads as soft on a scaled output.
            sourceSize.width: Metrics.CELL_W * 2
            sourceSize.height: Metrics.CELL_H * 2
        }

        Rectangle {
            anchors.fill: parent
            // The opaque base rather than the layer role: the palette's own transparency
            // would otherwise compound with this scrim's, and a scrim's job is to dim by a
            // known amount.
            color: Appearance.colors.colLayer0Base
            opacity: root.pending ? 0.55 : pointer.containsMouse ? 0.2 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: root.pending
            text: "hourglass_empty"
            iconSize: 24
            color: Appearance.colors.colOnLayer0
        }
    }

    // The committed wallpaper. #96 allows it to be absent from the library entirely, so this
    // is a ring a tile may have rather than a state the grid always shows somewhere.
    Rectangle {
        anchors.fill: parent
        visible: root.applied
        radius: Appearance.rounding.small
        color: "transparent"
        border.width: 3
        border.color: Appearance.colors.colPrimary
    }

    Rectangle {
        anchors.fill: parent
        visible: root.activeFocus
        radius: Appearance.rounding.small
        color: "transparent"
        border.width: 2
        border.color: Appearance.colors.colSecondary
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.activate();
        }
    }
}
