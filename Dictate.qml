import QtQuick
import Quickshell
import Quickshell.Io

// Dictation indicator, display only. It reads a state file that any
// dictation tool can write (modules.dictate.stateFile): the first word is
// idle | recording | transcribing, an optional second word says where the
// audio goes: cloud and local get a glyph, anything else is shown as is.
// Hidden while idle or when there is no such file, so it costs nothing
// without a dictation setup.
BarItem {
    id: root

    property string status: "idle"
    property string label: ""
    readonly property bool recording: status === "recording"
    // fa-cloud, fa-microchip
    readonly property var glyphs: ({ cloud: "\uf0c2", local: "\uf2db" })

    visible: recording || status === "transcribing"
    clickable: false
    tooltip: (recording ? "Recording" : "Transcribing") + (label !== "" ? ` (${label})` : "")

    function parse(content) {
        const words = content.trim().split(/\s+/);
        status = words[0];
        label = words[1] ?? "";
    }

    FileView {
        path: Config.modules.dictate.stateFile
            || Quickshell.env("XDG_RUNTIME_DIR") + "/dictate/state"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: root.parse("")
    }

    // red while the microphone is open, plain while waiting for the text
    BarText {
        color: root.recording ? Theme.critical : root.fg
        text: "\uf130" + (root.label !== "" ? " " + (root.glyphs[root.label] ?? root.label) : "")
    }
}
