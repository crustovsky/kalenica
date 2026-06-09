import QtQuick
import Quickshell
import Quickshell.Io

BarItem {
    id: root

    property int percent: 0
    property bool available: true

    visible: available

    Process {
        id: readBrightness
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d %"]
        stdout: StdioCollector {
            onStreamFinished: root.percent = parseInt(text) || 0
        }
        onExited: code => { if (code !== 0) root.available = false; }
    }

    Timer {
        interval: 5000
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: readBrightness.running = true
    }

    onScrolled: delta => {
        Quickshell.execDetached(["brightnessctl", "set", delta > 0 ? "1%+" : "1%-"]);
        readBrightness.running = true;
    }

    BarText {
        color: root.fg
        text: `${root.percent > 66 ? "󰃠" : root.percent > 33 ? "󰃟" : "󰃞"} ${root.percent}%`
    }
}
