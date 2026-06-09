import QtQuick
import Quickshell
import Quickshell.Wayland

Drawer {
    id: root

    property bool inhibitIdle: false

    IdleInhibitor {
        window: root.QsWindow.window
        enabled: root.inhibitIdle
    }

    BarItem {
        id: shutdown
        onClicked: Quickshell.execDetached(["vicinae", "vicinae://launch/power/power-off"])
        BarText { color: shutdown.fg; text: "⏻ " }
    }
    BarItem {
        id: idle
        tooltip: root.inhibitIdle ? "Idle inhibited" : "Idle not inhibited"
        onClicked: root.inhibitIdle = !root.inhibitIdle
        BarText { color: idle.fg; text: root.inhibitIdle ? "" : "" }
    }
    BarItem {
        id: reboot
        onClicked: Quickshell.execDetached(["vicinae", "vicinae://launch/power/reboot"])
        BarText { color: reboot.fg; text: "⭮" }
    }
    BarItem {
        id: suspend
        onClicked: Quickshell.execDetached(["vicinae", "vicinae://launch/power/suspend"])
        BarText { color: suspend.fg; text: "⏾" }
    }
    BarItem {
        id: lock
        onClicked: Quickshell.execDetached(["vicinae", "vicinae://launch/power/lock"])
        BarText { color: lock.fg; text: "⏸" }
    }
}
