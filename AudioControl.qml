import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default output (sinks) or input volume: scroll adjusts, click opens the
// device switcher, right click on the output launches cava.
BarItem {
    id: root

    property bool sinks: true

    readonly property var node: sinks ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource
    readonly property int vol: node !== null && node.audio !== null
        ? Math.round(node.audio.volume * 100) : 0
    readonly property bool muted: node !== null && node.audio !== null && node.audio.muted

    PwObjectTracker { objects: [root.node] }

    AudioDevicePopup {
        id: devices
        sinks: root.sinks
        anchorItem: root
    }

    tooltip: node !== null ? (node.description || node.name) : ""
    onClicked: devices.toggle()
    onRightClicked: {
        if (sinks)
            Quickshell.execDetached(["kitty", "--class", "Cava", "cava"]);
    }
    onScrolled: delta => {
        if (node !== null && node.audio !== null)
            node.audio.volume = Math.max(0, Math.min(1, node.audio.volume + delta * 0.01));
    }

    BarText {
        color: root.fg
        text: root.muted ? (root.sinks ? " " : " ")
            : root.sinks ? `${["", "", "", ""][Math.min(3, Math.floor(root.vol / 25))]}  ${root.vol}%`
            : ` ${root.vol}%`
    }
}
