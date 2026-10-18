pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

// Idle timers (ext-idle-notify): the bars fade their content after
// modules.idle.barDim seconds (OLED care, so only with theme.oled and
// regardless of idle inhibitors: a movie keeps the picture on, not the bar
// burning in), BrightnessControl dims the panels after brightnessDim
// (honouring inhibitors like hypridle did). Lock / screen-off / suspend stay
// with hypridle (see examples/hypridle.conf).
Singleton {
    readonly property bool barIdle: barMonitor.idle
    readonly property bool brightnessIdle: brightnessMonitor.idle

    // An IdleMonitor (quickshell 0.3.2) goes silent after a runtime timeout
    // change, and config.json lands after startup, so a new value rebuilds
    // the monitor instead of rebinding it.
    component Monitor: Loader {
        id: mon
        required property int seconds
        required property bool respectInhibitors
        readonly property bool idle: (item as IdleMonitor)?.isIdle ?? false

        active: seconds > 0
        onSecondsChanged: {
            active = false;
            active = seconds > 0;
        }
        sourceComponent: IdleMonitor {
            timeout: mon.seconds
            respectInhibitors: mon.respectInhibitors
        }
    }

    Monitor {
        id: barMonitor
        seconds: Config.theme.oled ? Config.modules.idle.barDim : 0
        respectInhibitors: false
    }

    Monitor {
        id: brightnessMonitor
        seconds: Config.modules.idle.brightnessDim
        respectInhibitors: true
    }
}
