//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.launcher
import qs.modules.lock
import qs.modules.notificationPopup
import qs.modules.OSD
import qs.modules.sessionScreen
import qs.modules.wallpaper
import qs.services

ShellRoot {
    // While the screen is locked, do not add, remove, or reorder the
    // items in this list. A reloading generation matches its objects to
    // the old one's by index position among their parent's children --
    // never by id -- so reshaping this list orphans the lock's
    // WlSessionLock and strands the session locked with no client, with
    // qFatal if only the lock's index moved and silently otherwise.
    // Editing the *contents* of any file, this one included, is safe.
    // Recovery from a stranded session is on Hyprland's own lockdead
    // screen; AGENTS.md covers developing the lock without ever
    // reaching that state.

    property var brightness: Brightness
    property var gameMode: GamingModeService
    property var warp: WarpService
    property var materialTheme: MaterialThemeLoader
    property var screenZoom: ScreenZoom
    property var powerProfile: PowerProfileService
    property var session: Session

    // Initialize launcher services
    property var _appSearch: AppSearch
    property var _cliphist: Cliphist
    property var _emojis: Emojis
    property var _launcherSearch: LauncherSearch

    property bool enableNotificationPopup: true
    property bool enableOSD: true

    Bar {}

    Launcher {}

    SessionScreen {}

    LazyLoader {
        active: enableNotificationPopup
        Popups {}
    }

    LazyLoader {
        active: enableOSD
        OSD {}
    }

    LockModule {}

    WallpaperModule {}
}
