//@ pragma UseQApplication
// required for tray menus (QsMenuAnchor); pragma changes need a restart
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
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
            resync.restart();
        }
    }

    // quickshell can miss moveworkspace events during the replug churn,
    // leaving workspace->monitor links stale (pills dim on the wrong bar):
    // re-query Hyprland once the screen list settles
    Timer {
        id: resync
        interval: 1000
        onTriggered: {
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
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
