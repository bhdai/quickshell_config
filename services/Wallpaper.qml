pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.modules.common.functions
import "WallpaperLogic.js" as WallpaperLogic

/**
 * Owns wallpaper state, library discovery, validation, persistence, and IPC.
 *
 * Path mutations return an accepted normalized path before asynchronous decoding finishes
 * and commit only when the newest candidate reaches Ready. Override deletion is immediate
 * and returns the resolved global fallback.
 */
Singleton {
    id: root

    readonly property string stateRoot: Quickshell.env("XDG_STATE_HOME")
        || `${Quickshell.env("HOME")}/.local/state`
    readonly property string stateDirectory: `${stateRoot}/quickshell/user`
    readonly property string statePath: `${stateDirectory}/wallpaper.json`
    readonly property string defaultLibrary: `${FileUtils.trimFileProtocol(
        StandardPaths.writableLocation(StandardPaths.PicturesLocation))}/wall`

    readonly property string wallpaper: stateAdapter.wallpaper
    readonly property var monitorWallpapers: stateAdapter.monitorWallpapers
    readonly property string library: stateAdapter.library
    readonly property alias libraryModel: folderList

    property bool writesEnabled: true
    property bool stateDirectoryReady: false
    property bool savePending: false
    property string pendingPath: ""
    property bool pendingForMonitor: false
    property string pendingMonitor: ""
    property string pendingPalettePath: ""

    // Emitted only after the colour script has finished publishing a complete palette.
    signal paletteGenerated()

    function get(): string {
        return stateAdapter.wallpaper;
    }

    function forMonitor(name: string): string {
        return WallpaperLogic.forMonitor(
            stateAdapter.wallpaper,
            stateAdapter.monitorWallpapers,
            name
        );
    }

    function normalizePath(path): string {
        if (typeof path !== "string")
            return "";

        let normalized = FileUtils.trimFileProtocol(path);
        if (normalized.startsWith("~/"))
            normalized = `${Quickshell.env("HOME")}/${normalized.slice(2)}`;

        if (!normalized.startsWith("/") || !WallpaperLogic.hasSupportedExtension(normalized))
            return "";

        return normalized;
    }

    function connectedMonitorNames(): list<string> {
        return Quickshell.screens.map(screen => screen.name);
    }

    function apply(path, monitor): string {
        const normalized = root.normalizePath(path);
        if (!normalized) {
            console.warn("Wallpaper: refused unsupported or non-absolute path:", path);
            return "";
        }
        if (!root.writesEnabled) {
            console.warn("Wallpaper: state writes are disabled for this session");
            return "";
        }

        const forMonitor = monitor !== undefined;
        if (forMonitor) {
            const connected = root.connectedMonitorNames();
            if (!connected.includes(monitor))
                console.warn("Wallpaper: monitor", monitor,
                    "is not connected; connected screens:", connected.join(", "));
        }

        root.pendingPath = normalized;
        root.pendingForMonitor = forMonitor;
        root.pendingMonitor = forMonitor ? monitor : "";
        validationImage.source = "";
        validationImage.source = Qt.resolvedUrl(normalized);
        return normalized;
    }

    function set(path): string {
        return root.apply(path);
    }

    function libraryPaths(): list<string> {
        const paths = [];
        for (let index = 0; index < folderList.count; ++index)
            paths.push(FileUtils.trimFileProtocol(folderList.get(index, "fileUrl")));
        return paths;
    }

    function cycle(direction): string {
        const paths = root.libraryPaths();
        if (paths.length === 0) {
            console.warn("Wallpaper: cannot cycle an empty library:", root.library);
            return "";
        }

        const target = WallpaperLogic.cyclePath(paths, stateAdapter.wallpaper, direction);
        if (target === stateAdapter.wallpaper)
            return "";
        return root.apply(target);
    }

    function next(): string {
        return root.cycle(1);
    }

    function prev(): string {
        return root.cycle(-1);
    }

    function setFor(monitor, path): string {
        return root.apply(path, monitor);
    }

    function clearFor(monitor): string {
        if (!root.writesEnabled) {
            console.warn("Wallpaper: state writes are disabled for this session");
            return "";
        }
        if (!Object.keys(stateAdapter.monitorWallpapers).includes(monitor))
            return "";

        const overrides = {};
        for (const name in stateAdapter.monitorWallpapers) {
            if (name !== monitor)
                overrides[name] = stateAdapter.monitorWallpapers[name];
        }
        stateAdapter.monitorWallpapers = overrides;
        root.saveState();
        return stateAdapter.wallpaper || "";
    }

    function saveState(): void {
        if (root.stateDirectoryReady)
            stateFile.writeAdapter();
        else
            root.savePending = true;
    }

    function warnIfGlobalHidden(): void {
        const connected = root.connectedMonitorNames();
        if (connected.length > 0
                && connected.every(name => Boolean(stateAdapter.monitorWallpapers[name]))) {
            console.warn("Wallpaper: every connected screen (" + connected.join(", ")
                + ") has a per-monitor override; the global wallpaper changed but nothing"
                + " on screen will");
        }
    }

    function startPalette(path: string): void {
        paletteProcess.command = [
            FileUtils.trimFileProtocol(Quickshell.shellPath("scripts/colors/apply-colors.sh")),
            path
        ];
        paletteProcess.running = true;
    }

    function requestPalette(path: string): void {
        if (paletteProcess.running) {
            root.pendingPalettePath = path;
            return;
        }
        root.startPalette(path);
    }

    function commitPending(): void {
        const path = root.pendingPath;
        if (!path || !root.writesEnabled)
            return;

        const forMonitor = root.pendingForMonitor;
        const monitor = root.pendingMonitor;
        root.pendingPath = "";
        root.pendingForMonitor = false;
        root.pendingMonitor = "";
        if (forMonitor) {
            const overrides = {};
            for (const name in stateAdapter.monitorWallpapers)
                overrides[name] = stateAdapter.monitorWallpapers[name];
            overrides[monitor] = path;
            stateAdapter.monitorWallpapers = overrides;
        } else {
            stateAdapter.wallpaper = path;
            root.warnIfGlobalHidden();
            root.requestPalette(path);
        }
        root.saveState();
    }

    function resetState(): void {
        stateAdapter.wallpaper = "";
        stateAdapter.monitorWallpapers = {};
        stateAdapter.library = root.defaultLibrary;
    }

    function loadStateText(text: string): void {
        if (!text.trim()) {
            root.resetState();
            return;
        }

        let value;
        try {
            value = JSON.parse(text);
            if (value === null || Array.isArray(value) || typeof value !== "object")
                throw new Error("state root is not an object");
            if (value.wallpaper !== undefined && typeof value.wallpaper !== "string")
                throw new Error("wallpaper is not a string");
            if (value.monitorWallpapers !== undefined
                    && (value.monitorWallpapers === null
                        || Array.isArray(value.monitorWallpapers)
                        || typeof value.monitorWallpapers !== "object"))
                throw new Error("monitorWallpapers is not an object");
            if (value.library !== undefined && typeof value.library !== "string")
                throw new Error("library is not a string");
        } catch (error) {
            root.writesEnabled = false;
            root.pendingPath = "";
            root.pendingForMonitor = false;
            root.pendingMonitor = "";
            validationImage.source = "";
            root.resetState();
            console.warn("Wallpaper: malformed state; refusing writes for this session");
            return;
        }

        stateAdapter.wallpaper = value.wallpaper ?? "";
        stateAdapter.monitorWallpapers = value.monitorWallpapers ?? {};
        stateAdapter.library = value.library ?? root.defaultLibrary;
    }

    Component.onCompleted: root.loadStateText(stateFile.text())

    Process {
        id: createStateDirectory
        command: ["mkdir", "-p", root.stateDirectory]
        running: true
        onExited: {
            root.stateDirectoryReady = true;
            if (root.savePending) {
                root.savePending = false;
                stateFile.writeAdapter();
            }
        }
    }

    Process {
        id: paletteProcess

        stderr: StdioCollector {
            id: paletteStderr
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                const error = paletteStderr.text.trim();
                console.warn("Wallpaper: palette generation failed:", error);
                Quickshell.execDetached([
                    "notify-send",
                    "Wallpaper set",
                    "Colours unchanged",
                    "-u",
                    "critical",
                    "-a",
                    "Shell"
                ]);
            } else {
                // Matugen replaces its output inode, which FileView's watch does not see.
                root.paletteGenerated();
            }

            const next = root.pendingPalettePath;
            root.pendingPalettePath = "";
            if (next)
                root.startPalette(next);
        }
    }

    FileView {
        id: stateFile

        path: Qt.resolvedUrl(root.statePath)
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false

        adapter: JsonAdapter {
            id: stateAdapter
            property string wallpaper: ""
            property var monitorWallpapers: ({})
            property string library: root.defaultLibrary
        }

        onFileChanged: stateFile.reload()
        onLoaded: root.loadStateText(stateFile.text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn("Wallpaper: failed to load state:", FileViewError.toString(error));
        }
        onSaveFailed: error => console.warn(
            "Wallpaper: failed to save state:", FileViewError.toString(error))
    }

    FolderListModel {
        id: folderList

        folder: Qt.resolvedUrl(root.library)
        nameFilters: WallpaperLogic.NAME_FILTERS
        caseSensitive: false
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        sortReversed: false
    }

    Image {
        id: validationImage

        visible: false
        asynchronous: true
        cache: false
        sourceSize.width: 1
        sourceSize.height: 1

        onStatusChanged: {
            if (status === Image.Ready) {
                root.commitPending();
            } else if (status === Image.Error && root.pendingPath) {
                console.warn("Wallpaper: image decode failed:", root.pendingPath);
                root.pendingPath = "";
                root.pendingForMonitor = false;
                root.pendingMonitor = "";
            }
        }
    }

    IpcHandler {
        target: "wallpaper"

        function get(): string {
            return root.get();
        }

        function set(path: string): string {
            return root.set(path);
        }

        function next(): string {
            return root.next();
        }

        function prev(): string {
            return root.prev();
        }

        function setFor(monitor: string, path: string): string {
            return root.setFor(monitor, path);
        }

        function clearFor(monitor: string): string {
            return root.clearFor(monitor);
        }
    }
}
