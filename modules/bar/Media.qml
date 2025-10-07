import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris

MouseArea {
    id: root
    implicitWidth: backgroundRect.implicitWidth
    implicitHeight: 30
    hoverEnabled: true

    property var activePlayer: null

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
        radius: 15
        color: "#444444"

        leftMargin: 10
        rightMargin: 10

        RowLayout {
            y: (parent.height - implicitHeight) / 2
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
    Loader {
        id: tooltipLoader
        active: root.containsMouse && root.activePlayer
        sourceComponent: MediaTooltip {
            activePlayer: root.activePlayer
            anchorItem: root
            cleanTitleFunc: root.cleanTitle
        }
    }
}
