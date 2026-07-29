import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import "LockFingerprint.js" as LockFingerprint

/**
 * The fingerprint affordance: an outlined chip under the password prompt, holding one
 * icon and one line.
 *
 * It has its own feedback line for a reason that is not layout. The password message area
 * is the only place account lockout is ever visible — the stack refuses with a plain
 * failure and explains itself in text alone — so a fingerprint no-match landing there
 * would let an unrelated touch erase the one sentence the user most needs to read.
 *
 * Like the password prompt, it reads no singleton: what it shows arrives as `phase`, so a
 * test can walk every state with no reader behind it.
 *
 * There is no scanning state. The approved prototype has one, but nothing on this path can
 * report it: the result codes say only how a completed scan ended, and the message that
 * would carry "a finger is on the sensor" is exactly the translated, device-specific text
 * this screen refuses to render.
 */
Item {
    id: root

    // A LockLogic.Fingerprint value, mirrored by LockFingerprint.Phase.
    property string phase: LockFingerprint.Phase.Absent

    readonly property var treatment: LockFingerprint.treatment(root.phase)

    implicitWidth: chip.implicitWidth
    implicitHeight: Appearance.sizes.lockFingerprintChip

    // Colour roles onto the palette. The chip is drawn over a blurred wallpaper rather
    // than over a solid layer, so its resting fill is translucent — enough to hold the
    // text legibly without becoming a second solid slab under the password field.
    function toneText(tone: string): color {
        switch (tone) {
        case LockFingerprint.Tone.Error:
            return Appearance.colors.colError;
        case LockFingerprint.Tone.Success:
            return Appearance.colors.colOnPrimaryContainer;
        default:
            return Appearance.colors.colOnLayer0;
        }
    }

    // The one place the icon outranks the text it sits beside: an accent fingerprint on an
    // otherwise quiet chip is what makes it read as an offer rather than as a label.
    function toneIcon(tone: string): color {
        return tone === LockFingerprint.Tone.Neutral ? Appearance.colors.colPrimary : root.toneText(tone);
    }

    function toneBorder(tone: string): color {
        switch (tone) {
        case LockFingerprint.Tone.Error:
            return Appearance.colors.colError;
        case LockFingerprint.Tone.Success:
            return Appearance.colors.colPrimary;
        default:
            return ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.3);
        }
    }

    function toneFill(tone: string): color {
        return tone === LockFingerprint.Tone.Success ? Appearance.colors.colPrimaryContainer : ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.56);
    }

    // Read from the phase rather than from the `treatment` binding, which is a separate
    // dependent of the same change and need not have been re-evaluated yet.
    onPhaseChanged: if (LockFingerprint.treatment(root.phase).shake)
        shake.restart()

    Rectangle {
        id: chip

        // Far enough to read as a refusal from across the room, short enough not to look
        // like something broke. The same distance the chip rises through on its way in,
        // so arriving and being refused are one vocabulary.
        readonly property real travel: 7

        anchors.centerIn: parent
        implicitWidth: line.implicitWidth + 2 * Appearance.font.pixelSize.small
        implicitHeight: Appearance.sizes.lockFingerprintChip
        radius: Appearance.rounding.full
        color: root.toneFill(root.treatment.tone)
        border.width: 1
        border.color: root.toneBorder(root.treatment.tone)

        // Faded rather than removed, so a reader that stops mid-lock leaves quietly
        // instead of snapping the composition shut under the pointer. The slot it
        // occupies is kept either way — on a machine with no reader it is empty space
        // below the prompt, which is cheaper than a layout that moves when a scan fails.
        opacity: root.treatment.visible ? 1 : 0

        transform: Translate {
            id: offset

            y: root.treatment.visible ? 0 : chip.travel
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
            }
        }

        SequentialAnimation {
            id: shake

            NumberAnimation {
                target: offset
                property: "x"
                to: -chip.travel
                duration: Appearance.animation.elementMoveFast.duration
            }
            NumberAnimation {
                target: offset
                property: "x"
                to: chip.travel
                duration: Appearance.animation.elementMoveFast.duration
            }
            NumberAnimation {
                target: offset
                property: "x"
                to: 0
                duration: Appearance.animation.elementMoveFast.duration
            }
        }

        Row {
            id: line

            anchors.centerIn: parent
            spacing: Appearance.font.pixelSize.smallest

            MaterialSymbol {
                anchors.verticalCenter: copy.verticalCenter
                text: root.treatment.icon
                iconSize: Appearance.font.pixelSize.hugeass
                color: root.toneIcon(root.treatment.tone)

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
                color: root.toneText(root.treatment.tone)
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
}
