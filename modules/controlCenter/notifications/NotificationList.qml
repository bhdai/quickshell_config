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

    property real headerAndMarginHeight: 0
    property real maxPanelHeight: 400

    maximumFlickVelocity: 3500
    boundsBehavior: Flickable.DragOverBounds

    delegate: NotificationItem {
        width: notifList.width
        notif: modelData
    }

    interactive: true
}
