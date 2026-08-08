//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.modules.common

/**
 * PROTOTYPE — throwaway. See README.md.
 *
 * The dashboard card reduced to the one thing #136 is about: a chrome rectangle that animates
 * its width between three destinations, with the real tab bar on top of it. Three tabs rather
 * than two, because Performance is the switch that has to keep reading right.
 *
 * A FloatingWindow, so this can be run beside the live shell without killing it.
 */
ShellRoot {
    FloatingWindow {
        id: window

        implicitWidth: 980
        implicitHeight: 620
        visible: true
        color: Appearance.colors.colLayer0

        // Pane sizes, as `dashboard_metrics.js` names them. Performance is invented — it only
        // has to be a third width that is neither of the other two.
        readonly property var canvas: ({
                calendar: {
                    width: 872,
                    height: 428
                },
                wallpaper: {
                    width: 676,
                    height: 424
                },
                performance: {
                    width: 796,
                    height: 380
                }
            })

        property string currentTab: "calendar"
        property int variant: 0
        property real speed: 1

        readonly property var variantNames: ["0 · live geometry (today)", "1 · settled stride", "2 · animated index"]

        Column {
            anchors.centerIn: parent
            spacing: 24

            // --- The card -------------------------------------------------------------
            Item {
                width: 900
                height: 520
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    id: card
                    anchors.centerIn: parent

                    readonly property real pad: 12
                    // The width the card is on its way to, computed before the Behavior. This
                    // is the whole of the fix in variant 1: a number the indicator can read
                    // that the animation has not touched.
                    readonly property real settledWidth: window.canvas[window.currentTab].width + 2 * pad
                    readonly property real settledHeight: window.canvas[window.currentTab].height + 2 * pad + 48 + 8

                    implicitWidth: settledWidth
                    implicitHeight: settledHeight
                    width: implicitWidth
                    height: implicitHeight

                    property bool placed: false
                    Component.onCompleted: Qt.callLater(() => card.placed = true)

                    Behavior on implicitWidth {
                        enabled: card.placed
                        NumberAnimation {
                            duration: Math.round(Appearance.animation.elementMove.duration * window.speed)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        }
                    }
                    Behavior on implicitHeight {
                        enabled: card.placed
                        NumberAnimation {
                            duration: Math.round(Appearance.animation.elementMove.duration * window.speed)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        }
                    }

                    color: Appearance.colors.colLayer0
                    radius: Appearance.rounding.large
                    border.color: Appearance.colors.colOutlineVariant
                    border.width: 1

                    ProtoTabBar {
                        id: tabBar
                        anchors.top: parent.top
                        anchors.topMargin: card.pad
                        anchors.left: parent.left
                        anchors.leftMargin: card.pad
                        anchors.right: parent.right
                        anchors.rightMargin: card.pad
                        current: window.currentTab
                        variant: window.variant
                        speed: window.speed
                        settledBarWidth: card.settledWidth - 2 * card.pad
                        trace: Quickshell.env("PROTO_TRACE") === "1"
                        onSelected: tab => window.currentTab = tab
                    }

                    // Stand-in for the pane. Nothing here is under test; it exists so the card
                    // is not an empty box and so the resize has something to reveal.
                    Rectangle {
                        anchors.top: tabBar.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: card.pad
                        anchors.right: parent.right
                        anchors.rightMargin: card.pad
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: card.pad
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer1
                    }
                }
            }

            // --- The prototype's own chrome -------------------------------------------
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Repeater {
                    model: window.variantNames
                    delegate: ProtoChip {
                        required property int index
                        required property var modelData
                        label: modelData
                        checked: window.variant === index
                        onClicked: window.variant = index
                    }
                }

                Item {
                    width: 24
                    height: 1
                }

                Repeater {
                    model: [1, 3, 8]
                    delegate: ProtoChip {
                        required property var modelData
                        label: `${modelData}× slow`
                        checked: window.speed === modelData
                        onClicked: window.speed = modelData
                    }
                }
            }

            Text {
                id: readout
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurfaceVariant
                text: `drift ${tabBar.drift.toFixed(1)}px   ·   overshoot ${Math.max(0, tabBar.overshoot).toFixed(1)}px   ·   reversals ${tabBar.reversals}\n` + `drift     = how far the indicator's destination moved after it set off\n` + `overshoot = how far past its resting place the indicator was carried\n` + `reversals = times it changed direction on the way`
            }
        }

        // Drives every variant through every switch with no one watching, so the two numbers
        // can be read off a machine with no display. Set PROTO_AUTOPILOT=1.
        property var autopilot: [[0, "wallpaper"], [0, "performance"], [0, "calendar"], [1, "wallpaper"], [1, "performance"], [1, "calendar"], [2, "wallpaper"], [2, "performance"], [2, "calendar"]]
        property int autopilotStep: -1

        Timer {
            running: Quickshell.env("PROTO_AUTOPILOT") === "1"
            interval: 600
            repeat: true
            onTriggered: {
                window.autopilotStep++;
                if (window.autopilotStep >= window.autopilot.length) {
                    Qt.quit();
                    return;
                }
                const [variant, tab] = window.autopilot[window.autopilotStep];
                window.variant = variant;
                window.currentTab = tab;
            }
        }
    }
}
