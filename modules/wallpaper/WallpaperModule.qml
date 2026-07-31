pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.services

Scope {
    id: root

    readonly property int transitionDuration: 400
    readonly property alias surfaces: surfaceVariants.instances
    property var seenOutputs: ({})

    function hasSeen(name: string): bool {
        return root.seenOutputs[name] === true;
    }

    function remember(name: string): void {
        root.seenOutputs[name] = true;
    }

    Variants {
        id: surfaceVariants

        model: Quickshell.screens

        PanelWindow {
            id: wallpaperWindow

            required property var modelData
            property string target: Wallpaper.forMonitor(modelData.name)
            property string displayed: ""
            property string loadingTarget: ""
            property bool firstIsDisplayed: true
            property bool transitioning: false
            property bool reattaching: root.hasSeen(modelData.name)
            readonly property var outgoingImage: firstIsDisplayed ? firstImage : secondImage
            readonly property var incomingImage: firstIsDisplayed ? secondImage : firstImage

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

            function clearToFloor(): void {
                wallpaperWindow.transitioning = false;
                wallpaperWindow.loadingTarget = "";
                wallpaperWindow.displayed = "";
                firstImage.source = "";
                firstImage.opacity = 0;
                secondImage.source = "";
                secondImage.opacity = 0;
            }

            function loadLatest(): void {
                if (wallpaperWindow.transitioning)
                    return;
                if (!wallpaperWindow.target) {
                    wallpaperWindow.clearToFloor();
                    return;
                }
                if (wallpaperWindow.target === wallpaperWindow.displayed
                        || wallpaperWindow.target === wallpaperWindow.loadingTarget)
                    return;

                const incoming = wallpaperWindow.incomingImage;
                wallpaperWindow.loadingTarget = wallpaperWindow.target;
                incoming.opacity = 0;
                incoming.source = "";
                incoming.source = Qt.resolvedUrl(wallpaperWindow.loadingTarget);
            }

            function land(image): void {
                const retired = wallpaperWindow.outgoingImage;
                const landed = wallpaperWindow.loadingTarget;
                wallpaperWindow.firstIsDisplayed = image === firstImage;
                wallpaperWindow.displayed = landed;
                wallpaperWindow.loadingTarget = "";
                wallpaperWindow.transitioning = false;
                retired.source = "";
                retired.opacity = 0;
                wallpaperWindow.loadLatest();
            }

            function ready(image): void {
                if (image !== wallpaperWindow.incomingImage)
                    return;
                if (wallpaperWindow.loadingTarget !== wallpaperWindow.target) {
                    wallpaperWindow.loadingTarget = "";
                    image.source = "";
                    wallpaperWindow.loadLatest();
                    return;
                }
                if (!wallpaperWindow.displayed) {
                    image.opacity = 1;
                    wallpaperWindow.land(image);
                    return;
                }

                wallpaperWindow.transitioning = true;
                fadeAnimation.restart();
            }

            function failed(image): void {
                if (image !== wallpaperWindow.incomingImage)
                    return;

                const failedTarget = wallpaperWindow.loadingTarget;
                console.warn("Wallpaper: image decode failed:", failedTarget);
                wallpaperWindow.loadingTarget = "";
                image.source = "";
                image.opacity = 0;
                if (wallpaperWindow.target !== failedTarget)
                    wallpaperWindow.loadLatest();
            }

            onTargetChanged: wallpaperWindow.loadLatest()

            Component.onCompleted: {
                root.remember(modelData.name);
                if (wallpaperWindow.reattaching)
                    reattachTimer.restart();
                wallpaperWindow.loadLatest();
            }

            Timer {
                id: reattachTimer

                interval: 100
                repeat: false
                onTriggered: wallpaperWindow.reattaching = false
            }

            NumberAnimation {
                id: fadeAnimation

                // A Behavior reaches opacity 1 but does not reliably deliver its child
                // completion signal under Quickshell 0.3.0, stranding later targets.
                target: wallpaperWindow.incomingImage
                property: "opacity"
                from: 0
                to: 1
                duration: root.transitionDuration
                easing.type: Easing.Linear
                onFinished: wallpaperWindow.land(wallpaperWindow.incomingImage)
            }

            Image {
                id: firstImage

                anchors.fill: parent
                z: wallpaperWindow.firstIsDisplayed ? 0 : 1
                opacity: 0
                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: wallpaperWindow.width
                sourceSize.height: wallpaperWindow.height

                onStatusChanged: {
                    if (status === Image.Ready)
                        wallpaperWindow.ready(firstImage);
                    else if (status === Image.Error)
                        wallpaperWindow.failed(firstImage);
                }
            }

            Image {
                id: secondImage

                anchors.fill: parent
                z: wallpaperWindow.firstIsDisplayed ? 1 : 0
                opacity: 0
                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: wallpaperWindow.width
                sourceSize.height: wallpaperWindow.height

                onStatusChanged: {
                    if (status === Image.Ready)
                        wallpaperWindow.ready(secondImage);
                    else if (status === Image.Error)
                        wallpaperWindow.failed(secondImage);
                }
            }
        }
    }
}
