import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.dashboard
import qs.services

ShellRoot {
    id: root

    readonly property string pixelPath: Quickshell.env("WALLPAPER_INTERACTION_PIXEL") ?? ""
    readonly property string libraryPath: Wallpaper.library
    readonly property string initialAppliedPath: `${libraryPath}/18.png`
    property int phase: 0
    property int attempts: 0
    property int mutationPhase: 0
    property string removedLastPath: ""

    function require(condition: bool, message: string): bool {
        if (condition)
            return true;
        console.error("WALLPAPER_INTERACTION FAIL " + message);
        Qt.quit();
        return false;
    }

    function mutate(command: list<string>, nextPhase: int): void {
        root.phase = -1;
        root.mutationPhase = nextPhase;
        mutator.command = command;
        mutator.running = true;
    }

    function finish(): void {
        console.log("WALLPAPER_INTERACTION passed");
        Qt.quit();
    }

    Process {
        id: mutator

        onExited: exitCode => {
            if (!root.require(exitCode === 0, `mutation exited ${exitCode}`))
                return;
            root.attempts = 0;
            root.phase = root.mutationPhase;
        }
    }

    FloatingWindow {
        id: window

        implicitWidth: 900
        implicitHeight: 700
        visible: true

        DashboardCard {
            id: card
            currentTab: "wallpaper"
        }

        Timer {
            interval: 50
            repeat: true
            running: true

            onTriggered: {
                root.attempts++;
                if (root.attempts > 120) {
                    root.require(false, `timeout in phase ${root.phase}`);
                    return;
                }
                if (root.phase < 0 || !card.paneItem)
                    return;

                const pane = card.paneItem;

                if (root.phase === 0) {
                    if (Wallpaper.libraryModel.count !== 18 || !card.activeTabFocused)
                        return;
                    if (!root.require(!pane.gridFocused, "opening moved focus into the grid")
                            || !root.require(pane.focusedPath === "", "opening assigned a focused path")
                            || !root.require(pane.viewport.contentY === 105,
                                `opening revealed contentY=${pane.viewport.contentY}, expected 105`))
                        return;

                    if (!root.require(pane.focusEntry(), "Tab entry found no target")
                            || !root.require(pane.focusedPath === root.initialAppliedPath,
                                `entry chose ${pane.focusedPath}`)
                            || !root.require(pane.focusedIndex === 17, `entry index=${pane.focusedIndex}`)
                            || !root.require(pane.gridFocused, "entry did not move keyboard focus"))
                        return;

                    pane.moveFocus("right");
                    if (!root.require(pane.focusedIndex === 17, "Right entered a missing final-row cell"))
                        return;
                    pane.focusIndex(15);
                    pane.moveFocus("right");
                    if (!root.require(pane.focusedIndex === 15, "Right wrapped from the row edge"))
                        return;
                    pane.focusIndex(0);
                    pane.moveFocus("left");
                    pane.moveFocus("up");
                    if (!root.require(pane.focusedIndex === 0, "navigation crossed the top-left edge"))
                        return;
                    pane.focusIndex(4);
                    pane.moveFocus("up");
                    pane.moveFocus("down");
                    if (!root.require(pane.focusedIndex === 4, "vertical movement did not preserve the column"))
                        return;
                    pane.focusIndex(14);
                    pane.moveFocus("down");
                    if (!root.require(pane.focusedIndex === 14, "Down entered a missing final-row cell"))
                        return;
                    pane.focusIndex(13);
                    pane.moveFocus("down");
                    if (!root.require(pane.focusedIndex === 17, "Down did not move exactly four cells"))
                        return;
                    pane.focusIndex(0);
                    if (!root.require(pane.viewport.contentY === 0,
                            `top focus left contentY=${pane.viewport.contentY}`))
                        return;
                    pane.focusIndex(17);
                    if (!root.require(pane.viewport.contentY === 105,
                            `bottom focus set contentY=${pane.viewport.contentY}`))
                        return;

                    pane.focusIndex(4);
                    pane.activateFocused();
                    root.phase = 1;
                    root.attempts = 0;
                    return;
                }

                if (root.phase === 1) {
                    const applied = `${root.libraryPath}/05.png`;
                    if (Wallpaper.wallpaper !== applied)
                        return;
                    if (!root.require(pane.focusedPath === applied && pane.gridFocused,
                            "activation changed focus")
                            || !root.require(pane.returnFocusToTab() && card.activeTabFocused,
                                "Tab did not return focus to the active label")
                            || !root.require(pane.focusEntry() && pane.focusedPath === applied,
                                "grid re-entry did not prefer the applied tile"))
                        return;

                    pane.focusIndex(8);
                    root.mutate(["cp", root.pixelPath, `${root.libraryPath}/00.png`], 2);
                    return;
                }

                if (root.phase === 2) {
                    if (Wallpaper.libraryModel.count !== 19 || pane.focusedIndex !== 9)
                        return;
                    if (!root.require(pane.focusedPath === `${root.libraryPath}/09.png`
                                && pane.gridFocused,
                            "insertion did not preserve path identity"))
                        return;
                    root.mutate(["rm", `${root.libraryPath}/09.png`], 3);
                    return;
                }

                if (root.phase === 3) {
                    if (Wallpaper.libraryModel.count !== 18
                            || pane.focusedPath !== `${root.libraryPath}/10.png`)
                        return;
                    if (!root.require(pane.focusedIndex === 9 && pane.gridFocused,
                            "focused removal did not choose the tile at the old index"))
                        return;
                    root.mutate(["rm", `${root.libraryPath}/05.png`], 4);
                    return;
                }

                if (root.phase === 4) {
                    if (Wallpaper.libraryModel.count !== 17 || pane.focusedIndex !== 8)
                        return;
                    if (!root.require(Wallpaper.wallpaper === `${root.libraryPath}/05.png`,
                            "removing the applied file unset the displayed wallpaper")
                            || !root.require(pane.appliedIndex() === -1,
                                "removed applied file retained an indicator")
                            || !root.require(pane.focusedPath === `${root.libraryPath}/10.png`,
                                "unrelated removal changed focus identity"))
                        return;

                    pane.focusIndex(Wallpaper.libraryModel.count - 1);
                    root.removedLastPath = pane.focusedPath;
                    root.mutate(["rm", root.removedLastPath], 5);
                    return;
                }

                if (root.phase === 5) {
                    if (Wallpaper.libraryModel.count !== 16 || pane.focusedIndex !== 15)
                        return;
                    if (!root.require(pane.focusedPath === `${root.libraryPath}/17.png`,
                            "removing the final tile did not choose the new final tile"))
                        return;

                    const command = ["rm"];
                    for (let index = 0; index < Wallpaper.libraryModel.count; ++index)
                        command.push(pane.pathAt(index));
                    root.mutate(command, 6);
                    return;
                }

                if (root.phase === 6) {
                    if (Wallpaper.libraryModel.count !== 0 || !card.activeTabFocused)
                        return;
                    if (!root.require(!pane.gridFocused && pane.focusedPath === ""
                                && pane.focusedIndex === -1,
                            "empty transition left a grid focus target"))
                        return;
                    root.finish();
                }
            }
        }
    }
}
