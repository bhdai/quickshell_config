import Quickshell
import QtQuick
import qs.modules.lock
import qs.services

/**
 * Constructs the status cluster with UPower unreachable, which is the case #67 calls out:
 * a machine that cannot answer "is there a battery" must still get a cluster, and the
 * network icon must still take width in it.
 */
ShellRoot {
    LockStatusCluster {
        id: cluster
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            console.log(`LOCK_STATUS_CLUSTER battery=${Battery.available} width=${Math.round(cluster.implicitWidth)} symbol=${Network.symbol}`);
            Qt.quit();
        }
    }
}
