import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * The battery indicator's hover readout: what the battery is doing and for how long.
 *
 * Rendered as a rich tooltip's content rather than as its own popup. Every row is a label and
 * a value behind its own icon, which M3's subhead-plus-supporting-text anatomy cannot express,
 * and rows come and go with what UPower actually knows — there is no time estimate at a
 * standstill and no health figure on a battery that never reported one.
 */
ColumnLayout {
    id: root

    spacing: 10

    function formatTime(seconds: real): string {
        if (seconds <= 0)
            return "";
        const totalMinutes = Math.round(seconds / 60);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        if (hours > 0)
            return hours + "h, " + minutes + "m";
        return minutes + "m";
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: {
            if (Battery.chargeState === UPowerDeviceState.FullyCharged)
                return false;
            const timeValue = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
            if (timeValue <= 0)
                return false;
            // A rate this low makes the remaining-time estimate meaningless rather than long.
            if (Battery.energyRate <= 0.01)
                return false;
            return true;
        }

        CustomIcon {
            width: 18
            height: 18
            source: "preferences-system-time-symbolic.svg"
            colorize: true
            color: Appearance.colors.colSubtext
        }

        Text {
            text: Battery.isCharging ? "Time to full:" : "Time to empty:"
            color: Appearance.colors.colSubtext
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smallPlus
        }

        Text {
            text: root.formatTime(Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty)
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smallPlus
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        // A standstill used to hide this row, which left the charge-threshold case — plugged in,
        // 0W, held below full — explaining itself with nothing at all. Only an unplugged
        // standstill is genuinely unreportable now.
        visible: Battery.isPluggedIn || Battery.chargeState === UPowerDeviceState.FullyCharged || Battery.energyRate !== 0

        MaterialSymbol {
            iconSize: 18
            fill: 1
            text: "bolt"
            color: Battery.isPluggedIn ? Appearance.colors.colBatteryCharging : Appearance.colors.colSubtext
        }

        Text {
            text: {
                if (Battery.chargeState === UPowerDeviceState.FullyCharged)
                    return "Fully charged";
                if (Battery.isCharging)
                    return "Charging: " + Battery.energyRate.toFixed(2) + "W";
                // Naming the cause rather than the symptom: bare "not charging" beside a full-
                // looking battery reads as a fault, and this state is the configured one.
                if (Battery.isPluggedIn)
                    return "Plugged in — charge limit reached";
                return "Discharging: " + Battery.energyRate.toFixed(2) + "W";
            }
            color: Battery.chargeState === UPowerDeviceState.FullyCharged ? Appearance.colors.colBatteryCharging : Appearance.colors.colOnSurfaceVariant
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smallPlus
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: Battery.health > 0

        CustomIcon {
            width: 18
            height: 18
            source: "emoji-nature-symbolic.svg"
            colorize: true
            color: Appearance.colors.colSubtext
        }

        Text {
            text: "Health:"
            color: Appearance.colors.colSubtext
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smallPlus
        }

        Text {
            text: Battery.health.toFixed(1) + "%"
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smallPlus
        }
    }

    // Uptime moved here when the dashboard dropped the duplicated clock: it belongs with the
    // other facts about how long this machine has been running rather than beside a calendar.
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            iconSize: 18
            text: "timer"
            color: Appearance.colors.colSubtext
        }

        Text {
            text: "Uptime:"
            color: Appearance.colors.colSubtext
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smallPlus
        }

        Text {
            text: Time.uptime
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smallPlus
        }
    }
}
