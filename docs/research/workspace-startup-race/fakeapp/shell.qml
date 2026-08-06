//@ pragma UseQApplication
import Quickshell
import QtQuick

// Stand-in for one of the exec-once pinned apps. Maps a single normal toplevel
// after FAKEAPP_DELAY ms so the workspace-creation event can be placed anywhere
// relative to the shell's startup snapshot.
ShellRoot {
    id: root

    readonly property int delayMs: parseInt(Quickshell.env("FAKEAPP_DELAY") ?? "0") || 0

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

    Timer {
        interval: root.delayMs
        running: true
        onTriggered: {
            loader.loading = true;
            console.log(`FAKEAPP mapped after ${root.delayMs}ms`);
        }
    }
}
