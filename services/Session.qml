pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // Session screen state
    property bool sessionOpen: false

    function toggleSession() {
        sessionOpen = !sessionOpen;
    }

    function closeSession() {
        sessionOpen = false;
    }

    function lock() {
        sessionOpen = false;
        Quickshell.execDetached(["loginctl", "lock-session"]);
    }

    function suspend() {
        sessionOpen = false;
        Quickshell.execDetached(["bash", "-c", "systemctl suspend || loginctl suspend"]);
    }

    function logout() {
        sessionOpen = false;
        Quickshell.execDetached(["pkill", "-i", "Hyprland"]);
    }

    function poweroff() {
        sessionOpen = false;
        Quickshell.execDetached(["bash", "-c", "systemctl poweroff || loginctl poweroff"]);
    }

    function reboot() {
        sessionOpen = false;
        Quickshell.execDetached(["bash", "-c", "reboot || loginctl reboot"]);
    }

    // Sets a one-shot EFI variable the firmware reads at power-on, so it is independent of the
    // boot loader. No `loginctl` fallback: it has no --firmware-setup, and the sibling
    // functions' fallbacks only exist because loginctl does accept those verbs.
    function rebootToFirmware() {
        sessionOpen = false;
        Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]);
    }
}
