//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

/**
 * PROTOTYPE — throwaway. Three variants of the dashboard timeseries widget, switchable
 * inside one FloatingWindow, answering how it should be drawn and what contract it exposes.
 *
 * Run it: qs -p prototypes/timeseries-qml
 */
ShellRoot {
    id: shell

    readonly property int historyLength: 24
    readonly property var variants: [
        {
            name: "A — Canvas parity",
            renderer: "Canvas software raster → texture upload",
            contract: "optional second line · low-alpha fill · eased scale · smooth scroll",
            startup: "Blank plot with “Collecting the second sample…”"
        },
        {
            name: "B — Shape parity",
            renderer: "ShapePath + PathPolyline geometry renderer",
            contract: "same line, fill, scale and scroll contract as A",
            startup: "Blank plot with “Collecting the second sample…”"
        },
        {
            name: "C — Sampled Shape",
            renderer: "ShapePath + PathPolyline, rebuilt once per sample",
            contract: "optional second line · no fill · padded snap scale · 1 Hz steps",
            startup: "A present-value dot while history is unavailable"
        }
    ]

    property int variantIndex: 0
    property bool networkScenario: true
    property bool paused: false
    property var line1: []
    property var line2: []
    property int sequence: 0
    property real slideProgress: 1
    property real targetMaximum: 100
    property real smoothMaximum: 100
    property int samplesAdded: 0

    readonly property real current1: line1.length ? line1[line1.length - 1] : 0
    readonly property real current2: line2.length ? line2[line2.length - 1] : 0
    readonly property real immediateMaximum: networkScenario
        ? Math.max(10, Math.max(...line1, ...line2) * 1.15)
        : 100
    readonly property color line1Color: Appearance.colors.colPrimary
    readonly property color line2Color: Appearance.colors.colTertiary

    function chooseVariant(index) {
        variantIndex = (index + variants.length) % variants.length;
        console.log("PROTOTYPE STATE variant=" + variants[variantIndex].name
                    + " scenario=" + (networkScenario ? "network" : "cpu")
                    + " samples=" + line1.length);
    }

    function sampleValue(index, secondary) {
        if (!networkScenario)
            return 47 + 20 * Math.sin(index * 0.58) + 9 * Math.sin(index * 1.71);

        const base = secondary ? 12 : 35;
        const wave = secondary ? 8 * Math.sin(index * 0.81 + 1.2) : 18 * Math.sin(index * 0.47);
        const pulse = index % 11 === (secondary ? 7 : 4) ? (secondary ? 34 : 70) : 0;
        return Math.max(1, base + wave + pulse);
    }

    function appendSample(primary, secondary) {
        const next1 = line1.slice();
        const next2 = line2.slice();
        next1.push(primary);
        if (networkScenario)
            next2.push(secondary);
        while (next1.length > historyLength + 1)
            next1.shift();
        while (next2.length > historyLength + 1)
            next2.shift();
        line1 = next1;
        line2 = networkScenario ? next2 : [];
        samplesAdded++;

        targetMaximum = networkScenario
            ? Math.max(10, Math.max(...next1, ...next2) * 1.15)
            : 100;
        smoothMaximum = targetMaximum;
        slideAnimation.restart();
    }

    function tick() {
        appendSample(sampleValue(sequence, false), sampleValue(sequence, true));
        sequence++;
    }

    function seed() {
        line1 = [];
        line2 = [];
        sequence = 0;
        samplesAdded = 0;
        for (let i = 0; i < 18; i++) {
            const next1 = line1.slice();
            const next2 = line2.slice();
            next1.push(sampleValue(sequence, false));
            if (networkScenario)
                next2.push(sampleValue(sequence, true));
            line1 = next1;
            line2 = next2;
            sequence++;
        }
        targetMaximum = immediateMaximum;
        smoothMaximum = targetMaximum;
        slideProgress = 1;
    }

    function switchScenario(useNetwork) {
        networkScenario = useNetwork;
        paused = false;
        seed();
    }

    function restartRing() {
        paused = true;
        line1 = [sampleValue(sequence, false)];
        line2 = networkScenario ? [sampleValue(sequence, true)] : [];
        sequence++;
        targetMaximum = networkScenario ? Math.max(10, current1, current2) * 1.15 : 100;
        smoothMaximum = targetMaximum;
        slideProgress = 1;
        warmupPause.restart();
    }

    function injectSpike() {
        const base = networkScenario ? Math.max(120, immediateMaximum * 1.8) : 96;
        appendSample(base, networkScenario ? base * 0.42 : 0);
        sequence++;
    }

    Component.onCompleted: seed()

    Behavior on smoothMaximum {
        NumberAnimation {
            duration: 360
            easing.type: Easing.OutQuad
        }
    }

    NumberAnimation {
        id: slideAnimation
        target: shell
        property: "slideProgress"
        from: 0
        to: 1
        duration: 1000
        easing.type: Easing.Linear
    }

    Timer {
        interval: 1000
        running: !shell.paused
        repeat: true
        onTriggered: shell.tick()
    }

    Timer {
        id: warmupPause
        interval: 2600
        repeat: false
        onTriggered: shell.paused = false
    }

    FloatingWindow {
        id: window

        implicitWidth: 1000
        implicitHeight: 760
        color: Appearance.colors.colLayer0
        visible: true

        Column {
            id: page
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 24
            spacing: 12

            Text {
                text: "How a timeseries plot is drawn in QML"
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }

            Text {
                width: parent.width
                text: "Compare identical Canvas and Shape contracts first; then decide whether the cheaper sampled contract loses anything you care about. Reset the ring to inspect startup and inject a spike to expose scale behaviour."
                wrapMode: Text.WordWrap
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurfaceVariant
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                ProtoButton {
                    label: "Network · two lines"
                    icon: "swap_vert"
                    selected: shell.networkScenario
                    onClicked: shell.switchScenario(true)
                }

                ProtoButton {
                    label: "CPU · one line"
                    icon: "memory"
                    selected: !shell.networkScenario
                    onClicked: shell.switchScenario(false)
                }

                Rectangle {
                    width: 1
                    height: 34
                    color: Appearance.colors.colOutlineVariant
                }

                ProtoButton {
                    label: "Reset to one sample"
                    icon: "restart_alt"
                    onClicked: shell.restartRing()
                }

                ProtoButton {
                    label: "Inject spike"
                    icon: "bolt"
                    onClicked: shell.injectSpike()
                }

                ProtoButton {
                    label: shell.paused ? "Resume" : "Pause"
                    icon: shell.paused ? "play_arrow" : "pause"
                    selected: shell.paused
                    onClicked: {
                        warmupPause.stop();
                        shell.paused = !shell.paused;
                    }
                }
            }

            Rectangle {
                id: stage
                width: parent.width
                height: 490
                radius: Appearance.rounding.large
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                CanvasVariant {
                    anchors.fill: parent
                    visible: shell.variantIndex === 0
                }

                ShapeParityVariant {
                    anchors.fill: parent
                    visible: shell.variantIndex === 1
                }

                SampledShapeVariant {
                    anchors.fill: parent
                    visible: shell.variantIndex === 2
                }
            }

            Rectangle {
                width: parent.width
                height: 54
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2

                Text {
                    anchors.fill: parent
                    anchors.margins: 12
                    text: `${shell.variants[shell.variantIndex].renderer}  |  ${shell.variants[shell.variantIndex].contract}\n${shell.variants[shell.variantIndex].startup}`
                    wrapMode: Text.WordWrap
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Rectangle {
            id: switcher
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            width: switcherRow.implicitWidth + 26
            height: 42
            radius: height / 2
            color: Appearance.colors.colPrimaryContainer
            border.width: 1
            border.color: Appearance.colors.colPrimary

            Row {
                id: switcherRow
                anchors.centerIn: parent
                spacing: 12

                MaterialSymbol {
                    text: "arrow_back"
                    iconSize: 20
                    color: Appearance.colors.colOnPrimaryContainer

                    TapHandler {
                        onTapped: shell.chooseVariant(shell.variantIndex - 1)
                    }
                }

                Text {
                    text: shell.variants[shell.variantIndex].name
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnPrimaryContainer
                }

                MaterialSymbol {
                    text: "arrow_forward"
                    iconSize: 20
                    color: Appearance.colors.colOnPrimaryContainer

                    TapHandler {
                        onTapped: shell.chooseVariant(shell.variantIndex + 1)
                    }
                }
            }
        }

        Shortcut {
            sequence: "Left"
            onActivated: shell.chooseVariant(shell.variantIndex - 1)
        }

        Shortcut {
            sequence: "Right"
            onActivated: shell.chooseVariant(shell.variantIndex + 1)
        }
    }

    component ProtoButton: Rectangle {
        id: button

        required property string label
        property string icon: ""
        property bool selected: false
        signal clicked

        width: content.implicitWidth + 22
        height: 34
        radius: height / 2
        color: selected ? Appearance.colors.colPrimaryContainer : hover.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
        border.width: 1
        border.color: selected ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: button.icon
                iconSize: 18
                color: button.selected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
            }

            Text {
                text: button.label
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: button.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
            }
        }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: button.clicked()
        }
    }

    component ChartFrame: Rectangle {
        id: frame

        property alias plotArea: plot.data
        property string updateLabel
        property bool startupDot: false

        anchors.centerIn: parent
        width: 784
        height: 390
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant

        Row {
            id: heading
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 22

            Row {
                spacing: 9

                MaterialSymbol {
                    text: shell.networkScenario ? "swap_vert" : "memory"
                    iconSize: 24
                    fill: 1
                    color: shell.line1Color
                }

                Column {
                    spacing: 1

                    Text {
                        text: shell.networkScenario ? "Network" : "CPU"
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }

                    Text {
                        text: shell.networkScenario ? "24 seconds · shared vertical scale" : "24 seconds · fixed 0–100% scale"
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }

            Item {
                width: parent.width - parent.children[0].width - readings.width
                height: 1
            }

            Row {
                id: readings
                spacing: 18

                Reading {
                    symbol: shell.networkScenario ? "download" : "speed"
                    label: shell.networkScenario ? "Download" : "Usage"
                    value: shell.networkScenario ? Math.round(shell.current1) + " MB/s" : Math.round(shell.current1) + "%"
                    accent: shell.line1Color
                }

                Reading {
                    visible: shell.networkScenario
                    symbol: "upload"
                    label: "Upload"
                    value: Math.round(shell.current2) + " MB/s"
                    accent: shell.line2Color
                }
            }
        }

        Rectangle {
            id: chartBackground
            anchors.top: heading.bottom
            anchors.topMargin: 18
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.right: parent.right
            anchors.rightMargin: 22
            height: 220
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            clip: true

            Repeater {
                model: 4

                delegate: Rectangle {
                    required property int index
                    x: 0
                    y: index * chartBackground.height / 3
                    width: chartBackground.width
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                    opacity: index === 3 ? 0.8 : 0.42
                }
            }

            Item {
                id: plot
                anchors.fill: parent
                anchors.margins: 8
            }

            Text {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                text: shell.variantIndex === 2
                    ? Math.round(shell.immediateMaximum) + (shell.networkScenario ? " MB/s" : "%")
                    : Math.round(shell.smoothMaximum) + (shell.networkScenario ? " MB/s" : "%")
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnSurfaceVariant
            }

            Item {
                anchors.fill: parent
                visible: shell.line1.length < 2

                Rectangle {
                    visible: frame.startupDot && shell.line1.length > 0
                    width: 8
                    height: 8
                    radius: 4
                    x: parent.width - 20
                    y: parent.height - 12 - (shell.current1 / (shell.variantIndex === 2 ? shell.immediateMaximum : shell.smoothMaximum)) * (parent.height - 24)
                    color: shell.line1Color
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: frame.startupDot ? 24 : 0
                    text: frame.startupDot ? "Current value now; history after the next sample" : "Collecting the second sample…"
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        Row {
            anchors.top: chartBackground.bottom
            anchors.topMargin: 16
            anchors.left: chartBackground.left
            anchors.right: chartBackground.right
            spacing: 10

            MaterialSymbol {
                text: shell.variantIndex === 2 ? "pace" : "animation"
                iconSize: 20
                color: Appearance.colors.colSecondary
            }

            Text {
                text: frame.updateLabel
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }

    component Reading: Column {
        required property string symbol
        required property string label
        required property string value
        required property color accent

        spacing: 1

        Row {
            spacing: 4

            MaterialSymbol {
                text: symbol
                iconSize: 16
                color: accent
            }

            Text {
                text: label
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        Text {
            text: value
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.DemiBold
            color: accent
        }
    }

    component CanvasVariant: Item {
        ChartFrame {
            updateLabel: `Canvas paints ${canvasPlot.paintCount} · slide progress ${shell.slideProgress.toFixed(2)} · ${shell.line1.length} samples`

            plotArea: ProtoCanvasPlot {
                id: canvasPlot
                anchors.fill: parent
                line1: shell.line1
                line2: shell.line2
                maximum: shell.smoothMaximum
                historyLength: shell.historyLength
                slideProgress: shell.slideProgress
                smoothScroll: true
                fillUnderLine: true
                line1Color: shell.line1Color
                line2Color: shell.line2Color
            }
        }
    }

    component ShapeParityVariant: Item {
        ChartFrame {
            updateLabel: `Shape geometry updates ${shapePlot.geometryUpdateCount} · slide progress ${shell.slideProgress.toFixed(2)} · ${shell.line1.length} samples`

            plotArea: ProtoShapePlot {
                id: shapePlot
                anchors.fill: parent
                line1: shell.line1
                line2: shell.line2
                maximum: shell.smoothMaximum
                historyLength: shell.historyLength
                slideProgress: shell.slideProgress
                smoothScroll: true
                fillUnderLine: true
                line1Color: shell.line1Color
                line2Color: shell.line2Color
            }
        }
    }

    component SampledShapeVariant: Item {
        ChartFrame {
            startupDot: true
            updateLabel: `Shape geometry updates ${sampledPlot.geometryUpdateCount} · one rebuild per 1s sample · ${shell.line1.length} samples`

            plotArea: ProtoShapePlot {
                id: sampledPlot
                anchors.fill: parent
                line1: shell.line1
                line2: shell.line2
                maximum: shell.immediateMaximum
                historyLength: shell.historyLength
                slideProgress: 1
                smoothScroll: false
                fillUnderLine: false
                line1Color: shell.line1Color
                line2Color: shell.line2Color
            }
        }
    }
}
