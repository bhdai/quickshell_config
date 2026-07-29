import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import "LockFingerprint.js" as LockFingerprint

/**
 * The fingerprint affordance: one icon and one line, under the password prompt and clear
 * of it.
 *
 * It has its own feedback line for a reason that is not layout. The password message area
 * is the only place account lockout is ever visible — the stack refuses with a plain
 * failure and explains itself in text alone — so a fingerprint no-match landing there
 * would let an unrelated touch erase the one sentence the user most needs to read.
 *
 * Like the password prompt, it reads no singleton: what it shows arrives as `phase`, so a
 * test can walk every state with no reader behind it.
 */
Item {
    id: root

    // A LockLogic.Fingerprint value, mirrored by LockFingerprint.Phase.
    property string phase: LockFingerprint.Phase.Absent

    readonly property var treatment: LockFingerprint.treatment(root.phase)

    implicitWidth: line.implicitWidth
    implicitHeight: line.implicitHeight

    // Colour roles onto the palette, the same mapping the password prompt uses.
    function toneColor(tone: string): color {
        switch (tone) {
        case LockFingerprint.Tone.Error:
            return Appearance.colors.colError;
        case LockFingerprint.Tone.Success:
            return Appearance.colors.colPrimary;
        default:
            return Appearance.colors.colOnSurfaceVariant;
        }
    }

    Row {
        id: line

        anchors.centerIn: parent
        spacing: Appearance.font.pixelSize.smallest / 2

        // Faded rather than removed, so a reader that stops mid-lock leaves quietly
        // instead of snapping the composition shut under the pointer. The slot it
        // occupies is kept either way — on a machine with no reader it is empty space
        // below the prompt, which is cheaper than a layout that moves when a scan fails.
        opacity: root.treatment.visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
            }
        }

        MaterialSymbol {
            anchors.verticalCenter: copy.verticalCenter
            text: root.treatment.icon
            iconSize: Appearance.font.pixelSize.large
            color: root.toneColor(root.treatment.tone)

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                }
            }
        }

        Text {
            id: copy

            text: root.treatment.copy
            color: root.toneColor(root.treatment.tone)
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                }
            }
        }
    }
}
