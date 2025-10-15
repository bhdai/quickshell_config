import qs.modules.common
import qs.modules.common.widgets
import Quickshell
import Quickshell.Io

QuickToggleButton {
    id: root
    buttonIcon: "energy_savings_leaf"
    toggled: toggled

    onClicked: {
        root.toggled = !root.toggled;
    }
}
