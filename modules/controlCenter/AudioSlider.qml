import qs.services
import QtQuick

SliderControl {
    id: root
    icon: Audio.symbol

    from: 0.0
    to: 1.0
    value: Audio.ready ? Audio.sinkVolume : 0.0

    onMoved: value => {
        if (Audio.ready && Audio.sink?.audio) {
            Audio.sink.audio.volume = value;
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            if (Audio.ready && Audio.sink?.audio) {
                Audio.sink.audio.muted = !Audio.sink.audio.muted;
            }
        }
    }
}
