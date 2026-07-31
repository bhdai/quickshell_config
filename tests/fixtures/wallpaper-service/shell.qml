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
    readonly property string thirdPath: Quickshell.env("WALLPAPER_TEST_THIRD") ?? ""
    readonly property string badPath: Quickshell.env("WALLPAPER_TEST_BAD") ?? ""
    readonly property string insertedPath: Quickshell.env("WALLPAPER_TEST_INSERTED") ?? ""
    readonly property string colorLogPath: Quickshell.env("WALLPAPER_TEST_COLOR_LOG") ?? ""
    readonly property string statePath: `${Quickshell.env("XDG_STATE_HOME")}/quickshell/user/wallpaper.json`
    property int attempts: 0
    property int phase: 0
    property var monitorNames: []
    property int monitorIndex: 0

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

    function colorEvents(): string {
        colorLog.reload();
        return colorLog.text().trim().replace(/\n/g, ",");
    }

    FileView {
        id: stateEditor
        path: Qt.resolvedUrl(root.statePath)
        atomicWrites: true
    }

    FileView {
        id: colorLog
        path: Qt.resolvedUrl(root.colorLogPath)
        blockLoading: true
        printErrors: false
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
                    if (root.phase === 1) {
                        root.phase = 2;
                        console.log(`WALLPAPER_RELOADED global=${Wallpaper.get()} resolved=${Wallpaper.forMonitor("DP-1")}`);
                        stateEditor.setText(JSON.stringify({
                            wallpaper: root.secondPath,
                            monitorWallpapers: { "DP-1": root.goodPath },
                            library: Wallpaper.library
                        }));
                    } else if (Wallpaper.forMonitor("DP-1") === root.goodPath) {
                        root.finish(`reloaded=${Wallpaper.get()} override=${Wallpaper.forMonitor("DP-1")}`);
                    }
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
                return;
            }

            if (root.scenario === "cycle" && Wallpaper.libraryModel.count === 4) {
                const first = Wallpaper.library + "/a.jpg";
                const last = Wallpaper.library + "/z.PNG";
                if (root.phase === 0) {
                    root.phase = 1;
                    console.log(`WALLPAPER_CYCLE next=${Wallpaper.next()} current=${Wallpaper.get()}`);
                } else if (root.phase === 1 && Wallpaper.get() === first) {
                    root.phase = 2;
                    console.log(`WALLPAPER_CYCLE prev=${Wallpaper.prev()} current=${Wallpaper.get()}`);
                } else if (root.phase === 2 && Wallpaper.get() === last) {
                    root.phase = 3;
                    console.log(`WALLPAPER_CYCLE wrap=${Wallpaper.next()} current=${Wallpaper.get()}`);
                } else if (root.phase === 3 && Wallpaper.get() === first) {
                    root.finish("cycle=" + Wallpaper.get());
                }
                return;
            }

            if (root.scenario === "override-set") {
                if (root.phase === 0) {
                    root.phase = 1;
                    const invalid = Wallpaper.setFor("DP-1", "relative/wall.jpg");
                    const bad = Wallpaper.setFor("DP-1", root.badPath);
                    console.log(`WALLPAPER_OVERRIDE pending invalid=${invalid} bad=${bad} current=${Wallpaper.forMonitor("DP-1")}`);
                } else if (root.phase === 1 && root.attempts > 8) {
                    root.phase = 2;
                    const accepted = Wallpaper.setFor("DP-1", root.secondPath);
                    console.log(`WALLPAPER_OVERRIDE after-bad=${Wallpaper.forMonitor("DP-1")} accepted=${accepted}`);
                } else if (root.phase === 2 && Wallpaper.forMonitor("DP-1") === root.secondPath) {
                    root.finish(`override=${Wallpaper.forMonitor("DP-1")} global=${Wallpaper.get()}`);
                }
                return;
            }

            if (root.scenario === "override-clear") {
                const cleared = Wallpaper.clearFor("DP-1");
                const resolved = Wallpaper.forMonitor("DP-1");
                const again = Wallpaper.clearFor("DP-1");
                root.finish(`clear=${cleared} resolved=${resolved} again=${again}`);
                return;
            }

            if (root.scenario === "override-no-fallback") {
                const cleared = Wallpaper.clearFor("DP-1");
                root.finish(`clear-no-fallback=${cleared} resolved=${Wallpaper.forMonitor("DP-1")}`);
                return;
            }

            if (root.scenario === "hidden-global") {
                if (root.phase === 0) {
                    root.monitorNames = Quickshell.screens.map(screen => screen.name);
                    if (root.monitorNames.length === 0) {
                        root.finish("hidden=no-connected-screens");
                        return;
                    }
                    root.phase = 1;
                    Wallpaper.setFor(root.monitorNames[0], root.goodPath);
                } else if (root.phase === 1
                        && Wallpaper.forMonitor(root.monitorNames[root.monitorIndex]) === root.goodPath) {
                    root.monitorIndex++;
                    if (root.monitorIndex < root.monitorNames.length) {
                        Wallpaper.setFor(root.monitorNames[root.monitorIndex], root.goodPath);
                    } else {
                        root.phase = 2;
                        const accepted = Wallpaper.set(root.secondPath);
                        console.log(`WALLPAPER_HIDDEN accepted=${accepted} current=${Wallpaper.get()}`);
                    }
                } else if (root.phase === 2 && Wallpaper.get() === root.secondPath) {
                    root.finish("hidden=" + Wallpaper.get());
                }
                return;
            }

            if (root.scenario === "empty-cycle") {
                const next = Wallpaper.next();
                const prev = Wallpaper.prev();
                root.finish(`empty-cycle next=${next} prev=${prev} current=${Wallpaper.get()}`);
                return;
            }

            if (root.scenario === "noop-cycle" && Wallpaper.libraryModel.count === 1) {
                const next = Wallpaper.next();
                const prev = Wallpaper.prev();
                root.finish(`noop-cycle next=${next} prev=${prev} current=${Wallpaper.get()}`);
                return;
            }

            if (root.scenario === "palette-global") {
                if (root.phase === 0) {
                    root.phase = 1;
                    Wallpaper.set(root.secondPath);
                } else if (root.colorEvents().includes("END " + root.secondPath)) {
                    root.finish(`palette-global current=${Wallpaper.get()} events=${root.colorEvents()}`);
                }
                return;
            }

            if (root.scenario === "palette-same-path") {
                if (root.phase === 0) {
                    root.phase = 1;
                    Wallpaper.set(root.goodPath);
                } else if (root.colorEvents().includes("END " + root.goodPath)) {
                    root.finish(`palette-same-path current=${Wallpaper.get()} events=${root.colorEvents()}`);
                }
                return;
            }

            if (root.scenario === "palette-override") {
                if (root.phase === 0) {
                    root.phase = 1;
                    Wallpaper.setFor("DP-1", root.secondPath);
                } else if (root.phase === 1
                        && Wallpaper.forMonitor("DP-1") === root.secondPath) {
                    root.phase = 2;
                    Wallpaper.clearFor("DP-1");
                } else if (root.phase === 2 && root.attempts > 12) {
                    root.finish(`palette-override current=${Wallpaper.get()} events=${root.colorEvents()}`);
                }
                return;
            }

            if (root.scenario === "palette-latest") {
                const events = root.colorEvents();
                if (root.phase === 0) {
                    root.phase = 1;
                    Wallpaper.set(root.secondPath);
                } else if (root.phase === 1 && events.includes("START " + root.secondPath)) {
                    root.phase = 2;
                    Wallpaper.set(root.goodPath);
                } else if (root.phase === 2 && Wallpaper.get() === root.goodPath) {
                    root.phase = 3;
                    Wallpaper.set(root.thirdPath);
                } else if (root.phase === 3 && events.includes("END " + root.thirdPath)) {
                    root.finish(`palette-latest current=${Wallpaper.get()} events=${events}`);
                }
                return;
            }

            if (root.scenario === "palette-failure") {
                if (root.phase === 0) {
                    root.phase = 1;
                    Wallpaper.set(root.secondPath);
                } else if (root.colorEvents().includes("FAIL " + root.secondPath)) {
                    root.finish(`palette-failure current=${Wallpaper.get()} events=${root.colorEvents()}`);
                }
            }
        }
    }
}
