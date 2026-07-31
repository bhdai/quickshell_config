pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.services

Scope {
    id: root

    property var seenOutputs: ({})

    function hasSeen(name: string): bool {
        return root.seenOutputs[name] === true;
    }

    function remember(name: string): void {
        root.seenOutputs[name] = true;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wallpaperWindow

            required property var modelData
            property string target: Wallpaper.forMonitor(modelData.name)
            property bool reattaching: root.hasSeen(modelData.name)

            screen: modelData
            visible: !reattaching
            exclusionMode: ExclusionMode.Ignore
            color: Appearance.colors.colLayer0
            mask: Region {}

            anchors {
                top: true
                right: true
                bottom: true
                left: true
            }

            WlrLayershell.namespace: "quickshell:wallpaper"
            WlrLayershell.layer: WlrLayer.Background

            Component.onCompleted: {
                root.remember(modelData.name);
                if (wallpaperWindow.reattaching)
                    reattachTimer.restart();
            }

            Timer {
                id: reattachTimer

                interval: 100
                repeat: false
                onTriggered: wallpaperWindow.reattaching = false
            }

            Image {
                anchors.fill: parent
                source: wallpaperWindow.target
                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: wallpaperWindow.width
                sourceSize.height: wallpaperWindow.height
            }
        }
    }
}
