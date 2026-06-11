import QtQuick
import Quickshell.Services.Pipewire

BarItem {
    id: root

    readonly property var source: Pipewire.defaultAudioSource
    readonly property int vol: source !== null && source.audio !== null
        ? Math.round(source.audio.volume * 100) : 0
    readonly property bool muted: source !== null && source.audio !== null && source.audio.muted

    PwObjectTracker { objects: [Pipewire.defaultAudioSource] }

    AudioDevicePopup {
        id: inputs
        sinks: false
        anchorItem: root
    }

    onClicked: inputs.toggle()
    onScrolled: delta => {
        if (source !== null && source.audio !== null)
            source.audio.volume = Math.max(0, Math.min(1, source.audio.volume + delta * 0.01));
    }

    BarText {
        color: root.fg
        text: root.muted ? " " : ` ${root.vol}%`
    }
}
