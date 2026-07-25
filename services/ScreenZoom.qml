pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common

Singleton {
    id: root
    property real screenZoom: 1

    onScreenZoomChanged: {
        Quickshell.execDetached(["hyprctl", "keyword", "cursor:zoom_factor", root.screenZoom.toString()]);
    }

    Behavior on screenZoom {
        NumberAnimation {
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.expressiveEffects
        }
    }

    IpcHandler {
        target: "zoom"

        function zoomIn() {
            screenZoom = Math.min(screenZoom + 0.4, 3.0);
        }

        function zoomOut() {
            screenZoom = Math.max(screenZoom - 0.4, 1);
        }
    }
}
