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
    property var notif
    property bool collapsed: false

    width: parent?.width ?? 300
    implicitHeight: mainLayout.implicitHeight + 10 // 10px padding on top/bottom

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: Colors.surface

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: 5
            spacing: 0

            // header Section
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                Layout.bottomMargin: 4

                Item {
                    id: iconContainer
                    implicitWidth: 20
                    implicitHeight: 20

                    // Show app icon if available
                    Loader {
                        id: appIconLoader
                        anchors.fill: parent
                        active: root.notif && root.notif.appIcon
                        sourceComponent: IconImage {
                            source: Quickshell.iconPath(root.notif.appIcon, true)
                            implicitSize: 20
                            visible: source !== ""
                        }
                    }

                    // Show Material Symbol fallback if no app icon
                    Loader {
                        id: materialSymbolLoader
                        anchors.fill: parent
                        active: root.notif && !root.notif.appIcon
                        sourceComponent: MaterialSymbol {
                            text: "lightbulb"
                            fill: 1
                            iconSize: 20
                            color: Colors.accent // Adjust as needed
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Text {
                    text: root.notif ? root.notif.appName : ""
                    Layout.leftMargin: 8
                    opacity: 0.8
                    color: Colors.text
                    font.pointSize: 10
                }

                Item {
                    Layout.fillWidth: true
                } // spacer

                Text {
                    id: timeDisplay
                    opacity: 0.7
                    color: Colors.text
                    font.pointSize: 9
                    text: {
                        if (root.notif && root.notif.time) {
                            var notifTime = new Date(root.notif.time);
                            var now = new Date();
                            var diffMs = now - notifTime;
                            var diffSecs = Math.floor(diffMs / 1000);
                            var diffMins = Math.floor(diffSecs / 60);
                            var diffHours = Math.floor(diffMins / 60);
                            var diffDays = Math.floor(diffHours / 24);

                            if (diffSecs < 60) {
                                return "just now";
                            } else if (diffMins < 60) {
                                return diffMins + "m ago";
                            } else if (diffHours < 24) {
                                return diffHours + "h ago";
                            } else if (diffDays === 1) {
                                return "yesterday";
                            } else if (diffDays < 7) {
                                return diffDays + "d ago";
                            } else {
                                // for older notifications, show the date
                                return Qt.formatDateTime(notifTime, "MMM d");
                            }
                        }
                        return "";
                    }
                }

                MouseArea {
                    id: closeButtonContainer
                    property real iconSize: 15
                    implicitWidth: iconSize
                    implicitHeight: iconSize
                    hoverEnabled: true
                    onClicked: {
                        Notifications.discardNotification(root.notif.notificationId);
                    }
                    CustomIcon {
                        id: closeIcon
                        source: "window-close-symbolic"
                        anchors.centerIn: parent
                        width: closeButtonContainer.iconSize
                        height: closeButtonContainer.iconSize
                        colorize: true
                        color: closeButtonContainer.pressed ? "red" : Colors.powerButton
                    }
                }
            }

            // separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.text
                opacity: 0.5
            }

            // content section
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                Layout.leftMargin: 5
                Layout.rightMargin: 5
                spacing: 10

                ClippingWrapperRectangle {
                    radius: 8
                    antialiasing: true
                    visible: root.notif && root.notif.image !== ""
                    Item {
                        id: notificationImageContainer
                        implicitWidth: 86
                        implicitHeight: 86
                        anchors.centerIn: parent

                        Image {
                            id: notificationImage
                            anchors.fill: parent
                            source: {
                                if (root.notif && root.notif.image) {
                                    let imagePath = root.notif.image;

                                    // convert "image://icon/home/user/..." → "file:///home/user/..."
                                    if (imagePath.startsWith("image://icon/")) {
                                        const stripped = imagePath.replace("image://icon/", "");
                                        if (stripped.startsWith("~/"))
                                            return "file://" + stripped.replace("~", Quickshell.homePath);
                                        if (!stripped.startsWith("/"))
                                            return "file:///" + stripped;
                                        return "file://" + stripped;
                                    }

                                    // handle normal "~/" paths
                                    if (imagePath.startsWith("~/"))
                                        return "file://" + imagePath.replace("~", Quickshell.homePath);

                                    // handle already-valid file URLs
                                    if (imagePath.startsWith("file://"))
                                        return imagePath;

                                    // default case
                                    return imagePath;
                                }
                                return "";
                            }
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                            antialiasing: true
                            asynchronous: true
                            visible: source !== ""

                            // Component.onCompleted: {
                            //     console.log("Notification image source:", notificationImage.source);
                            // }
                        }
                    }
                }

                // right column: summary & body
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: root.notif ? root.notif.summary : ""
                        font.bold: true
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        color: Colors.text
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.notif ? root.notif.body : ""
                        wrapMode: Text.WordWrap
                        textFormat: Text.RichText // to handle markup if any
                        color: Colors.text
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
