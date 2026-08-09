import QtQuick
import "dashboard_metrics.js" as Metrics

/**
 * The four cards of the Performance destination, each placed at the rectangle the metrics
 * module names for it. The pane is the canvas its destination declared, so a card that
 * outgrew its rectangle would overlap its neighbour rather than move the window.
 */
Item {
    id: root

    implicitWidth: Metrics.CANVAS.performance.width
    implicitHeight: Metrics.CANVAS.performance.height

    CpuCard {
        x: Metrics.PERFORMANCE_CARD.cpu.x
        y: Metrics.PERFORMANCE_CARD.cpu.y
        width: Metrics.PERFORMANCE_CARD.cpu.width
        height: Metrics.PERFORMANCE_CARD.cpu.height
    }

    MemoryCard {
        x: Metrics.PERFORMANCE_CARD.memory.x
        y: Metrics.PERFORMANCE_CARD.memory.y
        width: Metrics.PERFORMANCE_CARD.memory.width
        height: Metrics.PERFORMANCE_CARD.memory.height
    }

    NetworkCard {
        x: Metrics.PERFORMANCE_CARD.network.x
        y: Metrics.PERFORMANCE_CARD.network.y
        width: Metrics.PERFORMANCE_CARD.network.width
        height: Metrics.PERFORMANCE_CARD.network.height
    }

    StorageCard {
        x: Metrics.PERFORMANCE_CARD.storage.x
        y: Metrics.PERFORMANCE_CARD.storage.y
        width: Metrics.PERFORMANCE_CARD.storage.width
        height: Metrics.PERFORMANCE_CARD.storage.height
    }
}
