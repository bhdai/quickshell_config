import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.common

RowLayout {
    id: root

    // public API for this component
    property alias icon: iconSymbol.source
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to

    signal moved(real value)

    spacing: 15
    Layout.fillWidth: true

    CustomIcon {
        id: iconSymbol
        width: 20
        height: 20
        colorize: true
        color: Colors.text
    }

    StyledSlider {
        id: slider
        Layout.fillWidth: true
        configuration: StyledSlider.Configuration.M

        highlightColor: Colors.accent
        trackColor: Colors.surface1
        handleColor: Colors.accent
        dotColor: Colors.accent
        dotColorHighlighted: Colors.accent

        // when the slider value change, emit the moved signal
        // only fires when user drag it
        onValueChanged: {
            if (pressed) {
                root.moved(value);
            }
        }
    }
}
