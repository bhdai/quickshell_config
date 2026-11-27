import qs.modules.common
import qs.modules.common.widgets
import qs.modules.controlCenter.detailPanel
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

/**
 * The control center's sound panel: which device plays sound, and each app's volume.
 *
 * The control center builds this when the panel opens and destroys it when it closes, so the
 * node tracking and availability polling below run only while it is on screen.
 */
Item {
    id: root

    signal closePanel

    // Everything the control center has left under its card.
    property real maxPanelHeight: 600

    // Fixed rather than sized to the lists, for the same reason as the Bluetooth panel: apps
    // start and stop streams while it is open, and the panel should not resize around them.
    implicitHeight: root.maxPanelHeight

    // See Audio.nodeRows for why the lists hold primitives. The snapshot is taken a moment after
    // the graph changes, so a node PipeWire is removing is gone before a delegate looks it up.
    property var outputRows: []
    property var streamRows: []

    Component.onCompleted: snapshotTimer.triggered()

    Connections {
        target: Audio
        function onOutputsChanged() {
            snapshotTimer.restart();
        }
        function onAppStreamsChanged() {
            snapshotTimer.restart();
        }
    }

    Timer {
        id: snapshotTimer
        interval: 50
        onTriggered: {
            root.outputRows = Audio.nodeRows(Audio.outputs);
            root.streamRows = Audio.nodeRows(Audio.appStreams);
        }
    }

    // Plugging in HDMI or a jack changes a port, not the node list, so nothing else would notice.
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: Audio.refreshOutputAvailability()
    }

    PwObjectTracker {
        objects: Audio.outputs.concat(Audio.appStreams)
    }

    component SectionLabel: Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        color: Appearance.colors.colPrimary
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.bold: true
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        radius: 20
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
    }

    DetailPanel {
        anchors.fill: parent
        title: "Sound"
        subtitle: "Choose where sound plays and how loud each app is"
        switchLabel: "Mute output"
        switchChecked: Audio.sink?.audio?.muted ?? false

        onSwitchToggled: {
            if (Audio.sink?.audio)
                Audio.sink.audio.muted = !Audio.sink.audio.muted;
        }
        onDone: root.closePanel()

        Flickable {
            id: flick
            anchors.fill: parent
            clip: true
            contentHeight: column.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: column
                width: flick.width
                spacing: 8

                SectionLabel {
                    text: "Output"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Repeater {
                        model: ScriptModel {
                            values: root.outputRows
                            objectProp: "key"
                        }

                        delegate: AudioOutputItem {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            node: Audio.nodeFor(modelData.id, modelData.name)
                            first: index === 0
                            last: index === root.outputRows.length - 1
                        }
                    }
                }

                SectionLabel {
                    Layout.topMargin: 8
                    text: "Apps"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Repeater {
                        model: ScriptModel {
                            values: root.streamRows
                            objectProp: "key"
                        }

                        delegate: AudioStreamItem {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            node: Audio.nodeFor(modelData.id, modelData.name)
                            first: index === 0
                            last: index === root.streamRows.length - 1
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.streamRows.length === 0
                        implicitHeight: 56
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer1

                        Text {
                            anchors.centerIn: parent
                            text: "No apps are playing sound"
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }
            }
        }
    }
}
