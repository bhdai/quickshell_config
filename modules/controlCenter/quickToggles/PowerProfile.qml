import qs.modules.common
import qs.modules.common.widgets
import Quickshell.Services.UPower
import QtQuick

QuickToggleButton {
    id: root

    property string currentProfile: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "power-profile-power-saver-symbolic";
        case PowerProfile.Balanced:
            return "power-profile-balanced-symbolic";
        case PowerProfile.Performance:
            return "power-profile-performance-symbolic";
        default:
            return "power-profile-balanced-symbolic";
        }
    }

    contentItem: Item {
        implicitWidth: 24
        implicitHeight: 24

        CustomIcon {
            id: cloudflareIcon
            source: root.currentProfile

            anchors.centerIn: parent
            width: 24
            height: 24
            colorize: true
            color: Colors.background

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.34, 0.80, 0.34, 1.00, 1, 1]
                }
            }
        }
    }

    toggled: true

    onClicked: cycleProfile()

    function cycleProfile(): void {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            PowerProfiles.profile = PowerProfile.Balanced;
            break;
        case PowerProfile.Balanced:
            if (PowerProfiles.hasPerformanceProfile) {
                PowerProfiles.profile = PowerProfile.Performance;
            } else {
                PowerProfiles.profile = PowerProfile.PowerSaver;
            }
            break;
        case PowerProfile.Performance:
            PowerProfiles.profile = PowerProfile.PowerSaver;
            break;
        }
    }
}
