import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common

WrapperRectangle {
    Layout.alignment: Qt.AlignVCenter

    implicitHeight: 30
    color: Colors.surface
    radius: 15

    leftMargin: 10
    rightMargin: 10

    RowLayout {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
            text: Time.hoursMinutes
            color: "white"
            font.pixelSize: 12
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            width: 1
            color: "white"
            opacity: 0.5

            implicitHeight: parent.height * 0.6
            Layout.alignment: Qt.AlignVCenter
        }

        RowLayout {
            spacing: 5
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: Time.dayOfWeek
                color: "white"
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: Time.dateMonth
                color: "white"
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
