import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.modules.mediaControls as MediaControlsModule

MouseArea {
    id: root
    implicitWidth: backgroundRect.implicitWidth
    implicitHeight: 30
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton

    property var activePlayer: null

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            mediaControls.isOpen = !mediaControls.isOpen;
        }
    }

    function updateActivePlayer() {
        const playingPlayer = Mpris.players.values.find(p => p.playbackState === MprisPlaybackState.Playing);
        if (playingPlayer) {
            root.activePlayer = playingPlayer;
            return;
        }

        // if not player is playing fall back to the first player in the list
        root.activePlayer = Mpris.players.values[0] || null;
    }

    function cleanTitle(title) {
        if (!title)
            return "Unknown Title";

        let cleaned = title.replace(/^\s*\(.+?\)\s*/, '');
        cleaned = cleaned.replace(/^\s*\[.+?\]\s*/, '');

        return cleaned.trim() || title;
    }

    // run once when the component is first created
    Component.onCompleted: updateActivePlayer()

    // run whenever the list of players changes
    Connections {
        target: Mpris.players
        function onObjectInsertedPost() {
            updateActivePlayer();
        }
        function onObjectRemovedPost() {
            updateActivePlayer();
        }
    }

    // create a listener for each player to react to its state changes
    Instantiator {
        model: Mpris.players

        Connections {
            target: modelData
            function onPlaybackStateChanged() {
                updateActivePlayer();
            }
            function onTrackChanged() {
                updateActivePlayer();
            }
        }
    }

    visible: !!activePlayer

    WrapperRectangle {
        id: backgroundRect
        implicitHeight: 30
        color: root.containsMouse ? "#555555" : "#444444"
        radius: 15

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        leftMargin: 10
        rightMargin: 10

        RowLayout {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            // music note
            Text {
                text: "󰎇"
                color: "#ffffff"
                font.pixelSize: 16
                Layout.alignment: Qt.AlignVCenter
            }

            // track title
            Text {
                id: titleText
                text: activePlayer ? cleanTitle(activePlayer.trackTitle) : ""
                color: "#ffffff"
                font.pixelSize: 12

                elide: Text.ElideRight

                Layout.alignment: Qt.AlignVCenter

                Layout.maximumWidth: 200
            }

            // separator
            Rectangle {
                width: 1
                height: parent.height * 0.6
                color: "#aaaaaa"
                visible: titleText.text && artistText.text
                Layout.alignment: Qt.AlignVCenter
            }

            // track artist
            Text {
                id: artistText
                text: activePlayer ? (activePlayer.trackArtist || "Unknown Artist") : ""
                color: "#aaaaaa"
                font.pixelSize: 12

                elide: Text.ElideRight

                Layout.alignment: Qt.AlignVCenter

                Layout.maximumWidth: 100
            }
        }
    }

    // lazy loaded tooltip
    Timer {
        id: tooltipTimer
        interval: 500
        running: root.containsMouse && root.activePlayer
        onTriggered: tooltipLoader.active = true
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: MediaTooltip {
            activePlayer: root.activePlayer
            anchorItem: root
            cleanTitleFunc: root.cleanTitle
        }
    }

    // reset tooltip when mouse leaves
    onContainsMouseChanged: {
        if (!containsMouse) {
            tooltipTimer.stop();
            tooltipLoader.active = false;
        }
    }

    // media controls popup
    MediaControlsModule.MediaControls {
        id: mediaControls
        anchorItem: root
    }
}
