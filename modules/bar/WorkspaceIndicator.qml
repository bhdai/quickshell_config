import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

WrapperRectangle {
    id: workspaceIndicatorRoot
    color: "#444444"
    radius: 20
    margin: 5

    readonly property int defaultWorkspaceCount: 5

    readonly property int horizontalPadding: 3

    readonly property int maxWorkspaceId: {
        if (Hyprland.workspaces?.values?.length > 0) {
            let ids = Hyprland.workspaces.values.map(ws => ws.id);
            return Math.max(defaultWorkspaceCount, Math.max(...ids));
        }
        return defaultWorkspaceCount;
    }

    RowLayout {
        spacing: 1
        Layout.alignment: Qt.AlignVCenter

        Item {
            Layout.preferredWidth: horizontalPadding
        }

        Repeater {
            model: workspaceIndicatorRoot.maxWorkspaceId

            delegate: Item {
                id: container

                readonly property int workspaceId: index + 1
                readonly property var actualWorkspace: Hyprland.workspaces?.values?.find(w => w.id === workspaceId) || null

                readonly property int activeSize: 20
                readonly property int hasWindowsSize: 12
                readonly property int emptySize: 8

                Layout.preferredWidth: activeSize * 1.2
                Layout.preferredHeight: activeSize
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    id: workspacePill
                    anchors.centerIn: parent

                    height: {
                        if (Hyprland.focusedWorkspace?.id === workspaceId) {
                            return activeSize;
                        } else if (actualWorkspace && actualWorkspace.toplevels?.values?.length > 0) {
                            return hasWindowsSize;
                        } else {
                            return emptySize;
                        }
                    }
                    width: Hyprland.focusedWorkspace?.id === workspaceId ? height * 1.5 : height
                    radius: height / 2

                    color: {
                        if (workspaceMouseArea.containsMouse) {
                            return "#5aa5f6";
                        }
                        if (Hyprland.focusedWorkspace?.id === workspaceId) {
                            return "#5aa5f6";
                        } else if (actualWorkspace && actualWorkspace.toplevels?.values?.length > 0) {
                            return "#ffffff";
                        } else {
                            return "#77767b";
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.Linear
                        }
                    }
                    // Behavior on width {
                    //     NumberAnimation {
                    //         duration: 200
                    //         easing.type: Easing.Linear
                    //     }
                    // }
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
}
