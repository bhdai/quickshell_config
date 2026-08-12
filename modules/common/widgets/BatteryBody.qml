import QtQuick
import qs.modules.common
import qs.modules.common.functions
import "../../../services/battery_glyph.js" as BatteryGlyph

/**
 * The battery as it is drawn: a filled body with the percentage cut out of it, and one trailing
 * glyph saying what power is doing.
 *
 * Takes its state as properties rather than reading the Battery singleton, so the state → glyph
 * rule stays a function of its inputs and lives in `services/battery_glyph.js` under test.
 *
 * Deliberately not a hover target and not a popup. The bar wraps this in the MouseArea and
 * tooltip that make it interactive; the lock screen instantiates it bare, because there a
 * MouseArea would be a dead zone in a surface where a press anywhere raises the password
 * prompt. Sharing the body rather than the indicator is what keeps the two from drifting.
 */
Item {
    id: root

    required property real percentage
    required property bool isCharging
    required property bool isPluggedIn
    required property bool isCritical

    /// The colour of an idle battery, and of the glyph in every state. Callers differ here:
    /// the bar draws on its own always-dark backdrop, the lock screen on the wallpaper.
    required property color foreground

    property real glyphSize: 14

    // The glyph overhangs the body rather than following it, so it is placed by anchors and
    // contributes no width — the body alone is the widget's footprint.
    readonly property real glyphOverlap: -5

    readonly property string glyph: BatteryGlyph.pickGlyph(root)

    // The fill carries the whole plugged-in/unplugged distinction now that the glyph does not,
    // so it is worth being able to read back.
    readonly property alias fillColor: batteryProgress.highlightColor

    // The trailing slot is reserved in every state rather than measured per glyph. The bar sits
    // beside this, and ClippedProgressBar's own width counts the nob but not the overhanging
    // glyph — left alone, docking the laptop would shift everything to the left of the battery
    // by the nob's width.
    implicitWidth: batteryProgress.valueBarWidth + 5
    implicitHeight: batteryProgress.implicitHeight

    ClippedProgressBar {
        id: batteryProgress

        anchors.verticalCenter: parent.verticalCenter
        value: root.percentage
        text: Math.round(root.percentage * 100)
        highlightColor: {
            if (BatteryGlyph.usesChargingFill(root))
                return Appearance.colors.colBatteryCharging;
            if (root.isCritical)
                return Appearance.colors.colBatteryCritical;
            return root.foreground;
        }
        trackColor: ColorUtils.transparentize(root.foreground, 0.5)
        showNob: root.glyph === BatteryGlyph.Glyph.Nob
        nobFilled: BatteryGlyph.nobFilled(root)
    }

    // Takes the nob's place, which is why `showNob` above asks the same question rather than
    // the two being drawn together.
    MaterialSymbol {
        anchors.left: batteryProgress.right
        anchors.leftMargin: root.glyphOverlap
        anchors.verticalCenter: batteryProgress.verticalCenter

        visible: root.glyph === BatteryGlyph.Glyph.Bolt
        text: "bolt"
        iconSize: root.glyphSize
        fill: 1
        color: root.foreground
    }
}
