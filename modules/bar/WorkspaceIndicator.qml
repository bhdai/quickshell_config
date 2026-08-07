import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.modules.common
import "WorkspaceModel.js" as WorkspaceModel

Item {
    id: root

    // One bar per output, so the highlight is a question about this output. Hyprland's
    // focused workspace and focused monitor are both global and would light the same dot on
    // every display.
    required property ShellScreen screen

    // The special visible on this monitor. Nothing sets it yet; the `activespecial` event
    // that does arrives with bhdai/quickshell_config#130.
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

    // No background of its own. A colLayer1 stadium at this height read as a smaller
    // container beside the bar's others rather than as one of them, so the row sits
    // directly on the bar. The vertical padding stays: it is what keeps the dots off the
    // bar's edges and what the hover state layer needs room for.

    Item {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        width: root.rowGeometry.contentWidth
        height: root.activeSize

        Repeater {
            model: root.workspaceRow.slots

            delegate: Item {
                id: slot

                required property int index
                required property var modelData

                x: root.padding + index * root.stride
                width: root.dotWidth
                height: root.activeSize

                // A slot that appears because the row grew arrives rather than pops.
                opacity: 0
                Component.onCompleted: opacity = 1

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
                    height: slot.modelData.occupied ? root.occupiedDotSize : root.emptyDotSize
                    width: height
                    radius: Appearance.rounding.full
                    color: {
                        if (slot.modelData.urgent)
                            return Appearance.m3colors.m3error;
                        return slot.modelData.occupied ? Appearance.colors.colOnLayer0 : Appearance.colors.colEmptyWorkspace;
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
                    onClicked: Hyprland.dispatch(WorkspaceModel.focusCommand(slot.modelData.id))
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
}
