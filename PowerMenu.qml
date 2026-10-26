import QtQuick
import Quickshell
import Quickshell.Wayland

Drawer {
    id: root

    IdleInhibitor {
        window: root.QsWindow.window
        enabled: Idle.inhibited
    }

    ConfirmDialog { id: confirm }

    BarItem {
        id: shutdown
        onClicked: confirm.ask("Shutdown the system?", ["systemctl", "poweroff"])
        BarText { color: shutdown.fg; text: "⏻ " }
    }
    BarItem {
        id: idle
        tooltip: Idle.inhibited ? "Idle inhibited" : "Idle not inhibited"
        onClicked: Idle.inhibited = !Idle.inhibited
        BarText { color: idle.fg; text: Idle.inhibited ? "" : "" }
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
        onClicked: Quickshell.execDetached(Config.modules.power.lockCommand)
        BarText { color: lock.fg; text: "⏸" }
    }
}
