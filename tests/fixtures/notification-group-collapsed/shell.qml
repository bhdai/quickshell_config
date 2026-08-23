import Quickshell
import QtQuick
import qs.modules.controlCenter.notifications

/**
 * Counts the notification rows a group actually builds, collapsed and expanded.
 *
 * A collapsed group shows three previews, but the expanded list is a sibling in the same
 * layout — and `visible: false` does not stop a Repeater from building its delegates. So a
 * group of forty built forty rows every time the control center opened, none of them ever
 * drawn, and the open cost grew with everything the notification store had ever kept.
 *
 * Counted rather than timed: the cost is one row's construction, which is a few hundred
 * microseconds on this machine and nothing on the next one. The row count is the same
 * everywhere.
 */
ShellRoot {
    FloatingWindow {
        id: window

        implicitWidth: 420
        implicitHeight: 600
        visible: true

        readonly property int notificationCount: 40

        readonly property var notifications: {
            const list = [];
            for (let i = 0; i < notificationCount; i++)
                list.push({
                    notificationId: i,
                    appName: "Fixture",
                    appIcon: "",
                    desktopEntry: "fixture",
                    summary: `Summary ${i}`,
                    body: `Body ${i}`,
                    image: "",
                    actions: [],
                    urgency: 1,
                    time: 1787400000000 + i
                });
            return list;
        }

        readonly property var group: ({
            key: "fixture",
            appName: "Fixture",
            appIcon: "",
            notifications: notifications,
            latestNotification: notifications[notificationCount - 1],
            count: notificationCount
        })

        // Duck-typed rather than matched on the type name: QML stamps a generated suffix onto
        // that, and it is not part of any contract.
        function isNotificationRow(item: QtObject): bool {
            return "notif" in item && "showExpandChevron" in item && "compact" in item;
        }

        function countRows(item: QtObject): int {
            let total = isNotificationRow(item) ? 1 : 0;
            for (const child of item.children)
                total += countRows(child);
            return total;
        }

        NotificationGroup {
            id: group

            width: parent.width
            group: window.group
        }

        // On a timer rather than Component.onCompleted: quitting from there runs before the
        // engine has anything connected to the quit signal, and the shell stays up.
        Timer {
            interval: 1
            running: true

            onTriggered: {
                console.log(`ROWS collapsed=${window.countRows(group)} stored=${window.notificationCount}`);
                group.expanded = true;
                console.log(`ROWS expanded=${window.countRows(group)} stored=${window.notificationCount}`);
                Qt.quit();
            }
        }
    }
}
