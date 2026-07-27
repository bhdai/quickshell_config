import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    // ---- variant knobs ----------------------------------------------------
    // Changing either of these is itself a file edit, and therefore a reload. Set
    // them BEFORE locking, except where a run sheet explicitly calls for editing
    // `lockId` while locked to break instance matching mid-lock.

    // "" reproduces an unset reloadableId, which falls back to ReloadPropagator's
    // by-index child matching.
    readonly property string lockId: "spikeLock"

    // false puts lock state in an ordinary QML property, which a new generation
    // constructs as `false` — the state of affairs #46 predicts will unlock.
    readonly property bool persistLockState: true
    // -----------------------------------------------------------------------

    // Distinguishes a surface adopted from the previous generation from one this
    // generation created: consecutive generations always print different nonces.
    readonly property string nonce: Math.random().toString(36).slice(2, 8)

    property bool volatileWantLock: false

    readonly property bool wantLock: root.persistLockState ? persist.wantLock : root.volatileWantLock

    function log(msg: string) {
        console.warn(`[spike ${root.nonce}] ${msg}`);
    }

    function setWantLock(want: bool) {
        if (root.persistLockState)
            persist.wantLock = want;
        else
            root.volatileWantLock = want;
        root.log(`wantLock := ${want}`);
    }

    Component.onCompleted: root.log(`generation start — lockId="${root.lockId}" persistLockState=${root.persistLockState}`)
    Component.onDestruction: root.log("generation destroyed")

    PersistentProperties {
        id: persist

        // Carries its own id so that "did the lock match?" and "did the lock state
        // survive?" stay independent knobs — editing `lockId` must not also wipe
        // the persisted state.
        reloadableId: "spikeState"

        property bool wantLock: false
        property int generation: 0

        onLoaded: {
            persist.generation = 1;
            root.log(`persist loaded (fresh) — wantLock=${persist.wantLock}`);
        }

        onReloaded: {
            persist.generation += 1;
            root.log(`persist reloaded (adopted) — generation=${persist.generation} wantLock=${persist.wantLock}`);
        }
    }

    WlSessionLock {
        id: lock

        reloadableId: root.lockId
        locked: root.wantLock

        onLockedChanged: root.log(`lock.locked -> ${lock.locked} (wantLock=${root.wantLock})`)
        onSecureChanged: root.log(`lock.secure -> ${lock.secure}`)

        Component.onCompleted: root.log("WlSessionLock created")
        Component.onDestruction: root.log("WlSessionLock destroyed")

        surface: WlSessionLockSurface {
            id: surface

            color: "#101820"

            Component.onCompleted: root.log(`surface created — screen=${surface.screen ? surface.screen.name : "?"}`)
            Component.onDestruction: root.log("surface destroyed")

            Item {
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_U) {
                        root.log("unlock key pressed");
                        root.setWantLock(false);
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 16

                    Text {
                        text: "SPIKE — reload while locked"
                        font.pixelSize: 40
                        font.family: "monospace"
                        color: "#ffffff"
                    }

                    Text {
                        text: `generation nonce   ${root.nonce}
persist generation ${persist.generation}
lockId             "${root.lockId}"
persistLockState   ${root.persistLockState}
locked / secure    ${lock.locked} / ${lock.secure}
screen             ${surface.screen ? surface.screen.name : "?"}`
                        font.pixelSize: 24
                        font.family: "monospace"
                        color: "#8fd3ff"
                    }

                    Text {
                        text: "press  U  to unlock"
                        font.pixelSize: 28
                        font.family: "monospace"
                        color: "#ffd479"
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "spike"

        function lock(): string {
            root.setWantLock(true);
            return `locking — nonce=${root.nonce}`;
        }

        function unlock(): string {
            root.setWantLock(false);
            return `unlocking — nonce=${root.nonce}`;
        }

        function status(): string {
            return `nonce=${root.nonce} generation=${persist.generation} lockId="${root.lockId}" persistLockState=${root.persistLockState} wantLock=${root.wantLock} locked=${lock.locked} secure=${lock.secure}`;
        }
    }
}
