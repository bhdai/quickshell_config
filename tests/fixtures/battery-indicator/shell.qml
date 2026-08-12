import Quickshell
import QtQuick
import qs.modules.bar
import qs.services

/**
 * Builds the bar's battery indicator and its hover readout against the live Battery singleton.
 *
 * What this catches that the BatteryBody fixture cannot: that the indicator still supplies
 * every property the shared body now requires, and that the tooltip's content — which reads
 * chargeState and energyRate directly rather than through the body — still constructs. A
 * missing required property is a load-time failure, so reaching the log line at all is most of
 * the assertion.
 *
 * A FloatingWindow rather than the bar itself: a layer surface cannot be built with no Wayland
 * session to build it on.
 */
ShellRoot {
    FloatingWindow {
        implicitWidth: 400
        implicitHeight: 200
        visible: true

        BatteryIndicator {
            id: indicator
        }

        BatteryDetails {
            id: details
        }

        Timer {
            interval: 500
            running: true
            onTriggered: {
                console.log(`BATTERY_INDICATOR width=${Math.round(indicator.implicitWidth)} height=${Math.round(indicator.implicitHeight)} pluggedIn=${Battery.isPluggedIn} detailsHeight=${Math.round(details.implicitHeight)}`);
                Qt.quit();
            }
        }
    }
}
