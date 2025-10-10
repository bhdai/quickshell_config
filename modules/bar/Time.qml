pragma Singleton

import Quickshell

Singleton {
    id: root

    readonly property string hoursMinutes: Qt.formatDateTime(clock.date, "hh:mm")
    readonly property string dayOfWeek: Qt.formatDateTime(clock.date, "ddd")
    readonly property string dateMonth: Qt.formatDateTime(clock.date, "dd/MM")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
