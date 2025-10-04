pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property string time: {
        Qt.formatDateTime(clock.date, "dd MMM d hh:mm AP");
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
