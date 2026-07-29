import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import "LockAuth.js" as LockAuth

/**
 * The password prompt: the field, the confirm control beside it, and one line of feedback
 * under both. Every outcome the lock can produce is legible here, and the three failures are
 * three visibly different treatments on purpose — a mistyped password means try again, a
 * lockout means wait, and a service failure means go and look at the machine.
 *
 * It reads no singleton. What it shows arrives as properties and what the user did leaves as
 * signals, which is what keeps the whole reach of the view layer in one place (LockSurface,
 * calling Lock.submit) and what lets a test drive all six states with no PAM behind it.
 */
Column {
    id: root

    // The field label, taken from the conversation rather than written here, so that changing
    // the PAM policy does not mean changing this file.
    property string prompt: ""
    property bool echo: false

    // Whether a response can be entered and sent at all: false while a result is in flight,
    // and false when there is no armed conversation to send it to.
    property bool inputAvailable: false
    property bool authenticating: false

    property string message: ""
    property string messageRole: LockAuth.Role.None

    // Dots to keep on screen while a response is in flight. The password itself is dropped at
    // submit, so its length is all there is left to draw.
    property int maskedLength: 0

    property alias text: input.text
    property alias cursorPosition: input.cursorPosition
    readonly property bool inputFocused: input.activeFocus

    readonly property string authState: LockAuth.fieldState(root.authenticating, root.messageRole, input.text.length > 0)
    readonly property var treatment: LockAuth.treatment(root.authState)

    signal submitted

    // The inner input holds the keyboard focus, so every key press arrives here first.
    // Forwarded raw, and synchronously, so the handler can still accept the event: which keys
    // open and close the prompt is the surface's business rather than this component's.
    signal keyPressed(var event)

    function restoreFocus(): void {
        input.forceActiveFocus();
    }

    // Colour roles onto the palette. Warning has no Material 3 role of its own, and tertiary
    // is the only other palette-derived accent — an amber literal would be the one colour on
    // this screen that a regenerated palette could not move.
    function toneColor(tone: string): color {
        switch (tone) {
        case LockAuth.Tone.Progress:
            return Appearance.colors.colPrimary;
        case LockAuth.Tone.Warning:
            return Appearance.colors.colTertiary;
        case LockAuth.Tone.Error:
        case LockAuth.Tone.Unavailable:
            return Appearance.colors.colError;
        default:
            return Appearance.colors.colOnSurfaceVariant;
        }
    }

    // Rejection and service failure share a colour, so the fill is what separates them: one
    // outlined field to type into again, one filled field about a machine that is not going
    // to answer.
    function toneFill(tone: string): color {
        if (!LockAuth.treatment(root.authState).filled)
            return Appearance.colors.colLayer1;

        return tone === LockAuth.Tone.Warning ? Appearance.colors.colTertiaryContainer : Appearance.colors.colErrorContainer;
    }

    spacing: Appearance.font.pixelSize.small

    onInputAvailableChanged: if (root.inputAvailable)
        root.restoreFocus()

    // Read from the state rather than from the `treatment` binding, which is a separate
    // dependent of the same change and need not have been re-evaluated yet.
    onAuthStateChanged: if (LockAuth.treatment(root.authState).shake)
        shake.restart()

    Component.onCompleted: root.restoreFocus()

    Rectangle {
        id: field

        // Far enough to read as a refusal from across the room, short enough not to look like
        // something broke.
        readonly property real shakeDistance: 7

        width: parent.width
        implicitHeight: Appearance.sizes.lockPasswordField
        radius: Appearance.rounding.full
        color: root.toneFill(root.treatment.tone)
        border.width: 1
        border.color: root.treatment.tone === LockAuth.Tone.Neutral ? (input.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant) : root.toneColor(root.treatment.tone)

        transform: Translate {
            id: shakeOffset
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
                target: shakeOffset
                property: "x"
                to: -field.shakeDistance
                duration: Appearance.animation.elementMoveFast.duration
            }
            NumberAnimation {
                target: shakeOffset
                property: "x"
                to: field.shakeDistance
                duration: Appearance.animation.elementMoveFast.duration
            }
            NumberAnimation {
                target: shakeOffset
                property: "x"
                to: 0
                duration: Appearance.animation.elementMoveFast.duration
            }
        }

        // The one moving part that says work is happening rather than that the machine has
        // stopped. Reset on stop, because the glyph under it turns back into an arrow and an
        // arrow left at 137 degrees is a bug rather than a state.
        NumberAnimation {
            target: confirmIcon
            property: "rotation"
            from: 0
            to: 360
            loops: Animation.Infinite
            duration: Appearance.animation.elementMoveSlow.duration * 2
            running: root.treatment.spin
            onRunningChanged: if (!running)
                confirmIcon.rotation = 0
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Appearance.font.pixelSize.normal
            anchors.rightMargin: Appearance.font.pixelSize.smallest / 2
            spacing: Appearance.font.pixelSize.smaller

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.treatment.fieldIcon
                iconSize: Appearance.font.pixelSize.hugeass
                color: root.toneColor(root.treatment.tone)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                TextInput {
                    id: input

                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    enabled: root.inputAvailable
                    focus: true
                    // Hidden rather than emptied while a response is in flight: the mask in
                    // its place stands in for a password that has already been dropped.
                    visible: !root.authenticating
                    echoMode: root.echo ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    color: Appearance.colors.colOnLayer0
                    selectByMouse: true
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    selectionColor: Appearance.m3colors.m3secondaryContainer
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal

                    // Enter on an empty field is not a submission. Sending it spends one of
                    // the account's failure-counter attempts on nothing, which is how a stray
                    // Return three times over ends in a lockout with nothing typed.
                    onAccepted: if (input.text.length > 0)
                        root.submitted()

                    Keys.onPressed: event => root.keyPressed(event)
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: !root.authenticating && input.text.length === 0
                    text: root.prompt
                    color: Appearance.colors.colSubtext
                    font.family: input.font.family
                    font.pixelSize: input.font.pixelSize
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: root.authenticating
                    text: "•".repeat(root.maskedLength)
                    color: Appearance.colors.colOnLayer0
                    font.family: input.font.family
                    font.pixelSize: input.font.pixelSize
                }
            }

            RippleButton {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: field.implicitHeight - Appearance.font.pixelSize.smallest
                implicitHeight: field.implicitHeight - Appearance.font.pixelSize.smallest
                padding: 0
                buttonRadius: Appearance.rounding.full
                enabled: root.inputAvailable && input.text.length > 0

                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colRipple: Appearance.colors.colPrimaryActive

                onClicked: root.submitted()

                contentItem: MaterialSymbol {
                    id: confirmIcon

                    text: root.treatment.submitIcon
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colOnPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // The icon is placed against the text rather than laid out beside it, so that the pair
    // reads as one line of feedback wherever the text happens to end up. A row would centre
    // the text and leave the symbol out at the edge of the field, where it reads as a widget
    // of its own rather than as part of the sentence.
    Item {
        readonly property real statusSpacing: Appearance.font.pixelSize.smallest / 2

        width: parent.width
        implicitHeight: statusText.height

        Text {
            id: statusText

            anchors.horizontalCenter: parent.horizontalCenter
            // Room kept for the icon on both sides, so a long lockout message wraps clear of
            // it instead of pushing it off the surface.
            width: parent.width - 2 * (statusIcon.width + parent.statusSpacing)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap

            // The message outranks the state's own copy — that is how the lockout text stays
            // on screen through the retype it explains. While a response is in flight it does
            // not: the previous outcome is stale the moment a new one is asked for.
            text: root.authenticating || root.message === "" ? root.treatment.copy : root.message
            color: root.toneColor(root.treatment.tone)
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
        }

        MaterialSymbol {
            id: statusIcon

            // Against the text's own content rather than its box, which is wider than the
            // sentence whenever the sentence is short.
            x: statusText.x + (statusText.width - statusText.contentWidth) / 2 - width - parent.statusSpacing
            anchors.verticalCenter: statusText.verticalCenter

            text: root.treatment.statusIcon
            iconSize: Appearance.font.pixelSize.large
            color: root.toneColor(root.treatment.tone)
        }
    }
}
