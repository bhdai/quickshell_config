import qs.modules.common
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls

/**
 * Material 3 styled TextField (filled style)
 * https://m3.material.io/components/text-fields/overview
 * Note: We don't use NativeRendering because it makes the small placeholder text look weird
 */
TextField {
    id: root
    Material.theme: Material.System
    Material.accent: Colors.primary
    Material.primary: Colors.primary
    Material.background: Colors.surface
    Material.foreground: Colors.text
    Material.containerStyle: Material.Outlined
    renderType: Text.QtRendering

    selectedTextColor: Colors.m3onSecondaryContainer
    selectionColor: Colors.secondaryContainer
    placeholderTextColor: Colors.outline
    clip: true

    font {
        family: "sans-serif"
        pixelSize: 15
        hintingPreference: Font.PreferFullHinting
    }
    wrapMode: TextEdit.Wrap

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
    }
}
