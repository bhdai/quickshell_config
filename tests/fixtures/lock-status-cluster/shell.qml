import Quickshell
import QtQuick
import qs.modules.lock
import qs.services

/**
 * Constructs the status cluster with UPower unreachable, which is the case #67 calls out:
 * a machine that cannot answer "is there a battery" must still get a cluster, and the
 * network icon must still take width in it.
 *
 * The cluster sits in a window because QtQuick.Layouts only recomputes an implicit size on
 * a polish pass, and nothing polishes an item no window owns. Measured outside one it
 * reports its first guess whatever the layout later did, which would pass this test on a
 * cluster that lays out to nothing.
 */
ShellRoot {
    FloatingWindow {
        implicitWidth: 800
        implicitHeight: 200
        visible: true

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
}
