import QtQuick
import Quickshell
import Quickshell.Services.UPower

BarItem {
    id: root
    clickable: false

    readonly property var device: UPower.displayDevice
    readonly property int pct: Math.round(device.percentage * 100)
    // Treat full-and-plugged like waybar's "plugged" state (same plug icon).
    readonly property bool charging: device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.PendingCharge
        || device.state === UPowerDeviceState.FullyCharged
    readonly property var icons: ["󰂃", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    // pct > 0 skips the transient 0% while UPower populates at startup
    readonly property bool low: pct > 0 && pct <= 20 && !charging
    readonly property bool critical: pct > 0 && pct <= 10 && !charging

    onCriticalChanged: {
        if (critical)
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "battery",
                "Battery critical", `${pct}% remaining`]);
    }

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
