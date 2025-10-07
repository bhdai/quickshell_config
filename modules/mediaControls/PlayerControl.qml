import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "." as MediaControls

Item {
    id: playerController
    required property MprisPlayer player

    property var artUrl: player?.trackArtUrl || ""
    property string artDownloadLocation: `${Quickshell.env("HOME")}/.cache/quickshell/coverart`
    property string artFileName: Qt.md5(artUrl) + ".jpg"
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property color artDominantColor: "#3d3d3d"
    property bool downloaded: false
    property real radius: 12
    property real contentPadding: 13
    property real artRounding: 8

    // cleanup processes on destruction to prevent crashes during reload
    Component.onDestruction: {
        if (mkdirProc)
            mkdirProc.running = false;
        if (coverArtDownloader)
            coverArtDownloader.running = false;
    }

    // ensure download directory exists
    Process {
        id: mkdirProc
        running: true
        command: ["mkdir", "-p", artDownloadLocation]
    }

    // download album art when URL changes
    onArtUrlChanged: {
        if (playerController.artUrl.length == 0) {
            playerController.artDominantColor = "#3d3d3d";
            playerController.downloaded = false;
            return;
        }
        playerController.downloaded = false;
        coverArtDownloader.running = true;
    }

    Process {
        id: coverArtDownloader
        property string targetFile: playerController.artUrl
        command: ["bash", "-c", `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                playerController.downloaded = true;
            }
        }
    }

    // extract dominant color from album art
    ColorQuantizer {
        id: colorQuantizer
        source: playerController.downloaded ? Qt.resolvedUrl(artFilePath) : ""
        depth: 0 // Single dominant color
        rescaleSize: 1
        onColorsChanged: {
            if (colors && colors.length > 0) {
                playerController.artDominantColor = colors[0];
            }
        }
    }

    // create adapted color scheme
    MediaControls.AdaptedMaterialScheme {
        id: blendedColors
        sourceColor: artDominantColor
    }

    // update position timer
    Timer {
        running: playerController.player?.playbackState == MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: playerController.player.positionChanged()
    }

    // format seconds to time string
    function formatTime(seconds) {
        if (!seconds || isNaN(seconds))
            return "0:00";
        let minutes = Math.floor(seconds / 60);
        let secs = Math.floor(seconds % 60);
        return `${minutes}:${secs.toString().padStart(2, '0')}`;
    }

    // clean title (remove prefixes in brackets/parentheses)
    function cleanTitle(title) {
        if (!title)
            return "Unknown Title";
        let cleaned = title.replace(/^\s*\(.+?\)\s*/, '');
        cleaned = cleaned.replace(/^\s*\[.+?\]\s*/, '');
        return cleaned.trim() || title;
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: blendedColors.colLayer0
        radius: playerController.radius

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        // blurred album art background
        Image {
            id: blurredArt
            anchors.fill: parent
            source: playerController.downloaded ? Qt.resolvedUrl(artFilePath) : ""
            sourceSize.width: background.width
            sourceSize.height: background.height
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: true

            layer.enabled: true
            layer.effect: MultiEffect {
                source: blurredArt
                blurEnabled: true
                blur: 1.0
                blurMax: 100
                saturation: 0.2
            }

            Rectangle {
                anchors.fill: parent
                color: MediaControls.ColorUtils.transparentize(blendedColors.colLayer0, 0.3)
                radius: playerController.radius
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: playerController.contentPadding
            spacing: 15

            // album art
            Rectangle {
                id: artBackground
                Layout.fillHeight: true
                implicitWidth: height
                radius: playerController.artRounding
                color: MediaControls.ColorUtils.transparentize(blendedColors.colLayer1, 0.5)

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artBackground.width
                        height: artBackground.height
                        radius: artBackground.radius
                    }
                }

                Image {
                    id: mediaArt
                    anchors.fill: parent
                    source: playerController.downloaded ? Qt.resolvedUrl(artFilePath) : ""
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true
                    asynchronous: true
                }
            }

            // info & controls
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: 2

                // track title
                Text {
                    id: trackTitle
                    Layout.fillWidth: true
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: blendedColors.colOnLayer0
                    elide: Text.ElideRight
                    text: cleanTitle(playerController.player?.trackTitle) || "Untitled"
                }

                // track artist
                Text {
                    id: trackArtist
                    Layout.fillWidth: true
                    font.pixelSize: 13
                    color: blendedColors.colSubtext
                    elide: Text.ElideRight
                    text: playerController.player?.trackArtist || "Unknown Artist"
                }

                Item {
                    Layout.fillHeight: true
                }

                // controls section
                Item {
                    Layout.fillWidth: true
                    implicitHeight: trackTime.implicitHeight + sliderRow.implicitHeight + 10

                    // time display
                    Text {
                        id: trackTime
                        anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5
                        anchors.left: parent.left
                        font.pixelSize: 11
                        color: blendedColors.colSubtext
                        text: `${formatTime(playerController.player?.position)} / ${formatTime(playerController.player?.length)}`
                    }

                    // play/pause button
                    MediaControls.RippleButton {
                        id: playPauseButton
                        anchors.right: parent.right
                        anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5

                        implicitWidth: 44
                        implicitHeight: 44
                        onClicked: playerController.player.togglePlaying()

                        buttonRadius: playerController.player?.isPlaying ? 8 : 22
                        colBackground: playerController.player?.isPlaying ? blendedColors.colPrimary : blendedColors.colSecondaryContainer
                        colBackgroundHover: playerController.player?.isPlaying ? blendedColors.colPrimaryHover : blendedColors.colSecondaryContainerHover

                        Behavior on buttonRadius {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }

                        MediaControls.MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: 28
                            fill: 1
                            color: playerController.player?.isPlaying ? blendedColors.colOnPrimary : blendedColors.colOnSecondaryContainer
                            text: playerController.player?.isPlaying ? "pause" : "play_arrow"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // slider row with prev/next buttons
                    RowLayout {
                        id: sliderRow
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                        spacing: 8

                        // previous button
                        MediaControls.RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: 16
                            colBackground: MediaControls.ColorUtils.transparentize(blendedColors.colSecondaryContainer, 1)
                            colBackgroundHover: blendedColors.colSecondaryContainerHover

                            onClicked: playerController.player?.previous()

                            MediaControls.MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: 24
                                fill: 1
                                color: blendedColors.colOnSecondaryContainer
                                text: "skip_previous"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // progress slider or bar
                        Loader {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20

                            sourceComponent: playerController.player?.canSeek ? sliderComponent : progressBarComponent

                            Component {
                                id: sliderComponent
                                Slider {
                                    id: positionSlider
                                    from: 0
                                    to: 1
                                    value: playerController.player?.position / playerController.player?.length || 0
                                    
                                    // Style the slider track
                                    background: Rectangle {
                                        x: positionSlider.leftPadding
                                        y: positionSlider.topPadding + positionSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 200
                                        implicitHeight: 6
                                        width: positionSlider.availableWidth
                                        height: implicitHeight
                                        radius: 3
                                        color: blendedColors.colSecondaryContainer
                                        
                                        Rectangle {
                                            width: positionSlider.visualPosition * parent.width
                                            height: parent.height
                                            radius: 3
                                            color: blendedColors.colPrimary
                                        }
                                    }
                                    
                                    // Style the slider handle
                                    handle: Rectangle {
                                        x: positionSlider.leftPadding + positionSlider.visualPosition * (positionSlider.availableWidth - width)
                                        y: positionSlider.topPadding + positionSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 16
                                        implicitHeight: 16
                                        radius: 8
                                        color: positionSlider.pressed ? Qt.lighter(blendedColors.colPrimary, 1.2) : blendedColors.colPrimary
                                        border.color: Qt.darker(color, 1.1)
                                        border.width: 1
                                        
                                        visible: positionSlider.hovered || positionSlider.pressed
                                    }
                                    
                                    onMoved: {
                                        if (playerController.player?.canSeek) {
                                            playerController.player.position = value * playerController.player.length;
                                        }
                                    }
                                }
                            }

                            Component {
                                id: progressBarComponent
                                ProgressBar {
                                    id: positionProgressBar
                                    from: 0
                                    to: 1
                                    value: playerController.player?.position / playerController.player?.length || 0
                                    
                                    // Style the progress bar
                                    contentItem: Rectangle {
                                        implicitWidth: 200
                                        implicitHeight: 6
                                        width: positionProgressBar.availableWidth
                                        height: implicitHeight
                                        radius: 3
                                        color: blendedColors.colSecondaryContainer
                                        
                                        Rectangle {
                                            width: positionProgressBar.visualPosition * parent.width
                                            height: parent.height
                                            radius: 3
                                            color: blendedColors.colPrimary
                                        }
                                    }
                                }
                            }
                        }

                        // next button
                        MediaControls.RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: 16
                            colBackground: MediaControls.ColorUtils.transparentize(blendedColors.colSecondaryContainer, 1)
                            colBackgroundHover: blendedColors.colSecondaryContainerHover

                            onClicked: playerController.player?.next()

                            MediaControls.MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: 24
                                fill: 1
                                color: blendedColors.colOnSecondaryContainer
                                text: "skip_next"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
