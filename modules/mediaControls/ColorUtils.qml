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

    // helper function to adapt color to accent hue/saturation while keeping lightness
    function adaptToAccent(color1, color2) {
        var c1 = Qt.color(color1);
        var c2 = Qt.color(color2);
        
        var hue = c2.hslHue;
        var sat = c2.hslSaturation;
        var light = c1.hslLightness;
        var alpha = c1.a;
        
        return Qt.hsla(hue, sat, light, alpha);
    }
}
