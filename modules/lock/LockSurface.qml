import QtQuick
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * The lock screen itself. It holds no reference to the WlSessionLock, so there is no
 * object here on which anything could set `locked`: it reads `Lock` and calls
 * `Lock.submit()`, and that is the whole of its reach.
 */
WlSessionLockSurface {
    id: root

    // Opaque by construction. Appearance.colors.colLayer0 carries the user's background
    // transparency, which on a lock surface would let the desktop show through.
    color: Appearance.m3colors.m3background

    Item {
        anchors.fill: parent
        focus: true

        Column {
            anchors.centerIn: parent
            spacing: 32

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Time.hoursMinutes
                color: Appearance.colors.colOnLayer0
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.hugeass * 4
                font.weight: Font.Light
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(Time.date, "dddd, d MMMM")
                color: Appearance.colors.colSubtext
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.large
            }

            MaterialTextField {
                id: passwordField

                anchors.horizontalCenter: parent.horizontalCenter
                width: Appearance.sizes.searchWidth
                enabled: Lock.acceptingInput
                echoMode: Lock.echoResponse ? TextInput.Normal : TextInput.Password
                placeholderText: Lock.prompt
                focus: true

                onAccepted: Lock.submit()

                // Two-way sync with the singleton's password: it is the single source of
                // truth, so a second output's field shows what is typed on the first.
                onTextChanged: if (Lock.password !== text)
                    Lock.password = text

                Connections {
                    target: Lock

                    function onPasswordChanged() {
                        if (passwordField.text !== Lock.password)
                            passwordField.text = Lock.password;
                    }

                    function onAcceptingInputChanged() {
                        if (Lock.acceptingInput)
                            passwordField.forceActiveFocus();
                    }
                }

                Component.onCompleted: passwordField.forceActiveFocus()
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Appearance.sizes.searchWidth
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Lock.authenticating ? "Authenticating…" : Lock.message
                color: Lock.messageIsProblem ? Appearance.colors.colError : Appearance.colors.colSubtext
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal
            }
        }
    }
}
