import qs.services
import QtQuick
import Quickshell

SliderControl {
    id: root
    icon: "light_mode"

    from: 0.0
    to: 1.0

    value: {
        const monitor = Brightness.getMonitorForScreen(Quickshell.screens[0]);
        return monitor && monitor.ready ? monitor.brightness : 0.5;
    }

    onMoved: value => {
        const monitor = Brightness.getMonitorForScreen(Quickshell.screens[0]);
        if (monitor && monitor.ready) {
            monitor.setBrightness(value);
        }
    }
}
