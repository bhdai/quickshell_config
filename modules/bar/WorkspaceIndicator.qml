import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.widgets
import "WorkspaceModel.js" as WorkspaceModel

Item {
    id: root

    // One bar per output, so the highlight is a question about this output. Hyprland's
    // focused workspace and focused monitor are both global and would light the same dot on
    // every display.
    required property ShellScreen screen

    // The special visible on this monitor. Written by the `activespecial` handler below and
    // by the startup seed read, and by nothing else — see the handler for why membership of
    // `Hyprland.workspaces` cannot answer this question.
    property string specialName: ""

    readonly property int activeSize: 16
    readonly property int verticalPadding: 5
    readonly property int dotWidth: 18
    readonly property int slotSpacing: 3
    readonly property int stride: dotWidth + slotSpacing
    // Measured from the widget's outer edge, so contentWidth covers the whole item and the
    // bounds it reports cannot drift from the ones it paints.
    readonly property int padding: 10
    readonly property int pillWidth: Math.round(dotWidth * 1.2)
    readonly property int occupiedDotSize: Math.round(activeSize * 0.6)
    readonly property int emptyDotSize: Math.round(activeSize * 0.4)
    readonly property int overlayWidth: Math.round(activeSize * 1.25)
    // MultiEffect's blur radius is in pixels of the source, so what carries over from
    // end-4's 32 against a 26 px button is that ~1.23 ratio, not the number. Oversized on
    // purpose: the row is meant to become an unreadable smear, not a soft-focus row.
    readonly property int specialBlurMax: Math.round(dotWidth * 1.23)

    // One driver for the whole treatment — the row's blur and scale and the overlay's
    // opacity — so the two halves cannot disagree about how far along they are. The pointer
    // suppressing it is the peek, and it changes no compositor state: this widget reports
    // the special, it does not operate it.
    property real specialReveal: (workspaceRow.special.visible && !peekHover.hovered) ? 1 : 0

    Behavior on specialReveal {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }

    // The marshalling into plain data has to happen inside this binding. Hoisted into a
    // JS variable first, QML stops tracking the live Hyprland objects it reads and the row
    // freezes at whatever it held when the binding last ran.
    readonly property var workspaceRow: WorkspaceModel.workspaceModel({
        workspaces: Hyprland.workspaces.values.map(workspace => ({
                    id: workspace.id,
                    name: workspace.name,
                    windowCount: workspace.toplevels?.values?.length ?? 0,
                    urgent: workspace.urgent
                })),
        activeId: Hyprland.monitorFor(root.screen)?.activeWorkspace?.id ?? 0,
        specialName: root.specialName
    })

    readonly property var rowGeometry: WorkspaceModel.pillGeometry({
        count: workspaceRow.slots.length,
        activeIndex: workspaceRow.activeIndex
    }, {
        dotWidth: dotWidth,
        spacing: slotSpacing,
        padding: padding,
        pillWidth: pillWidth
    })

    implicitWidth: rowGeometry.contentWidth
    implicitHeight: activeSize + 2 * verticalPadding

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            // Qt reads `bezierCurve` only when the type says BezierSpline. Appearance
            // already spells that enum on every token that carries a curve, so this names
            // one there rather than reaching into the Easing namespace for itself.
            easing.type: Appearance.animation.elementMoveSlow.type
            easing.bezierCurve: Appearance.animation.expressiveFastSpatial
        }
    }

    // Special visibility arrives on both edges and names its monitor: "special:quake,eDP-1"
    // on show, ",eDP-1" on hide. That is the whole per-monitor answer for one string split
    // per event. It cannot be read off `Hyprland.workspaces` instead: a special sits in that
    // list whenever it holds windows whether or not it is on screen, reports active: false
    // while visible, and lingers there for ~250 ms after a hide.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activespecial")
                return;

            const special = WorkspaceModel.parseActiveSpecial(event.data);
            if (special.monitor === root.screen.name)
                root.specialName = special.name;
        }
    }

    // A special already raised when the shell starts emits no event, and there is no replay
    // to ask for. This matters far more for hot reload — every file save, during development
    // — than for cold start.
    Component.onCompleted: Hyprland.refreshMonitors()

    Timer {
        // `HyprlandMonitor` carries no specialWorkspace property on Quickshell 0.3.0, so the
        // name only exists on the raw IPC object, and that object is still the pre-refresh
        // snapshot for roughly 250 ms after the request goes out. Qt.callLater is far too
        // short to see the reply.
        interval: 300
        running: true
        onTriggered: {
            // Seeds a name, never clears one: clearing belongs to the event stream, and a
            // read that raced a hide would otherwise resurrect a special already gone.
            const seeded = Hyprland.monitorFor(root.screen)?.lastIpcObject?.specialWorkspace?.name ?? "";
            if (seeded !== "")
                root.specialName = seeded;
        }
    }

    // A handler rather than a MouseArea over the row: the per-dot areas underneath stay
    // clickable and keep their own hover state, which a covering MouseArea would take.
    HoverHandler {
        id: peekHover
    }

    // No background of its own. A colLayer1 stadium at this height read as a smaller
    // container beside the bar's others rather than as one of them, so the row sits
    // directly on the bar. The vertical padding stays: it is what keeps the dots off the
    // bar's edges and what the hover state layer needs room for.

    Item {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        width: root.rowGeometry.contentWidth
        height: root.activeSize

        // The row shrinking as it blurs is what reads as "this went behind something"
        // rather than "this went out of focus".
        scale: 1 - 0.08 * root.specialReveal

        // Off entirely while nothing is raised: layering costs a texture and a render pass
        // per frame, and this row animates. Urgent blurs with everything else — peek is how
        // you read it — because lifting it out would need a third sibling carrying its own
        // slot arithmetic.
        layer.enabled: root.specialReveal > 0
        layer.effect: MultiEffect {
            source: row
            blurEnabled: true
            blur: root.specialReveal
            blurMax: root.specialBlurMax
        }

        Repeater {
            // A constant count rather than the row's length. A Repeater over an array model
            // destroys and rebuilds every delegate when that array is reassigned, and each
            // rebuilt slot restarts its entry fade from zero — so the whole row blinked
            // every time a workspace was created or destroyed, which is every time an app
            // opens on an empty workspace past the floor. The ceiling is the most slots the
            // model can ever hand back, so the delegates outlive any row length.
            model: WorkspaceModel.MAX_SLOTS

            delegate: Item {
                id: slot

                required property int index

                // Null past the end of the row. Every binding below reads through that
                // rather than the delegate being torn down when the row shrinks.
                readonly property var entry: root.workspaceRow.slots[index] ?? null

                x: root.padding + index * root.stride
                width: root.dotWidth
                height: root.activeSize

                // A slot that appears because the row grew arrives rather than pops, and one
                // that leaves because it shrank departs the same way.
                opacity: entry ? 1 : 0
                // Off entirely once faded out: an opacity-zero Item still takes clicks and
                // hover, and these sit past the widget's own width, which does not clip.
                visible: opacity > 0

                Behavior on opacity {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                // An M3 state layer behind the dot rather than a recolour of it: hover and
                // active used to be the same colour, so you could not tell what the pointer
                // was over from what the compositor was showing. Keyed to layer 0 because
                // that is the surface it now sits on — the row has no container of its own.
                Rectangle {
                    anchors.centerIn: parent
                    width: root.activeSize
                    height: root.activeSize
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colLayer0Hover
                    opacity: slotMouseArea.containsMouse ? 1 : 0

                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    height: slot.entry?.occupied ? root.occupiedDotSize : root.emptyDotSize
                    width: height
                    radius: Appearance.rounding.full
                    color: {
                        if (slot.entry?.urgent)
                            return Appearance.m3colors.m3error;
                        return slot.entry?.occupied ? Appearance.colors.colOnLayer0 : Appearance.colors.colEmptyWorkspace;
                    }

                    Behavior on height {
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                    }

                    Behavior on color {
                        animation: Appearance.animation.elementMove.colorAnimation.createObject(this)
                    }
                }

                MouseArea {
                    id: slotMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    // The model's slot ids run 1..n contiguously, so the ordinal is the
                    // index and needs no lookup. Reading it off `entry` instead would have
                    // to answer for a slot clicked during the fade it leaves on, which has
                    // no entry left and is still the workspace you pointed at.
                    onClicked: Hyprland.dispatch(WorkspaceModel.focusCommand(slot.index + 1))
                }
            }
        }

        // Declared after the slots so it covers the active dot, which is the mark — #120
        // chose no knocked-out shape on the pill.
        Rectangle {
            x: root.rowGeometry.pillX
            width: root.pillWidth
            height: root.activeSize
            radius: Appearance.rounding.full
            // -1 is the model's single "nowhere to point": no workspaces at all, an active
            // workspace missing from the list, or an active id past the ceiling.
            visible: root.workspaceRow.activeIndex >= 0
            color: {
                const index = root.workspaceRow.activeIndex;
                if (index >= 0 && root.workspaceRow.slots[index].urgent)
                    return Appearance.m3colors.m3error;
                return Appearance.colors.colPrimary;
            }

            Behavior on x {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }

            Behavior on color {
                animation: Appearance.animation.elementMove.colorAnimation.createObject(this)
            }
        }
    }

    // A sibling of the row, centred over it, feeding nothing: the widget is exactly as wide
    // with a special raised as without, which is what makes this treatment cost zero
    // horizontal pixels on a 40 px bar.
    Rectangle {
        id: specialOverlay

        anchors.centerIn: row
        width: root.overlayWidth
        height: root.activeSize
        radius: Appearance.rounding.full
        color: Appearance.colors.colPrimary
        opacity: root.specialReveal
        visible: opacity > 0

        MaterialSymbol {
            anchors.centerIn: parent
            text: "layers"
            // Filled rather than outlined: outline strokes thin out below roughly 20 px.
            fill: 1
            // MaterialSymbol wires the `opsz` axis to iconSize, so the glyph is drawn for
            // this size rather than scaled down from the 24 px master.
            iconSize: Math.round(root.activeSize * 0.65)
            color: Appearance.colors.colOnPrimary
        }
    }
}
