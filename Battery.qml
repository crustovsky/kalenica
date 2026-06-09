import QtQuick
import Quickshell.Services.UPower

BarItem {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property int pct: Math.round(device.percentage * 100)
    // Treat full-and-plugged like waybar's "plugged" state (same plug icon).
    readonly property bool charging: device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.PendingCharge
        || device.state === UPowerDeviceState.FullyCharged
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
        color: root.pct <= 10 && !root.charging ? Theme.critical
             : root.pct <= 20 && !root.charging ? Theme.warning
             : root.fg
        text: root.charging ? ` ${root.pct}%`
            : `${root.icons[Math.min(10, Math.round(root.pct / 10))]} ${root.pct}%`
    }
}
