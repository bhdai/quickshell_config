import QtQuick
import Quickshell
import QtQuick.Controls
import QtQuick.Layouts
import qs.services

ListView {
    id: notifList
    Layout.fillWidth: true

    implicitHeight: Math.min(contentHeight, maxPanelHeight - headerAndMarginHeight)

    // set explicit height to respect the allocated space from parent
    height: implicitHeight

    clip: true
    spacing: 6

    model: ScriptModel {
        values: Notifications.listArray
    }

    property real touchpadScrollFactor: 150
    property real mouseScrollFactor: 50
    property real mouseScrollDeltaThreshold: 120
    property real scrollTargetY: 0
    property bool animateAppearance: true

    property real headerAndMarginHeight: 0
    property real maxPanelHeight: 400

    maximumFlickVelocity: 3500
    boundsBehavior: Flickable.DragOverBounds

    delegate: NotificationItem {
        width: notifList.width
        notif: modelData
    }

    interactive: true

    // behavior for smooth scrolling animation
    Behavior on contentY {
        NumberAnimation {
            id: scrollAnim
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0, 0, 0, 1, 1, 1]
        }
    }

    // keep target synced when not animating
    onContentYChanged: {
        if (!scrollAnim.running) {
            scrollTargetY = contentY;
        }
    }

    // custom MouseArea to handle wheel events with momentum
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function (wheel) {
            // Determine if this is from a touchpad or mouse based on delta
            var delta = wheel.angleDelta.y / mouseScrollDeltaThreshold;
            var scrollFactor = Math.abs(wheel.angleDelta.y) >= mouseScrollDeltaThreshold ? mouseScrollFactor : touchpadScrollFactor;

            // Calculate the maximum scroll position
            var maxY = Math.max(0, contentHeight - height);

            // Calculate the new target position based on current animation state
            var base = scrollAnim.running ? scrollTargetY : contentY;
            var targetY = Math.max(0, Math.min(base - delta * scrollFactor, maxY));

            // Update the target and contentY
            scrollTargetY = targetY;
            contentY = targetY;

            wheel.accepted = true;
        }
    }
}
