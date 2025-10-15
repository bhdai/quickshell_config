import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.common

RowLayout {
    id: root

    // public API for this component
    property alias icon: iconSymbol.text
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to

    signal moved(real value)

    spacing: 15
    Layout.fillWidth: true

    MaterialSymbol {
        id: iconSymbol
        iconSize: 24
        color: "white"
        fill: 1
        Layout.alignment: Qt.AlignVCenter
    }

    StyledSlider {
        id: slider
        Layout.fillWidth: true
        configuration: StyledSlider.Configuration.S

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
