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
 * None of the three can hold the lock up. They read singletons that are already warm in
 * this same process, and the only thing this reads off Lock is the edge it seeds on.
 */
RowLayout {
    id: root

    readonly property real iconSize: Appearance.font.pixelSize.huge
    readonly property color foreground: Appearance.colors.colOnLayer0
    readonly property real slotSpacing: Appearance.font.pixelSize.smallest / 2

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

        sourceComponent: RowLayout {
            spacing: root.slotSpacing

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: Battery.symbol
                iconSize: root.iconSize
                fill: 1
                color: root.foreground
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: `${Math.round(Battery.percentage * 100)}%`
                color: root.foreground
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal
            }
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignVCenter

        spacing: root.slotSpacing
        // Hidden until the query answers, and hidden again if it never does. A lone keyboard
        // icon with no code beside it would be a worse answer than no answer.
        visible: KeyboardLayout.layout !== ""

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: "keyboard"
            iconSize: root.iconSize
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
