pragma Singleton
import QtQuick

QtObject {
    id: root

    // helper function to mix two colors
    function mix(color1, color2, ratio) {
        return Qt.rgba(color1.r * (1 - ratio) + color2.r * ratio, color1.g * (1 - ratio) + color2.g * ratio, color1.b * (1 - ratio) + color2.b * ratio, color1.a * (1 - ratio) + color2.a * ratio);
    }

    // helper function to transparentize a color
    function transparentize(color, amount) {
        return Qt.rgba(color.r, color.g, color.b, color.a * (1 - amount));
    }

    // helper function to lighten a color
    function lighten(color, amount) {
        return Qt.lighter(color, 1 + amount);
    }

    // helper function to darken a color
    function darken(color, amount) {
        return Qt.darker(color, 1 + amount);
    }
}
