import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

ShellRoot {
    id: root

    property var wallpaperService: Wallpaper
    readonly property string scenario: Quickshell.env("WALLPAPER_TEST_SCENARIO") ?? ""
    readonly property string goodPath: Quickshell.env("WALLPAPER_TEST_GOOD") ?? ""
    readonly property string secondPath: Quickshell.env("WALLPAPER_TEST_SECOND") ?? ""
    readonly property string badPath: Quickshell.env("WALLPAPER_TEST_BAD") ?? ""
    readonly property string insertedPath: Quickshell.env("WALLPAPER_TEST_INSERTED") ?? ""
    readonly property string statePath: `${Quickshell.env("XDG_STATE_HOME")}/quickshell/user/wallpaper.json`
    property int attempts: 0
    property int phase: 0

    function libraryNames(): list<string> {
        const names = [];
        for (let index = 0; index < Wallpaper.libraryModel.count; ++index)
            names.push(Wallpaper.libraryModel.get(index, "fileName"));
        return names;
    }

    function finish(message: string): void {
        console.log("WALLPAPER_RESULT " + message);
        Qt.quit();
    }

    FileView {
        id: stateEditor
        path: Qt.resolvedUrl(root.statePath)
        atomicWrites: true
    }

    Process {
        id: insertLibraryFile
        command: ["cp", root.goodPath, root.insertedPath]
        onExited: root.phase = 1
    }

    Timer {
        interval: 50
        repeat: true
        running: true

        onTriggered: {
            root.attempts++;
            if (root.attempts > 100) {
                root.finish("timeout scenario=" + root.scenario);
                return;
            }

            if (root.scenario === "missing") {
                root.finish(`missing get=${Wallpaper.get()} library=${Wallpaper.library}`);
                return;
            }

            if (root.scenario === "commit") {
                if (root.phase === 0) {
                    root.phase = 1;
                    const relative = Wallpaper.set("relative/wall.jpg");
                    const unsupported = Wallpaper.set("/tmp/wall.webp");
                    const home = Wallpaper.set("~/missing.JPG");
                    const accepted = Wallpaper.set("file://" + root.goodPath);
                    console.log(`WALLPAPER_PENDING relative=${relative} unsupported=${unsupported} home=${home} accepted=${accepted} current=${Wallpaper.get()}`);
                } else if (Wallpaper.get() === root.goodPath) {
                    root.finish("committed=" + Wallpaper.get());
                }
                return;
            }

            if (root.scenario === "reload") {
                if (root.phase === 0) {
                    console.log("WALLPAPER_INITIAL " + Wallpaper.get());
                    root.phase = 1;
                    stateEditor.setText(JSON.stringify({
                        wallpaper: root.secondPath,
                        monitorWallpapers: {},
                        library: Wallpaper.library
                    }));
                } else if (Wallpaper.get() === root.secondPath) {
                    root.finish("reloaded=" + Wallpaper.get());
                }
                return;
            }

            if (root.scenario === "malformed") {
                const accepted = Wallpaper.set(root.goodPath);
                root.finish(`malformed accepted=${accepted} current=${Wallpaper.get()}`);
                return;
            }

            if (root.scenario === "malformed-reload") {
                if (root.phase === 0) {
                    root.phase = 1;
                    stateEditor.setText("{ \"wallpaper\": ");
                } else if (Wallpaper.get() === "") {
                    const accepted = Wallpaper.set(root.goodPath);
                    root.finish(`malformed-reload accepted=${accepted} current=${Wallpaper.get()}`);
                }
                return;
            }

            if (root.scenario === "validation") {
                if (root.phase === 0) {
                    root.phase = 1;
                    const accepted = Wallpaper.set(root.badPath);
                    console.log(`WALLPAPER_BAD accepted=${accepted} current=${Wallpaper.get()}`);
                } else if (root.phase === 1 && root.attempts > 8) {
                    root.phase = 2;
                    console.log("WALLPAPER_AFTER_BAD " + Wallpaper.get());
                    const first = Wallpaper.set(root.goodPath);
                    const second = Wallpaper.set(root.secondPath);
                    console.log(`WALLPAPER_LATEST first=${first} second=${second} current=${Wallpaper.get()}`);
                } else if (root.phase === 2 && Wallpaper.get() === root.secondPath) {
                    root.finish("latest=" + Wallpaper.get());
                }
                return;
            }

            if (root.scenario === "same-path") {
                if (root.phase === 0) {
                    root.phase = 1;
                    Wallpaper.set(root.badPath);
                } else if (root.attempts > 8) {
                    root.finish("same-path=" + Wallpaper.get());
                }
                return;
            }

            if (root.scenario === "library") {
                const names = root.libraryNames();
                if (root.phase === 0 && names.length === 4) {
                    console.log("WALLPAPER_LIBRARY initial=" + names.join(","));
                    root.phase = -1;
                    insertLibraryFile.running = true;
                } else if (root.phase === 1 && names.length === 5) {
                    root.finish("library=" + names.join(","));
                }
            }
        }
    }
}
