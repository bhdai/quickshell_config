//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.notificationPopup
import qs.modules.OSD
import qs.services

ShellRoot {
    property var brightness: Brightness
    property var gameMode: GamingModeService

    property bool enableNotificationPopup: true
    property bool enableOSD: true

    Bar {}

    LazyLoader {
        active: enableNotificationPopup
        Popups {}
    }

    LazyLoader {
        active: enableOSD
        OSD {}
    }
}
