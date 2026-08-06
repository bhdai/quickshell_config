//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick

// Stand-in app whose window map is externally triggered: it polls for FAKEAPP_TRIGGER
// and maps as soon as the file appears. That lets the harness fire a workspace
// creation at an exact point in the shell's startup rather than guessing a delay.
ShellRoot {
    id: root

    readonly property string triggerPath: Quickshell.env("FAKEAPP_TRIGGER") ?? ""

    LazyLoader {
        id: loader
        loading: false

        FloatingWindow {
            implicitWidth: 200
            implicitHeight: 120
            title: "fakeapp"

            Rectangle {
                anchors.fill: parent
                color: "#202030"
            }
        }
    }

    Process {
        id: waiter
        running: true
        command: ["sh", "-c", `while [ ! -e "${root.triggerPath}" ]; do sleep 0.002; done`]

        onExited: {
            loader.loading = true;
            console.log("FAKEAPP triggered");
        }
    }
}
