import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./notifications"

Rectangle {
    id: root

    radius: 20
    color: Colors.surface1

    ColumnLayout {
        anchors.margins: 10
        anchors.fill: parent
        spacing: 0

        NotificationList {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
