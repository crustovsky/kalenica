import QtQuick
import Quickshell.Io

BarItem {
    id: root
    clickable: false

    property int percent: 0
    property bool available: true

    visible: available

    Process {
        id: readBrightness
        stdout: StdioCollector {
            // machine-readable: device,class,current,percent%,max
            onStreamFinished: root.percent = parseInt(text.split(",")[3]) || 0
        }
        onExited: code => { if (code !== 0) root.available = false; }
    }

    Timer {
        interval: 5000
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: readBrightness.exec(["brightnessctl", "-m"])
    }

    // set with -m prints the result, so one process adjusts and reads back
    onScrolled: delta => readBrightness.exec(
        ["brightnessctl", "-m", "set", delta > 0 ? "1%+" : "1%-"])

    BarText {
        color: root.fg
        text: `${root.percent > 66 ? "󰃠" : root.percent > 33 ? "󰃟" : "󰃞"} ${root.percent}%`
    }
}
