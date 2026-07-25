import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls

/**
 * Material 3 switch for the detail panels' "Use Bluetooth" / "Use Wi-Fi" rows.
 *
 * Two-way: `checked` is whatever the caller bound it to, and a press reports `toggled()` for
 * the caller to write back to that source. The control never assigns `checked` itself —
 * QtQuick.Controls does that on release while `checkable`, which would drop the caller's
 * binding and leave the switch lying about an adapter that changed from elsewhere.
 *
 * The handle can also be dragged. A drag is transient in the same way: only the handle moves
 * with the pointer, and on release it reports `toggled()` only if it landed on the opposite
 * side. Nothing else about the switch previews a drag — the colours stay on `checked` — so a
 * drag that is dragged back, released short, or declined by the caller costs nothing.
 *
 * A committing drag then parks the handle on the end it chose until the caller writes back,
 * so the gesture reads as one movement even though the write is a device round-trip. If that
 * write never comes, the handle returns rather than sit on a state nothing reached.
 */
Switch {
    id: root

    checkable: false

    // Where the handle sits along its travel: 0 at the off end, 1 at the on end. It follows
    // `checked` except mid-drag, when it follows the pointer. Switch already has a final
    // `position`, driven by the toggling this control deliberately does not do.
    readonly property real handlePosition: (dragArea.dragging || dragArea.settling) ? dragArea.dragPosition : (root.checked ? 1 : 0)
    readonly property real handleTravel: 20

    implicitWidth: 52
    implicitHeight: 32
    padding: 0

    // Reached by keyboard only: dragArea takes every pointer press.
    onClicked: root.toggled()

    onCheckedChanged: dragArea.settling = false

    // Both handle glyphs exist at once and cross-fade, so neither pops mid-travel. Like the
    // track and handle colours they follow `checked`, not the drag: a drag previews nothing
    // until the caller writes it back.
    component HandleIcon: MaterialSymbol {
        anchors.centerIn: parent
        iconSize: 16

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.expressiveEffects
            }
        }
    }

    indicator: Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Appearance.colors.colPrimary : Appearance.colors.colSurfaceContainerHighest
        // The checked track has no visible outline, but the border keeps its width so the
        // outline crossfades into the fill instead of popping off a frame before it.
        border.width: 2
        border.color: root.checked ? Appearance.colors.colPrimary : Appearance.colors.colOutline

        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.expressiveEffects
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.expressiveEffects
            }
        }

        Rectangle {
            id: handle
            // M3 rests the handle centred on 16 (off) and 36 (on) from the track's left edge.
            // At a constant 24 across both states — the size M3 uses once a switch has a
            // border to sit inside — that puts x between 4 and 24.
            width: 24
            height: width
            radius: width / 2
            color: root.checked ? Appearance.colors.colOnPrimary : Appearance.colors.colOutline
            anchors.verticalCenter: parent.verticalCenter
            x: 4 + root.handlePosition * root.handleTravel

            Behavior on x {
                // A dragged handle tracks the pointer directly; animating would make it lag.
                enabled: !dragArea.dragging

                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.expressiveFastSpatial
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.expressiveEffects
                }
            }

            HandleIcon {
                text: "check"
                color: Appearance.colors.colOnPrimaryContainer
                opacity: root.checked ? 1 : 0
            }

            HandleIcon {
                text: "close"
                color: Appearance.colors.colSurfaceContainerHighest
                opacity: root.checked ? 0 : 1
            }
        }
    }

    contentItem: Item {}

    MouseArea {
        id: dragArea

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        property bool dragging: false
        // Held from the release of a committing drag until the caller writes `checked` back.
        property bool settling: false
        property real dragPosition: 0
        property real startPosition: 0
        property real pressX: 0

        onPressed: mouse => {
            dragArea.pressX = mouse.x;
            // Where the handle stands right now, which is not `checked` if a previous drag is
            // still settling. Measuring the drag from anywhere else would jump it on contact.
            dragArea.startPosition = root.handlePosition;
        }

        onPositionChanged: mouse => {
            // Enough movement to tell a drag from a jittery tap, and no more. The platform's
            // own threshold is 10px, tuned for dragging things out of lists; against this
            // handle's 20px of travel it would classify anything short of half the track as a
            // tap, and the gesture would land as a jump from the end it started at.
            if (!dragArea.dragging && Math.abs(mouse.x - dragArea.pressX) < 2)
                return;
            dragArea.settling = false;
            dragArea.dragging = true;
            const travelled = (mouse.x - dragArea.pressX) / root.handleTravel;
            dragArea.dragPosition = Math.max(0, Math.min(1, dragArea.startPosition + travelled));
        }

        onReleased: {
            if (!dragArea.dragging) {
                root.toggled();
                return;
            }
            const landedChecked = dragArea.dragPosition >= 0.5;
            dragArea.dragging = false;
            if (landedChecked === root.checked)
                return;
            // Park at the end the gesture chose and wait there. Falling back to `checked` here
            // would walk the handle home and then fetch it again when the write lands — two
            // journeys for one gesture, and the caller's write is a device round-trip, not a
            // property assignment.
            dragArea.dragPosition = landedChecked ? 1 : 0;
            dragArea.settling = true;
            root.toggled();
        }

        onCanceled: {
            dragArea.dragging = false;
            dragArea.settling = false;
        }

        Timer {
            // A caller that never writes back would otherwise leave the handle parked on a
            // state the device never reached. Generous, because the wait being covered is a
            // real round-trip: expiring while BlueZ is still powering up would send the handle
            // home moments before the state it is waiting for arrives.
            interval: 2000
            running: dragArea.settling
            onTriggered: dragArea.settling = false
        }
    }
}
