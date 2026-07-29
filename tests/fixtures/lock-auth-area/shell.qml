import Quickshell
import QtQuick
import qs.modules.lock

/**
 * Walks the password prompt through all six interaction states, which nothing else reaches:
 * the smoke run never raises a lock, and a locked-out account is not something a test can
 * arrange, so a QML error in the failure treatments would first surface behind a locked
 * screen on the day the user most needs to read the message under it.
 *
 * The prompt reads no singleton, so every state is set here as plain properties — no PAM,
 * no lock, and nothing that could unlock anything.
 */
ShellRoot {
    FloatingWindow {
        implicitWidth: 600
        implicitHeight: 300
        visible: true

        LockAuthArea {
            id: area

            width: 450
            inputAvailable: true
        }

        Timer {
            interval: 500
            running: true
            onTriggered: {
                const walk = [
                    {
                        label: "idle"
                    },
                    {
                        label: "typing",
                        text: "hunter2"
                    },
                    {
                        label: "authenticating",
                        authenticating: true,
                        maskedLength: 7
                    },
                    {
                        label: "rejected",
                        messageRole: "error",
                        message: "Password incorrect. Try again."
                    },
                    {
                        label: "maxTries",
                        messageRole: "warning",
                        message: "Too many failed attempts. Wait a moment, then try again."
                    },
                    {
                        label: "unavailable",
                        messageRole: "unavailable",
                        message: "Password authentication is unavailable."
                    }
                ];

                for (const step of walk) {
                    area.text = step.text ?? "";
                    area.authenticating = step.authenticating ?? false;
                    area.maskedLength = step.maskedLength ?? 0;
                    area.messageRole = step.messageRole ?? "none";
                    area.message = step.message ?? "";

                    const treatment = area.treatment;
                    console.log(`LOCK_AUTH_AREA step=${step.label} state=${area.authState} tone=${treatment.tone} filled=${treatment.filled} shake=${treatment.shake} spin=${treatment.spin} icons=${treatment.fieldIcon}/${treatment.statusIcon}/${treatment.submitIcon} height=${Math.round(area.implicitHeight)}`);
                }

                Qt.quit();
            }
        }
    }
}
