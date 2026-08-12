import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * Network, battery and keyboard layout at the upper right — enough to decide whether to
 * plug in, or why a password keeps being rejected, without unlocking.
 *
 * The battery/network asymmetry is deliberate. Absence is meaningful for a battery: on a
 * machine with no battery there is nothing to say. Absence is ambiguous for a network,
 * because a missing icon and no connection look identical, so it always renders and leans
 * on the shared symbol selection's explicit disconnected symbol.
 *
 * The network shows no name. The icon answers "am I online", which is what matters while
 * locked; the name only tells a passer-by which network the machine is on.
 *
 * Built from the widgets the bar composes its own indicators from rather than from the
 * indicators themselves: BatteryIndicator is a hover-target wrapping a popup window, and on
 * a surface where a click anywhere is what opens the password prompt, a MouseArea that
 * swallows presses is a dead zone. Sharing BatteryBody rather than that wrapper gets the
 * battery's whole appearance — including which glyph a given power state draws — from one
 * place, while leaving the interaction behind.
 *
 * None of the three can hold the lock up. They read singletons that are already warm in
 * this same process, and the only thing this reads off Lock is the edge it seeds on.
 */
RowLayout {
    id: root

    readonly property real iconSize: Appearance.sizes.statusIcon
    readonly property color foreground: Appearance.colors.colOnLayer0

    spacing: Appearance.font.pixelSize.normal

    CustomIcon {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: root.iconSize
        Layout.preferredHeight: root.iconSize

        source: Network.symbol
        colorize: true
        color: root.foreground
    }

    Loader {
        Layout.alignment: Qt.AlignVCenter

        active: Battery.available
        visible: active

        // Body size, glyph and text style are the widget's own defaults, which is exactly what
        // BatteryIndicator leaves them at — overriding any of them here would be the lock
        // screen drifting away from the bar rather than matching it.
        sourceComponent: BatteryBody {
            percentage: Battery.percentage
            isCharging: Battery.isCharging
            isPluggedIn: Battery.isPluggedIn
            isCritical: Battery.isCritical
            foreground: root.foreground
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignVCenter

        spacing: Appearance.font.pixelSize.smallest / 2
        // Hidden until the query answers, and hidden again if it never does. A lone keyboard
        // icon with no code beside it would be a worse answer than no answer.
        visible: KeyboardLayout.layout !== ""

        CustomIcon {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.iconSize
            Layout.preferredHeight: root.iconSize

            source: "input-keyboard-symbolic"
            colorize: true
            color: root.foreground
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: KeyboardLayout.layout
            color: root.foreground
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.normal
        }
    }

    // Seeded on the compositor-confirmed lock rather than at shell start, so the layout is
    // read at the moment it is about to be shown.
    Connections {
        target: Lock

        function onSecureChanged(): void {
            if (Lock.secure)
                KeyboardLayout.refresh();
        }
    }

    // A surface built while `secure` is already up gets no edge of its own — the mirrored
    // output, and every hot reload that keeps the lock alive.
    Component.onCompleted: if (Lock.secure)
        KeyboardLayout.refresh()
}
