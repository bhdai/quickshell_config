import QtQuick
import qs.modules.common
import qs.modules.common.widgets

/**
 * PROTOTYPE — throwaway. See README.md.
 *
 * The production tab bar with its indicator geometry swapped out three ways, so the same
 * click can be watched under each. Everything else — the delegates, the labels, the curves —
 * is the shipping code, because the question is about where the numbers come from and not
 * about how they are drawn.
 */
Item {
    id: root

    property var tabs: ["Calendar", "Wallpaper", "Performance"]
    property string current: "calendar"
    // 0 = live geometry (today), 1 = settled stride, 2 = animated index
    property int variant: 0
    // The bar's width once the card has finished resizing, published from above rather than
    // read back off the row. Variant 1 is the only one that uses it.
    property real settledBarWidth: width
    property real speed: 1

    signal selected(string tab)

    readonly property int duration: Math.round(Appearance.animation.elementMove.duration * root.speed)
    readonly property real minimumIndicator: 24
    readonly property real indicatorHeight: 3
    readonly property Item indicatorItem: indicator

    readonly property int currentIndex: root.tabs.findIndex(tab => tab.toLowerCase() === root.current)

    // Natural label widths by index. A label's own implicit width never depends on the cell it
    // was laid into, so this is the one geometry the indicator may read during a resize.
    property var labelWidths: []
    function reportLabel(index: int, value: real) {
        const next = root.labelWidths.slice();
        next[index] = value;
        root.labelWidths = next;
    }
    function labelWidthAt(index: int): real {
        return Math.max(root.minimumIndicator, root.labelWidths[index] ?? 0);
    }

    implicitHeight: 48

    Row {
        id: row
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.height - root.indicatorHeight

        Repeater {
            id: repeater
            model: root.tabs

            delegate: RippleButton {
                id: tab
                required property int index
                required property var modelData
                readonly property bool active: root.current === modelData.toLowerCase()
                readonly property real labelX: x + (width - label.implicitWidth) / 2
                readonly property real labelWidth: label.implicitWidth

                width: row.width / repeater.count
                height: row.height
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: root.selected(modelData.toLowerCase())

                contentItem: Text {
                    id: label
                    text: tab.modelData
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: tab.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    Component.onCompleted: root.reportLabel(tab.index, implicitWidth)
                    onImplicitWidthChanged: root.reportLabel(tab.index, implicitWidth)
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Appearance.colors.colOutlineVariant
    }

    Rectangle {
        id: indicator
        anchors.bottom: parent.bottom
        height: root.indicatorHeight
        radius: height / 2
        color: Appearance.colors.colPrimary

        readonly property Item activeTab: {
            for (let i = 0; i < repeater.count; i++) {
                const item = repeater.itemAt(i);
                if (item && item.active)
                    return item;
            }
            return null;
        }

        // --- Variant 0: today. Both targets come off the laid-out cell, whose width is the
        // card's animating one divided by the tab count.
        readonly property real liveWidth: root.labelWidthAt(root.currentIndex)
        readonly property real liveX: activeTab ? activeTab.labelX + (activeTab.labelWidth - liveWidth) / 2 : 0

        // --- Variant 1: caelestia's. Index arithmetic over the settled stride; no laid-out
        // geometry is read at all.
        readonly property real settledStride: root.settledBarWidth / repeater.count
        readonly property real settledWidth: root.labelWidthAt(root.currentIndex)
        readonly property real settledX: settledStride * root.currentIndex + (settledStride - settledWidth) / 2

        // --- Variant 2: animate the index instead of the position. Position stays an exact
        // function of the live stride, so the indicator is under its label on every frame of
        // the resize by construction rather than by two curves agreeing.
        property real animIndex: root.currentIndex
        Behavior on animIndex {
            enabled: indicator.placed
            NumberAnimation {
                duration: root.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
        readonly property real liveStride: row.width / repeater.count
        readonly property real indexWidth: {
            const lo = Math.floor(animIndex);
            const hi = Math.ceil(animIndex);
            const f = animIndex - lo;
            return root.labelWidthAt(lo) * (1 - f) + root.labelWidthAt(hi) * f;
        }
        readonly property real indexX: liveStride * animIndex + (liveStride - indexWidth) / 2

        readonly property real targetWidth: root.variant === 0 ? liveWidth : root.variant === 1 ? settledWidth : indexWidth
        readonly property real targetX: root.variant === 0 ? liveX : root.variant === 1 ? settledX : indexX

        property bool placed: false
        Component.onCompleted: Qt.callLater(() => indicator.placed = true)

        width: targetWidth
        x: targetX

        Behavior on x {
            enabled: indicator.placed && root.variant !== 2
            NumberAnimation {
                duration: root.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
        Behavior on width {
            enabled: indicator.placed && root.variant !== 2
            NumberAnimation {
                duration: root.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial
            }
        }
    }

    // --- What the eye is too slow to catch, as three numbers ---------------------------
    //
    // The resting position is the same in every variant, so a variant is judged on the path it
    // takes to get there. `drift` is the defect stated directly: how far the indicator's
    // destination moved after the indicator had already set off for it. `overshoot` and
    // `reversals` are what that costs on screen — a target that slides back under a travelling
    // indicator carries it past where it belongs and then hauls it back.

    property real drift: 0
    property real overshoot: 0
    property int reversals: 0

    property real firstTarget: 0
    property real lastX: 0
    property real lastStep: 0
    property bool sampled: false

    // Where the indicator ends up once everything has settled. Index arithmetic over the
    // settled stride is the resting position in all three variants, so this is a fair
    // yardstick and not variant 1 marking its own homework.
    readonly property real restingX: indicator.settledX

    onCurrentIndexChanged: {
        root.drift = 0;
        root.overshoot = 0;
        root.reversals = 0;
        root.sampled = false;
        sampler.running = true;
        stopSampling.restart();
    }

    FrameAnimation {
        id: sampler
        running: false
        onTriggered: {
            const x = indicator.x;
            if (!root.sampled) {
                root.firstTarget = indicator.targetX;
                root.lastX = x;
                root.lastStep = 0;
                root.sampled = true;
                return;
            }

            root.drift = Math.max(root.drift, Math.abs(indicator.targetX - root.firstTarget));

            // Past the resting position, in whichever direction the indicator was travelling.
            const direction = Math.sign(root.restingX - root.lastX) || 1;
            root.overshoot = Math.max(root.overshoot, direction * (x - root.restingX));

            // Sub-pixel steps are the animation settling, not a change of mind.
            const step = x - root.lastX;
            if (Math.abs(step) > 0.5) {
                if (root.lastStep !== 0 && Math.sign(step) !== Math.sign(root.lastStep))
                    root.reversals++;
                root.lastStep = step;
            }
            root.lastX = x;
            if (root.trace)
                console.log(`TRACE variant=${root.variant} x=${x.toFixed(1)} target=${indicator.targetX.toFixed(1)}` + ` resting=${root.restingX.toFixed(1)} labelX=${(indicator.activeTab?.labelX ?? 0).toFixed(1)}`);
        }
    }

    property bool trace: false

    Timer {
        id: stopSampling
        // A little past the move, so the settling frames are sampled too.
        interval: root.duration + 150
        onTriggered: {
            sampler.running = false;
            console.log(`SAMPLE variant=${root.variant} to=${root.current}` + ` drift=${root.drift.toFixed(1)} overshoot=${Math.max(0, root.overshoot).toFixed(1)}` + ` reversals=${root.reversals} settled=${Math.abs(indicator.x - root.restingX).toFixed(2)}`);
        }
    }
}
