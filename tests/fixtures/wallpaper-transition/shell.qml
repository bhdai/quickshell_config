import QtQuick
import Quickshell
import qs.modules.wallpaper
import qs.services

ShellRoot {
    id: root

    readonly property string firstPath: Quickshell.env("WALLPAPER_TEST_FIRST") ?? ""
    readonly property string secondPath: Quickshell.env("WALLPAPER_TEST_SECOND") ?? ""
    property int ticks: 0
    property int phase: 0
    property int phaseTick: 0

    function finish(message: string): void {
        console.log("WALLPAPER_TRANSITION_RESULT " + message);
        Qt.quit();
    }

    WallpaperModule {
        id: wallpaperModule
    }

    Timer {
        interval: 50
        repeat: true
        running: true

        onTriggered: {
            root.ticks++;
            if (wallpaperModule.surfaces.length !== 1)
                return;

            const surface = wallpaperModule.surfaces[0];
            if (root.phase === 0) {
                root.phase = 1;
                Wallpaper.set(root.firstPath);
            } else if (root.phase === 1 && surface.displayed === root.firstPath) {
                root.phase = 2;
                root.phaseTick = root.ticks;
                Wallpaper.set(root.secondPath);
            } else if (root.phase === 2 && Wallpaper.get() === root.secondPath
                    && root.ticks - root.phaseTick > 14) {
                root.phase = 3;
                root.phaseTick = root.ticks;
                Wallpaper.set(root.firstPath);
            } else if (root.phase === 3 && Wallpaper.get() === root.firstPath
                    && root.ticks - root.phaseTick > 24) {
                root.finish(`target=${surface.target} displayed=${surface.displayed}`
                    + ` loading=${surface.loadingTarget}`
                    + ` transitioning=${surface.transitioning}`);
            } else if (root.ticks > 120) {
                root.finish(`timeout phase=${root.phase} target=${surface.target}`
                    + ` displayed=${surface.displayed} loading=${surface.loadingTarget}`
                    + ` transitioning=${surface.transitioning}`);
            }
        }
    }
}
