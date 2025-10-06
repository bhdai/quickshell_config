import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: workspaceIndicatorRoot

    readonly property int defaultWorkspaceCount: 5
    readonly property int horizontalPadding: 5
    readonly property int pillSpacing: 1

    readonly property int activeSize: 20
    readonly property int hasWindowsSize: 12
    readonly property int emptySize: 8
    readonly property real itemContainerWidth: activeSize * 1.2

    readonly property real activeWidthMultiplier: 1.2
    readonly property real activeIndicatorWidth: itemContainerWidth * activeWidthMultiplier

    readonly property int targetIndex: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id - 1 : 0
    property real targetX: 0

    function updatePillPosition() {
        var targetItem = dotsRepeater.itemAt(targetIndex);
        if (targetItem) {
            var centerPointInRoot = targetItem.mapToItem(workspaceIndicatorRoot, targetItem.width / 2, 0);
            targetX = centerPointInRoot.x - (activeIndicatorWidth / 2);
        }
    }

    Component.onCompleted: {
        updatePillPosition();
    }

    onTargetIndexChanged: {
        updatePillPosition();
    }

    readonly property int maxWorkspaceId: {
        if (Hyprland.workspaces?.values?.length > 0) {
            let ids = Hyprland.workspaces.values.map(ws => ws.id);
            return Math.max(defaultWorkspaceCount, Math.max(...ids));
        }
        return defaultWorkspaceCount;
    }

    // the component's implicit size is calculated based on its contents
    implicitHeight: activeSize + 10 // WrapperRectangle's margin * 2
    implicitWidth: {
        const repeaterWidth = (itemContainerWidth * maxWorkspaceId) + (pillSpacing * (maxWorkspaceId - 1));
        return repeaterWidth + (horizontalPadding * 2) + 10; // WrapperRectangle's margin * 2
    }

    WrapperRectangle {
        id: background
        anchors.fill: parent
        color: "#444444"
        radius: 20
        margin: 5
    }

    RowLayout {
        id: dotsLayout
        anchors.centerIn: parent
        spacing: pillSpacing

        Item {
            Layout.preferredWidth: horizontalPadding
        }

        Repeater {
            id: dotsRepeater
            model: maxWorkspaceId

            delegate: Item {

                Layout.preferredWidth: itemContainerWidth
                Layout.preferredHeight: activeSize

                readonly property int workspaceId: index + 1
                readonly property var actualWorkspace: Hyprland.workspaces?.values?.find(w => w.id === workspaceId) || null

                Rectangle {
                    anchors.centerIn: parent

                    height: actualWorkspace && actualWorkspace.toplevels?.values?.length > 0 ? hasWindowsSize : emptySize
                    width: height
                    radius: height / 2

                    color: {
                        if (workspaceMouseArea.containsMouse) {
                            return "#5aa5f6";
                        }
                        // it never gets to this logic for the active dot because the blue pill is on top
                        if (actualWorkspace && actualWorkspace.toplevels?.values?.length > 0) {
                            return "#ffffff";
                        } else {
                            return "#77767b";
                            // return "#2d2d2d";
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }

                MouseArea {
                    id: workspaceMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        Hyprland.dispatch(`workspace ${workspaceId}`);
                    }
                }
            }
        }

        Item {
            Layout.preferredWidth: horizontalPadding
        }
    }

    // the animated indicator
    // this regtangle sits on top of everything else
    Rectangle {
        z: 1 // make sure it's drawn on top of the dots
        anchors.verticalCenter: parent.verticalCenter
        height: activeSize
        width: activeIndicatorWidth
        radius: height / 2
        color: "#5aa5f6"
        enabled: false

        x: targetX

        Behavior on x {
            NumberAnimation {
                duration: 250
                easing.type: Easing.InOutCubic
            }
        }
    }
}
