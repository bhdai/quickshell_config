import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root
    property var group
    property bool expanded: false

    // AC 6: Auto-collapse when group drops to 1 notification
    onGroupChanged: {
        if (root.group && root.group.count <= 1)
            root.expanded = false;
    }

    width: parent?.width ?? 300
    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        // === COLLAPSED STATE ===
        NotificationItem {
            id: collapsedItem
            Layout.fillWidth: true
            visible: !root.expanded
            notif: root.group ? root.group.latestNotification : null
            inGroup: root.group ? root.group.count > 1 : false
            groupCount: root.group ? root.group.count : 0
            showExpandChevron: root.group ? root.group.count > 1 : false
            onCloseClicked: {
                if (root.group)
                    Notifications.discardGroup(root.group.key);
            }
            onExpandClicked: root.expanded = true
        }

        // expanded state
        // Single continuous background wrapping header + all items (Pixel-style)
        Rectangle {
            Layout.fillWidth: true
            visible: root.expanded
            implicitHeight: expandedColumn.implicitHeight + 12
            radius: 8
            color: Appearance.m3colors.m3surfaceContainer

            ColumnLayout {
                id: expandedColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 4

                // Group header row
                RowLayout {
                    id: groupHeaderRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4

                    IconImage {
                        source: {
                            if (root.group && root.group.appIcon) {
                                let resolved = Quickshell.iconPath(root.group.appIcon, true);
                                if (resolved) return resolved;
                            }
                            return "";
                        }
                        implicitSize: 18
                        visible: status === Image.Ready
                    }

                    Text {
                        text: root.group ? root.group.appName : ""
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: 14
                        font.bold: true
                    }

                    // Count badge (same position as collapsed — right after app name)
                    Rectangle {
                        width: Math.max(expandedCountText.implicitWidth + 8, 22)
                        height: 22
                        radius: 11
                        color: Appearance.m3colors.m3primary

                        Text {
                            id: expandedCountText
                            anchors.centerIn: parent
                            text: root.group ? root.group.count : ""
                            color: Appearance.m3colors.m3onPrimary
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Collapse chevron
                    MouseArea {
                        implicitWidth: 22
                        implicitHeight: 22
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = false

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "expand_less"
                            iconSize: 18
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    // Group dismiss
                    MouseArea {
                        implicitWidth: 15
                        implicitHeight: 15
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.group)
                                Notifications.discardGroup(root.group.key);
                        }

                        CustomIcon {
                            source: "window-close-symbolic"
                            anchors.centerIn: parent
                            width: 15
                            height: 15
                            colorize: true
                            color: parent.pressed ? "red" : Appearance.colors.colPowerButton
                        }
                    }
                }

                // Individual notification items
                Repeater {
                    model: root.group ? root.group.notifications.slice(0, 10) : []

                    NotificationItem {
                        Layout.fillWidth: true
                        notif: modelData
                    }
                }
            }
        }
    }
}
