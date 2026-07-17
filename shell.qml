//@ pragma UseQApplication
// required for tray menus (QsMenuAnchor); pragma changes need a restart
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property bool barVisible: true

    Variants {
        model: Quickshell.screens
        Bar {
            visible: root.barVisible
        }
    }

    Notifications {}

    Osd {
        id: osd
    }

    BrightnessControl {
        osd: osd
    }

    // toggle with: qs ipc call expo toggle
    Expo {}

    // qs ipc call screenshot screen|active|area
    Screenshot {}

    // heals stale NM/BlueZ bindings after a daemon restart
    ServiceWatchdog {}

    // toggle with: qs ipc call bar toggle
    IpcHandler {
        target: "bar"

        function toggle(): void {
            root.barVisible = !root.barVisible;
        }
    }

    // Hyprland sometimes stops compositing a mapped layer surface after an
    // output disable/enable cycle (lid close/open): remap the bars once the
    // screen list settles to force full damage
    Connections {
        target: Quickshell

        function onScreensChanged() {
            if (root.barVisible)
                healOff.restart();
        }
    }

    Timer {
        id: healOff
        interval: 2000
        onTriggered: {
            root.barVisible = false;
            healOn.start();
        }
    }

    Timer {
        id: healOn
        interval: 500
        onTriggered: root.barVisible = true
    }
}
