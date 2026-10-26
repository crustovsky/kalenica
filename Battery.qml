import QtQuick

// Battery readout; the state (and the critical alert) lives in BatteryState.
BarItem {
    id: root
    clickable: false

    readonly property var device: BatteryState.device
    readonly property int pct: BatteryState.pct
    readonly property bool charging: BatteryState.charging
    readonly property bool low: BatteryState.low
    readonly property bool critical: BatteryState.critical
    readonly property var icons: ["󰂃", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    visible: device !== null && device.isPresent

    function fmtTime(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.round(seconds % 3600 / 60);
        return h > 0 ? `${h}h ${m}min` : `${m}min`;
    }

    tooltip: {
        if (device === null)
            return "";
        let time = "";
        if (charging && device.timeToFull > 0)
            time = `\n${fmtTime(device.timeToFull)} until full`;
        else if (!charging && device.timeToEmpty > 0)
            time = `\n${fmtTime(device.timeToEmpty)} until empty`;
        return `󱐋 ${Math.abs(device.changeRate).toFixed(1)}W 󱈏 ${Math.round(device.healthPercentage)}%${time}`;
    }

    BarText {
        color: root.critical ? Theme.critical
             : root.low ? Theme.warning
             : root.fg

        // waybar's blink_warning (5s) / blink_critical (2.5s)
        SequentialAnimation on opacity {
            running: root.low
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.5; duration: root.critical ? 1250 : 2500 }
            NumberAnimation { to: 1; duration: root.critical ? 1250 : 2500 }
        }
        text: root.charging ? ` ${root.pct}%`
            : `${root.icons[Math.min(10, Math.round(root.pct / 10))]} ${root.pct}%`
    }
}
