pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Display-battery state shared by the per-monitor Battery module and the
// critical alert in shell.qml, which has to fire once, not once per bar.
Singleton {
    readonly property var device: UPower.displayDevice
    readonly property int pct: Math.round(device.percentage * 100)
    // full-and-plugged counts as charging, like waybar's "plugged" state
    readonly property bool charging: device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.PendingCharge
        || device.state === UPowerDeviceState.FullyCharged
    // pct > 0 skips the transient 0% while UPower populates at startup
    readonly property bool low: pct > 0 && pct <= Config.modules.battery.low && !charging
    readonly property bool critical: pct > 0 && pct <= Config.modules.battery.critical && !charging
}
