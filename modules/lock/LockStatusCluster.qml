import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
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
 * swallows presses is a dead zone. Consistency comes from sharing ClippedProgressBar,
 * CustomIcon and the Appearance tokens, which is where the bar's look actually lives.
 *
 * None of the three can hold the lock up. They read singletons that are already warm in
 * this same process, and the only thing this reads off Lock is the edge it seeds on.
 */
RowLayout {
    id: root

    readonly property real iconSize: Appearance.font.pixelSize.huge
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

        sourceComponent: Item {
            implicitWidth: batteryProgress.implicitWidth
            implicitHeight: batteryProgress.implicitHeight

            // The percentage is cut out of the filled body, so the icon and the number are
            // one shape — the same battery the bar draws, at the lock screen's scale.
            ClippedProgressBar {
                id: batteryProgress

                anchors.verticalCenter: parent.verticalCenter
                valueBarWidth: root.iconSize * 1.7
                valueBarHeight: root.iconSize
                value: Battery.percentage
                text: Math.round(Battery.percentage * 100)
                highlightColor: Battery.isCharging ? Appearance.colors.colBatteryCharging : (Battery.isCritical ? Appearance.colors.colBatteryCritical : root.foreground)
                trackColor: ColorUtils.transparentize(root.foreground, 0.5)
                font: Qt.font({
                    family: Appearance.font.family.main,
                    pixelSize: Appearance.font.pixelSize.smaller,
                    weight: Font.DemiBold
                })
                showNob: !Battery.isCharging || Battery.percentage >= 1
                nobFilled: Battery.percentage >= 1
            }

            // Takes the nob's place while charging, which is why the two are mutually
            // exclusive above rather than both drawn.
            MaterialSymbol {
                anchors.left: batteryProgress.right
                anchors.verticalCenter: batteryProgress.verticalCenter
                visible: Battery.isCharging && Battery.percentage < 1
                text: "bolt"
                iconSize: root.iconSize * 0.7
                fill: 1
                color: root.foreground
            }
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
