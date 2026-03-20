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

        //  single notification (no group controls needed)
        NotificationItem {
            Layout.fillWidth: true
            visible: !root.group || root.group.count <= 1
            notif: root.group ? root.group.latestNotification : null
        }

        //  multi notification group (count > 1)
        // Single card with persistent header
        Rectangle {
            Layout.fillWidth: true
            visible: root.group && root.group.count > 1
            implicitHeight: groupCardColumn.implicitHeight + 10
            radius: 8
            color: root.expanded ? Appearance.m3colors.m3surfaceContainer : Appearance.colors.colLayer1

            ColumnLayout {
                id: groupCardColumn
                anchors.fill: parent
                anchors.margins: 5
                spacing: 0

                // persistent header (stays put across collapsed/expanded)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Layout.bottomMargin: 4

                    Item {
                        implicitWidth: 20
                        implicitHeight: 20

                        IconImage {
                            id: groupAppIcon
                            anchors.fill: parent
                            source: {
                                if (!root.group) return "";
                                if (root.group.appIcon) {
                                    let resolved = Quickshell.iconPath(root.group.appIcon, true);
                                    if (resolved) return resolved;
                                }
                                if (root.group.latestNotification && root.group.latestNotification.appName) {
                                    let guessed = AppSearch.guessIcon(root.group.latestNotification.appName);
                                    if (guessed && guessed !== "image-missing" && guessed !== "application-x-executable")
                                        return Quickshell.iconPath(guessed, true);
                                }
                                return "";
                            }
                            implicitSize: 20
                            visible: status === Image.Ready
                        }

                        CustomIcon {
                            anchors.fill: parent
                            source: "software-update-urgent-symbolic.svg"
                            width: 20
                            height: 20
                            visible: groupAppIcon.status !== Image.Ready
                        }
                    }

                    Text {
                        text: root.group ? root.group.appName : ""
                        Layout.leftMargin: 8
                        opacity: 0.8
                        color: Appearance.colors.colOnLayer0
                        font.pointSize: 10
                    }

                    // Count badge
                    Rectangle {
                        Layout.leftMargin: 4
                        width: Math.max(groupCountText.implicitWidth + 8, 20)
                        height: 18
                        radius: 9
                        color: Appearance.m3colors.m3primary

                        Text {
                            id: groupCountText
                            anchors.centerIn: parent
                            text: root.group ? root.group.count : ""
                            color: Appearance.m3colors.m3onPrimary
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Time display (collapsed only)
                    Text {
                        visible: !root.expanded
                        opacity: 0.7
                        color: Appearance.colors.colOnLayer0
                        font.pointSize: 9
                        text: {
                            if (!root.group || !root.group.latestNotification) return "";
                            const notif = root.group.latestNotification;
                            if (!notif.time) return "";
                            var notifTime = new Date(notif.time);
                            var now = new Date();
                            var diffMs = now - notifTime;
                            var diffSecs = Math.floor(diffMs / 1000);
                            var diffMins = Math.floor(diffSecs / 60);
                            var diffHours = Math.floor(diffMins / 60);
                            var diffDays = Math.floor(diffHours / 24);

                            if (diffSecs < 60) return "just now";
                            else if (diffMins < 60) return diffMins + "m ago";
                            else if (diffHours < 24) return diffHours + "h ago";
                            else if (diffDays === 1) return "yesterday";
                            else if (diffDays < 7) return diffDays + "d ago";
                            else return Qt.formatDateTime(notifTime, "MMM d");
                        }
                    }

                    // Expand/collapse chevron (PERSISTENT — rotation animates like SysTray)
                    MouseArea {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = !root.expanded

                        CustomIcon {
                            source: "go-down-symbolic"
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            colorize: true
                            color: Appearance.colors.colOnLayer0
                            rotation: root.expanded ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }

                    // Close/dismiss group button
                    MouseArea {
                        property real iconSize: 15
                        implicitWidth: iconSize
                        implicitHeight: iconSize
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.group)
                                Notifications.discardGroup(root.group.key);
                        }

                        CustomIcon {
                            source: "window-close-symbolic"
                            anchors.centerIn: parent
                            width: parent.iconSize
                            height: parent.iconSize
                            colorize: true
                            color: parent.pressed ? "red" : Appearance.colors.colPowerButton
                        }
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    visible: !root.expanded
                    height: 1
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.2
                }

                // collapsed content: stacked notification previews
                ColumnLayout {
                    visible: !root.expanded
                    spacing: 1

                    Repeater {
                        model: root.group ? root.group.notifications.slice(0, 3) : []

                        NotificationItem {
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            notif: modelData
                            showHeader: false
                            compact: true
                            opacity: index < 2 ? 1 : (root.group && root.group.count > 3 ? 0.5 : 1)
                        }
                    }
                }

                // expanded content: all notifications
                ColumnLayout {
                    visible: root.expanded
                    spacing: 4
                    Layout.topMargin: 4

                    Repeater {
                        model: root.group ? root.group.notifications : []

                        NotificationItem {
                            Layout.fillWidth: true
                            notif: modelData
                        }
                    }
                }
            }
        }
    }
}
