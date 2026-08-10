import QtQuick
import Quickshell
import Quickshell.Io

BarItem {
    id: root

    property int usage: 0
    property string load: ""
    property string perCore: ""
    property var last: ({})

    tooltip: `Load: ${load}` + (perCore !== "" ? `\n${perCore}` : "")
    onClicked: Quickshell.execDetached(Config.modules.cpu.clickCommand)

    FileView {
        id: stat
        path: "/proc/stat"
        blockLoading: true
    }

    FileView {
        id: loadavg
        path: "/proc/loadavg"
        blockLoading: true
    }

    // returns usage % since the previous sample for one "cpuN ..." line
    function lineUsage(line) {
        const parts = line.trim().split(/\s+/);
        const name = parts[0];
        const fields = parts.slice(1).map(Number);
        const idle = fields[3] + (fields[4] ?? 0);
        const total = fields.reduce((a, b) => a + b, 0);
        const prev = last[name];
        last[name] = { idle: idle, total: total };
        if (prev === undefined || total <= prev.total)
            return 0;
        return Math.round(100 * (1 - (idle - prev.idle) / (total - prev.total)));
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            const lines = stat.text().split("\n").filter(l => l.startsWith("cpu"));
            root.usage = root.lineUsage(lines[0]);
            root.perCore = lines.slice(1)
                .map((l, i) => `Core ${String(i).padStart(2)}: ${String(root.lineUsage(l)).padStart(3)}%`)
                .join("\n");
            loadavg.reload();
            root.load = loadavg.text().split(" ").slice(0, 3).join(" ");
        }
    }

    BarText {
        color: root.fg
        text: `󰍛 ${root.usage}%`
    }
}
