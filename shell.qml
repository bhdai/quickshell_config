//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.notificationPopup

ShellRoot {
    property bool enableNotifications: true
    Bar {}

    LazyLoader {
        active: enableNotifications
        
        Popups {}
    }
}
