import QtQuick
import Quickshell.Wayland
import qs.modules.common
import qs.services
import "LockReveal.js" as LockReveal

/**
 * The lock screen itself. It holds no reference to the WlSessionLock, so there is no
 * object here on which anything could set `locked`: it reads `Lock` and calls
 * `Lock.submit()`, and that is the whole of its reach.
 *
 * At rest the screen is quiet — a large clock over the blurred wallpaper and the profile
 * near the bottom. Typing or clicking reveals the authentication area: the clock shrinks
 * into the upper quarter and the one profile element rises above the prompt. Escape from
 * an empty field reverses exactly the same animation, which is what makes reveal and
 * dismiss the same pace by construction rather than by two matching numbers.
 */
WlSessionLockSurface {
    id: root

    // Opaque by construction. Appearance.colors.colLayer0 carries the user's background
    // transparency, which on a lock surface would let the desktop show through.
    color: Appearance.m3colors.m3background

    // Held on the singleton beside the password, and for the same reason: the mirrored
    // output reveals and dismisses with the one that has keyboard focus instead of
    // diverging from it. It is view state — nothing here can unlock.
    readonly property bool revealed: Lock.authRevealed

    // Vertical positions as fractions of the surface, so the composition holds its shape
    // on an output of any size rather than being pinned to the prototype's 1600x900.
    readonly property real clockCenterFraction: root.revealed ? 0.25 : 0.46
    readonly property real profileTopFraction: root.revealed ? 0.56 : 0.78
    readonly property real authCenterFraction: 0.72

    // The entrance, as one pair of drivers every part of the composition reads. This needs
    // no lifecycle hook beyond construction, because the surface is constructed at the
    // moment the lock is raised.
    property real entranceScale: 0.9
    property real entranceOpacity: 0

    Component.onCompleted: {
        root.entranceScale = 1;
        root.entranceOpacity = 1;
    }

    Behavior on entranceScale {
        NumberAnimation {
            duration: Appearance.animation.compositionTravel.duration
            easing.type: Appearance.animation.compositionTravel.type
            easing.bezierCurve: Appearance.animation.compositionTravel.bezierCurve
        }
    }

    Behavior on entranceOpacity {
        NumberAnimation {
            duration: Appearance.animation.compositionTravel.duration
            easing.type: Appearance.animation.compositionTravel.type
            easing.bezierCurve: Appearance.animation.compositionTravel.bezierCurve
        }
    }

    // Outside the entrance on purpose. This is the opaque backstop the content animates
    // over: fading or scaling it in with everything else would make the entrance a window
    // onto the unlocked session for as long as it ran.
    LockBackground {
        anchors.fill: parent
    }

    Item {
        anchors.fill: parent

        opacity: root.entranceOpacity
        scale: root.entranceScale

        LockStatusCluster {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Appearance.font.pixelSize.hugeass
        }

        LockClock {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * root.clockCenterFraction - height / 2

            // One element shrinking as it travels. `scale` is about the item's centre, so
            // positioning by the unscaled height still lands the visual centre on the
            // fraction above.
            scale: root.revealed ? 0.58 : 1

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.animation.compositionTravel.duration
                    easing.type: Appearance.animation.compositionTravel.type
                    easing.bezierCurve: Appearance.animation.compositionTravel.bezierCurve
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.animation.compositionTravel.duration
                    easing.type: Appearance.animation.compositionTravel.type
                    easing.bezierCurve: Appearance.animation.compositionTravel.bezierCurve
                }
            }
        }

        LockProfile {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * root.profileTopFraction
            detailsVisible: !root.revealed

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.animation.compositionTravel.duration
                    easing.type: Appearance.animation.compositionTravel.type
                    easing.bezierCurve: Appearance.animation.compositionTravel.bezierCurve
                }
            }
        }

        // The prompt and the chip under it are one thing arriving — as they are in the
        // approved prototype, where the chip sits inside the auth area — so they fade and
        // rise as one element, quicker than the composition still travelling behind them.
        Item {
            anchors.fill: parent

            opacity: root.revealed ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.compositionAppear.duration
                    easing.type: Appearance.animation.compositionAppear.type
                    easing.bezierCurve: Appearance.animation.compositionAppear.bezierCurve
                }
            }

            // A transform rather than an offset in `y`: the position a layout produces has to
            // stay the layout's, or a message growing the prompt would animate as a reveal.
            transform: Translate {
                y: root.revealed ? 0 : Appearance.sizes.lockRevealRise

                Behavior on y {
                    NumberAnimation {
                        duration: Appearance.animation.compositionAppear.riseDuration
                        easing.type: Appearance.animation.compositionAppear.type
                        easing.bezierCurve: Appearance.animation.compositionAppear.bezierCurve
                    }
                }
            }

            LockAuthArea {
                id: authArea

                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * root.authCenterFraction - height / 2
                width: Appearance.sizes.searchWidth

                prompt: Lock.prompt
                echo: Lock.echoResponse
                inputAvailable: Lock.acceptingInput
                authenticating: Lock.authenticating
                message: Lock.message
                messageRole: Lock.messageRole
                maskedLength: Lock.submittedLength

                onSubmitted: Lock.submit()

                // Two-way sync with the singleton's password: it is the single source of truth,
                // so a second output's field shows what is typed on the first.
                onTextChanged: if (Lock.password !== authArea.text)
                    Lock.password = authArea.text

                // Every key press arrives here because the prompt holds the keyboard focus even
                // at rest, transparent and all: the keystroke that asks for the prompt is typed
                // into the field rather than being spent on opening it.
                onKeyPressed: event => {
                    const action = LockReveal.keyAction(root.revealed, event.text, event.key === Qt.Key_Escape, Lock.password.length === 0);
                    switch (action) {
                    case LockReveal.Action.Reveal:
                        Lock.authRevealed = true;
                        break;
                    case LockReveal.Action.ClearPassword:
                        Lock.password = "";
                        event.accepted = true;
                        break;
                    case LockReveal.Action.Rest:
                        Lock.authRevealed = false;
                        event.accepted = true;
                        break;
                    }
                }

                Connections {
                    target: Lock

                    function onPasswordChanged() {
                        if (authArea.text !== Lock.password) {
                            authArea.text = Lock.password;
                            authArea.cursorPosition = authArea.text.length;
                        }
                    }
                }
            }

            // Under the prompt rather than inside it. The reader is armed for the whole of the
            // lock and can win from the resting view without any of this being on screen, so
            // this is feedback about a factor already running, not a control.
            LockFingerprint {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: authArea.bottom
                anchors.topMargin: Appearance.font.pixelSize.smaller

                phase: Lock.fingerprintState
            }
        }

        LockPowerControls {
            id: powerControls

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.font.pixelSize.hugeass

            opacity: root.revealed ? 1 : 0
            // Absent rather than merely transparent: an invisible control still takes the
            // press that is supposed to open the prompt.
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.compositionAppear.duration
                    easing.type: Appearance.animation.compositionAppear.type
                    easing.bezierCurve: Appearance.animation.compositionAppear.bezierCurve
                }
            }

            transform: Translate {
                y: root.revealed ? 0 : Appearance.sizes.lockRevealRise

                Behavior on y {
                    NumberAnimation {
                        duration: Appearance.animation.compositionAppear.riseDuration
                        easing.type: Appearance.animation.compositionAppear.type
                        easing.bezierCurve: Appearance.animation.compositionAppear.bezierCurve
                    }
                }
            }

            // Backing out of the prompt backs out of the arming with it, so a shutdown
            // armed and then dismissed is not still armed the next time it reveals.
            Connections {
                target: root

                function onRevealedChanged(): void {
                    if (!root.revealed)
                        powerControls.pending = "";
                }
            }
        }

        // Above the composition so that a click anywhere at rest opens the prompt. Once it is
        // open the press is passed on instead of eaten, so the field and the power controls
        // under this still get their own clicks.
        MouseArea {
            anchors.fill: parent

            // Hover costs something and is only wanted when there is focus to restore, which
            // is also what keeps this from sitting between the pointer and a power control's
            // own hover feedback for the rest of the time.
            hoverEnabled: Lock.acceptingInput && !authArea.inputFocused

            onPositionChanged: authArea.restoreFocus()

            onPressed: mouse => {
                // Read before the reveal, not after: the press that opens the prompt is spent
                // on opening it, or a click landing where the confirm control is about to
                // appear would submit an empty password on the way past.
                mouse.accepted = !root.revealed;

                Lock.authRevealed = true;
                authArea.restoreFocus();
            }
        }
    }
}
