import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 8

    // default number of workspaces to show
    readonly property int defaultWorkspaceCount: 5

    readonly property int maxWorkspaceId: {
        if (Hyprland.workspaces?.values?.length > 0) {
            let ids = Hyprland.workspaces.values.map(ws => ws.id);
            return Math.max(defaultWorkspaceCount, Math.max(...ids));
        }
        return defaultWorkspaceCount;
    }

    Repeater {
        model: maxWorkspaceId

        delegate: Rectangle {
            id: workspaceRect
            width: 30
            height: 30
            radius: 8

            // determine the workspace ID for this item
            readonly property int workspaceId: index + 1

            // find the actual workspaces object if it exists
            readonly property var actualWorkspace: Hyprland.workspaces?.values?.find(w => w.id === workspaceId) || null

            color: {
                if (workspaceMouseArea.containsMouse) {
                    return "#5aa5f6";
                }

                if (Hyprland.focusedWorkspace?.id === workspaceId) {
                    return "#5aa5f6"; //active/focused workspace
                } else if (actualWorkspace && actualWorkspace.toplevels?.values?.length > 0) {
                    return "#ffffff"; // workspace with windows
                } else {
                    return "#77767b"; // empty workspace
                }
            }

            Text {
                anchors.centerIn: parent
                text: workspaceId
                font.pixelSize: 12
                font.bold: Hyprland.focusedWorkspace?.id === workspaceId
            }

            MouseArea {
                id: workspaceMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    // activate the workspace, creating it if it doesn't exist
                    Hyprland.dispatch(`workspace ${workspaceId}`);
                }
            }
        }
    }
}
