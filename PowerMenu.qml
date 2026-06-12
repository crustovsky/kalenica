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

    ConfirmDialog { id: confirm }

    BarItem {
        id: shutdown
        onClicked: confirm.ask("Shutdown the system?", ["systemctl", "poweroff"])
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
        onClicked: confirm.ask("Reboot the system?", ["systemctl", "reboot"])
        BarText { color: reboot.fg; text: "⭮" }
    }
    BarItem {
        id: suspend
        onClicked: confirm.ask("Suspend the system?", ["systemctl", "suspend"])
        BarText { color: suspend.fg; text: "⏾" }
    }
    BarItem {
        id: lock
        onClicked: Quickshell.execDetached(["uwsm", "app", "--", "hyprlock"])
        BarText { color: lock.fg; text: "⏸" }
    }
}
