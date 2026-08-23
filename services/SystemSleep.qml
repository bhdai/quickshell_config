pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "SystemSleepParse.js" as SystemSleepParse

/**
 * Emits `resumed` after logind completes a suspend or hibernate cycle.
 *
 * The system bus and `dbus-monitor` must be available for the lifetime of the shell.
 */
Singleton {
    id: root

    signal resumed()

    property bool awaitingArgument: false

    function accept(line) {
        const event = SystemSleepParse.consume(line, root.awaitingArgument);
        root.awaitingArgument = event.awaitingArgument;
        if (event.resumed)
            root.resumed();
    }

    Process {
        command: ["dbus-monitor", "--system", "type='signal',sender='org.freedesktop.login1',path='/org/freedesktop/login1',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"]
        running: true
        stdout: SplitParser {
            onRead: line => root.accept(line)
        }
    }
}
