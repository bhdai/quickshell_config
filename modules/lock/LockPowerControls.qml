import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "LockPower.js" as LockPower

/**
 * Suspend, restart and shutdown, usable without authenticating.
 *
 * Unauthenticated is the decision rather than an oversight: a local attacker can already
 * hold the physical power button, so gating these buys no security while costing the case
 * the controls exist for — suspending the laptop from the lock screen before closing the
 * lid. Nothing here reads the lock state, which is what keeps that from drifting.
 *
 * The confirm on restart and shutdown guards unsaved work, not the session.
 *
 * Lock-owned rather than the session screen's button: that button has no confirm state and
 * is sized for a centred grid, and growing a shared type to serve a requirement only this
 * screen has is what the surgical-changes rule exists to stop. The two look like one system
 * because they draw on the same Appearance tokens, not because they share a type.
 */
RowLayout {
    id: root

    // The action awaiting a confirming press, "" if none. It lives here rather than on the
    // Lock singleton because nothing on the unlock path has any business reading it.
    property string pending: ""

    spacing: Appearance.font.pixelSize.normal

    function press(action: string): void {
        const outcome = LockPower.press(action, root.pending);
        root.pending = outcome.pending;

        switch (outcome.invoke) {
        case LockPower.Action.Suspend:
            Session.suspend();
            break;
        case LockPower.Action.Reboot:
            Session.reboot();
            break;
        case LockPower.Action.PowerOff:
            Session.poweroff();
            break;
        }
    }

    Repeater {
        model: LockPower.Actions

        delegate: ColumnLayout {
            id: control

            required property string modelData

            readonly property bool armed: root.pending === control.modelData

            Layout.alignment: Qt.AlignVCenter
            spacing: Appearance.font.pixelSize.smallest / 2

            RippleButton {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Appearance.sizes.lockPowerButton
                implicitHeight: Appearance.sizes.lockPowerButton
                padding: 0
                buttonRadius: Appearance.rounding.full

                // The armed control turns the error role on itself, so what is about to
                // happen is legible from the colour before the label is read.
                colBackground: control.armed ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer2
                colBackgroundHover: control.armed ? Appearance.colors.colErrorContainerHover : Appearance.colors.colLayer2Hover
                colRipple: control.armed ? Appearance.colors.colErrorContainerActive : Appearance.colors.colPrimaryActive

                onClicked: root.press(control.modelData)

                contentItem: MaterialSymbol {
                    text: LockPower.symbol(control.modelData)
                    iconSize: Appearance.font.pixelSize.hugeass
                    color: control.armed ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: LockPower.label(control.modelData, root.pending)
                color: control.armed ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
    }
}
