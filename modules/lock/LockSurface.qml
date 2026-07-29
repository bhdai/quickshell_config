import QtQuick
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
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

    LockBackground {
        anchors.fill: parent
    }

    Item {
        anchors.fill: parent

        LockClock {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * root.clockCenterFraction - height / 2

            // One element shrinking as it travels. `scale` is about the item's centre, so
            // positioning by the unscaled height still lands the visual centre on the
            // fraction above.
            scale: root.revealed ? 0.58 : 1

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveSlow.duration
                    easing.type: Appearance.animation.elementMoveSlow.type
                    easing.bezierCurve: Appearance.animation.elementMoveSlow.bezierCurve
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveSlow.duration
                    easing.type: Appearance.animation.elementMoveSlow.type
                    easing.bezierCurve: Appearance.animation.elementMoveSlow.bezierCurve
                }
            }
        }

        LockProfile {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * root.profileTopFraction
            detailsVisible: !root.revealed

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveSlow.duration
                    easing.type: Appearance.animation.elementMoveSlow.type
                    easing.bezierCurve: Appearance.animation.elementMoveSlow.bezierCurve
                }
            }
        }

        Column {
            id: authArea

            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * root.authCenterFraction - height / 2
            width: Appearance.sizes.searchWidth
            spacing: Appearance.font.pixelSize.normal
            opacity: root.revealed ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveSlow.duration
                    easing.type: Appearance.animation.elementMoveSlow.type
                    easing.bezierCurve: Appearance.animation.elementMoveSlow.bezierCurve
                }
            }

            MaterialTextField {
                id: passwordField

                width: parent.width
                enabled: Lock.acceptingInput
                echoMode: Lock.echoResponse ? TextInput.Normal : TextInput.Password
                placeholderText: Lock.prompt
                focus: true

                onAccepted: Lock.submit()

                // Two-way sync with the singleton's password: it is the single source of
                // truth, so a second output's field shows what is typed on the first.
                onTextChanged: if (Lock.password !== text)
                    Lock.password = text

                // The field keeps focus while the screen is at rest, invisible and all, so
                // that the keystroke which asks for the prompt is typed into it rather
                // than being spent on opening it.
                Keys.onPressed: event => {
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
                        if (passwordField.text !== Lock.password) {
                            passwordField.text = Lock.password;
                            passwordField.cursorPosition = passwordField.text.length;
                        }
                    }

                    function onAcceptingInputChanged() {
                        if (Lock.acceptingInput)
                            passwordField.forceActiveFocus();
                    }
                }

                Component.onCompleted: passwordField.forceActiveFocus()
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Lock.authenticating ? "Authenticating…" : Lock.message
                color: Lock.messageIsProblem ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal
            }
        }

        // Above the composition so that a click anywhere at rest opens the prompt, and
        // disabled once it is open so the field and its controls get their own clicks.
        MouseArea {
            anchors.fill: parent
            enabled: !root.revealed

            onPressed: {
                Lock.authRevealed = true;
                passwordField.forceActiveFocus();
            }
        }
    }
}
