pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

// Idle timers (ext-idle-notify, honouring idle inhibitors like hypridle
// does) behind the OLED care features: the bars fade their content after
// modules.idle.barDim seconds, BrightnessControl dims the panels after
// modules.idle.brightnessDim. Lock / screen-off / suspend stay with hypridle
// (see examples/hypridle.conf).
Singleton {
    readonly property bool barIdle: barMonitor.idle
    readonly property bool brightnessIdle: brightnessMonitor.idle

    // An IdleMonitor (quickshell 0.3.2) goes silent after a runtime timeout
    // change, and config.json lands after startup, so a new value rebuilds
    // the monitor instead of rebinding it.
    component Monitor: Loader {
        id: mon
        required property int seconds
        readonly property bool idle: (item as IdleMonitor)?.isIdle ?? false

        active: seconds > 0
        onSecondsChanged: {
            active = false;
            active = seconds > 0;
        }
        sourceComponent: IdleMonitor { timeout: mon.seconds }
    }

    Monitor {
        id: barMonitor
        seconds: Config.modules.idle.barDim
    }

    Monitor {
        id: brightnessMonitor
        seconds: Config.modules.idle.brightnessDim
    }
}
