import QtQuick
import Quickshell
import Quickshell.Io

BarItem {
    id: root

    property real usedGb: 0
    property real totalGb: 0
    readonly property real pct: totalGb > 0 ? usedGb / totalGb * 100 : 0
    readonly property string icon: pct > 90 ? "" : pct > 60 ? "󰓅" : pct > 30 ? "󰾅" : "󰾆"

    tooltip: `󰾆 ${pct.toFixed(0)}%\n ${usedGb.toFixed(1)}GB/${totalGb.toFixed(1)}GB`
    onClicked: Quickshell.execDetached(Config.modules.memory.clickCommand)

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        blockLoading: true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            meminfo.reload();
            const text = meminfo.text();
            const total = +text.match(/MemTotal:\s+(\d+)/)[1];
            const avail = +text.match(/MemAvailable:\s+(\d+)/)[1];
            root.totalGb = total / 1048576;
            root.usedGb = (total - avail) / 1048576;
        }
    }

    BarText {
        color: root.fg
        text: `${root.icon} ${root.usedGb.toFixed(2)}GB`
    }
}
