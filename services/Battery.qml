pragma Singleton

// import qs
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import Quickshell.Io

Singleton {
    property bool available: UPower.displayDevice.isLaptopBattery
    property var chargeState: UPower.displayDevice.state
    property bool isCharging: chargeState == UPowerDeviceState.Charging

    // Derived from the line-power supplies rather than from the battery's own state, because
    // the battery reports plugged-in-not-charging inconsistently: a charge threshold parks it
    // in PendingCharge, but a full battery on AC reports FullyCharged and some hardware reports
    // Discharging at 0W while docked. All three are "the cable is in".
    property bool isPluggedIn: !UPower.onBattery
    property real percentage: UPower.displayDevice?.percentage ?? 1
    readonly property bool allowAutomaticSuspend: true

    property bool isLow: available && (percentage <= 0.5)
    property bool isCritical: available && (percentage <= 0.2)
    property bool isSuspending: available && (percentage <= 0.1)

    // Gated on being unplugged rather than on not charging: a battery held below its start
    // threshold is plugged in and idle, and warning about a charger that is already attached —
    // or worse, suspending the machine — would be wrong.
    property bool isLowAndUnplugged: isLow && !isPluggedIn
    property bool isCriticalAndUnplugged: isCritical && !isPluggedIn
    property bool isSuspendingAndUnplugged: allowAutomaticSuspend && isSuspending && !isPluggedIn

    property real energyRate: UPower.displayDevice.changeRate
    property real timeToEmpty: UPower.displayDevice.timeToEmpty
    property real timeToFull: UPower.displayDevice.timeToFull

    // Battery health from UPower devices (returns 0 if not supported)
    property real health: {
        for (let i = 0; i < UPower.devices.values.length; i++) {
            let device = UPower.devices.values[i];
            if (device.isLaptopBattery && device.healthSupported) {
                let hp = device.healthPercentage;
                // Normalize: if < 1, it's a fraction (0-1); multiply by 100
                // If 0, return small value to indicate unknown but supported
                if (hp <= 0) return 0;
                return hp < 1 ? hp * 100 : hp;
            }
        }
        return 0; // No health-supported battery found
    }

    onIsLowAndUnpluggedChanged: {
        if (available && isLowAndUnplugged)
            Quickshell.execDetached(["notify-send", "Low battery", "Consider plugging in your device", "-u", "critical", "-a", "Shell"]);
    }

    onIsCriticalAndUnpluggedChanged: {
        if (available && isCriticalAndUnplugged)
            Quickshell.execDetached(["notify-send", "Critical low battery", "Plug in your device immediately.\nAutomatic suspend at 10%", "-u", "critical", "-a", "Shell"]);
    }

    onIsSuspendingAndUnpluggedChanged: {
        if (available && isSuspendingAndUnplugged) {
            Quickshell.execDetached(["bash", "-c", `systemctl suspend || loginctl suspend`]);
        }
    }
}
