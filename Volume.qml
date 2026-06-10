import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

BarItem {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property int vol: sink !== null && sink.audio !== null
        ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink !== null && sink.audio !== null && sink.audio.muted

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    AudioDevicePopup {
        id: outputs
        sinks: true
        anchorItem: root
    }

    tooltip: sink !== null ? (sink.description || sink.name) : ""
    onClicked: outputs.toggle()
    onRightClicked: Quickshell.execDetached(["kitty", "--class", "Cava", "cava"])
    onScrolled: delta => {
        if (sink !== null && sink.audio !== null)
            sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta * 0.01));
    }

    BarText {
        color: root.fg
        text: root.muted ? " "
            : `${["", "", "", ""][Math.min(3, Math.floor(root.vol / 25))]}  ${root.vol}%`
    }
}
