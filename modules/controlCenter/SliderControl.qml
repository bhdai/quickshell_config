import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.common

Item {
    id: root
    Layout.fillWidth: true
    implicitHeight: slider.implicitHeight

    // public API for this component
    property alias icon: slider.insetIconSource
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to

    signal moved(real value)

    StyledSlider {
        id: slider
        anchors.fill: parent
        configuration: StyledSlider.Configuration.M

        highlightColor: Colors.accent
        trackColor: Colors.surfaceContainerHighest
        handleColor: Colors.accent
        dotColor: Colors.surfaceContainerHighest
        dotColorHighlighted: Colors.surfaceContainerHighest
        handleMargins: 6

        // inset icon setup for M+ sizes
        insetIconColorActive: Colors.m3onPrimaryFixed
        insetIconColorInactive: Colors.text
        enableInsetIcon: true

        // when the slider value change, emit the moved signal
        // only fires when user drag it
        onValueChanged: {
            if (pressed) {
                root.moved(value);
            }
        }
    }
}
