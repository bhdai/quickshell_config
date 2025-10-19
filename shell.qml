//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.notificationPopup
import qs.modules.OSD
import qs.services

ShellRoot {
    property bool enableNotifications: true

    property var brightness: Brightness

    Bar {}

    LazyLoader {
        active: enableNotifications

        Popups {}
    }

    OSD {}
}
